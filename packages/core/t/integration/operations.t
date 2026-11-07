use v5.44;
use Test2::V1;
use LibTmuxFixture;
LibTmuxFixture->run(
    sub ($server, $root) {
        my $session = $server->new_session(
            name    => 'operations',
            command => ['/bin/sleep', '120'],
            width   => 180,
            height  => 50
        );
        $server->rename_session(session => $session, name => '0');
        T2->is($server->snapshot->session_by_id($session->id)->name,
            '0', 'zero-like session name remains text');
        my $window = $server->new_window(
            session => $session,
            name    => '#{pid}',
            command => ['/bin/sleep', '120']
        );
        T2->is($window->name, '#{pid}',
            'window name is literal across tmux format changes');
        $server->rename_window(window => $window, name => '-t');
        T2->is($server->snapshot->window_by_id($window->id)->name,
            '-t', 'rename operands cannot become flags');
        my $pane = $window->panes->one;
        $server->set_title(pane => $pane, title => 'build.v2#{pid}');
        T2->is($server->snapshot->pane_by_id($pane->id)->title,
            'build.v2#{pid}', 'title format metacharacters remain literal');
        my $other = $server->new_session(
            name    => 'destination',
            command => ['/bin/sleep', '120']
        );
        my $link = $server->snapshot->window_links->one(
            {window => {-is => {id => $window->id}}});
        $server->move_window(link => $link, session => $other, index => 4);
        my $moved = $server->snapshot->window_links->one(
            {session => {-is => {id => $other->id}}, index => 4});
        $server->select_window(link => $moved);
        T2->ok($server->snapshot->window_links->one({id => $moved->id})->active,
            'contextual selection uses the moved link');
        my $split = $server->split_pane(
            pane       => $pane,
            horizontal => true,
            command    => ['/bin/sleep', '120']
        );
        $server->select_pane(pane => $split);
        T2->ok(
            $server->snapshot->pane_by_id($split->id)->active,
            'pane selection changes physical active pane'
        );
        $server->resize_pane(pane => $split, width => 70);
        T2->is($server->snapshot->pane_by_id($split->id)->width,
            70, 'explicit pane resize is observed');
        $server->select_layout(window => $window, layout => 'even-horizontal');
        T2->ok($server->snapshot->window_by_id($window->id)->layout =~ /,/,
            'layout result is a native captured layout');
        $server->set_option(
            name   => '@inherited',
            value  => 'global',
            scope  => 'session',
            global => true
        );
        T2->is(
            $server->get_option(
                name      => '@inherited',
                scope     => 'session',
                target    => $other->id,
                inherited => true
            ),
            'global',
            'inherited option is explicit'
        );
        my $missing;
        try {
            $server->get_option(
                name   => '@inherited',
                scope  => 'session',
                target => $other->id
            )
        }
        catch ($error) { $missing = $error }
        T2->ok(
            ref($missing) && $missing->isa('LibTmux::X::Command'),
            'missing local option is not an empty string'
        );
        $server->set_option(
            name   => '@inherited',
            value  => '',
            scope  => 'session',
            target => $other->id
        );
        T2->is(
            $server->get_option(
                name   => '@inherited',
                scope  => 'session',
                target => $other->id
            ),
            '',
            'known empty local option remains text'
        );
        $server->unset_option(
            name   => '@inherited',
            scope  => 'session',
            target => $other->id
        );
        T2->is(
            $server->get_option(
                name      => '@inherited',
                scope     => 'session',
                target    => $other->id,
                inherited => true
            ),
            'global',
            'unsetting local option restores explicit inherited value'
        );
        $server->set_environment(name => 'LIBTMUX_OPERATIONS', value => '0');
        T2->is($server->get_environment(name => 'LIBTMUX_OPERATIONS'),
            '0', 'global environment preserves zero-like text');
        $server->unset_environment(name => 'LIBTMUX_OPERATIONS');
        my $unset;
        try { $server->get_environment(name => 'LIBTMUX_OPERATIONS') }
        catch ($error) {
            $unset = $error
        }
        T2->ok(
            ref($unset) && $unset->isa('LibTmux::X::Command'),
            'unset environment remains a failure rather than empty text'
        );
        my $batch = $server->batch(
            [
                ['display-message', '-p', 'one'],
                ['not-a-tmux-command'],
                ['display-message', '-p', 'three']
            ]
        );
        T2->is($batch->[0]{result}->stdout,
            "one\n", 'batch retains first independent result');
        T2->ok(
            !$batch->[1]{result}->success,
            'batch retains middle nonzero exit'
        );
        T2->is($batch->[2]{result}->stdout,
            "three\n", 'batch continues in input order after nonzero exit');
        T2->is($server->attach_argv(session => $other->id)->[-1],
            $other->id, 'interactive attachment argv uses explicit stable ID');
        T2->is($server->clients->count,
            0, 'detached fixture has no attached client');
        my $raw = $server->execute(argv => ['not-a-tmux-command']);
        T2->ok(!$raw->success && length($raw->stderr),
            'raw execution preserves native failure diagnostics');
        my $command_failure;
        try { $server->cmd('not-a-tmux-command') } catch ($error) {
            $command_failure = $error
        }
        T2->ok(
            ref($command_failure)
                && $command_failure->isa('LibTmux::X::Command'),
            'checked command does not suppress failure'
        );
        $server->kill_pane(pane => $split);
        my $gone;
        try { $server->kill_pane(pane => $split) } catch ($error) {
            $gone = $error
        }
        T2->ok(
            ref($gone) && $gone->isa('LibTmux::X::NoSuchTarget'),
            'vanished target is distinct from an arbitrary command failure'
        );
        T2->is($server->snapshot->panes->where({id => $split->id})->count,
            0, 'pane teardown removes only its physical identity');
        $server->kill_window(window => $window);
        T2->is($server->snapshot->windows->where({id => $window->id})->count,
            0, 'window teardown removes its links');
        $server->kill_session(session => $other);
        T2->is($server->snapshot->sessions->count,
            1, 'session teardown preserves the other session');
    }
);
T2->done_testing;
