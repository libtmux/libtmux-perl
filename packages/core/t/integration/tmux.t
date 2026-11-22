use v5.44;
use Test2::V1;
use Cwd          qw(getcwd);
use POSIX        qw(WNOHANG);
use Scalar::Util qw(blessed);
my $loaded = eval { require LibTmux::Server; 1 };
T2->ok($loaded, 'explicit synchronous tmux facade loads');
unless ($loaded) { T2->diag($@); T2->done_testing; exit }
use LibTmuxFixture;
LibTmuxFixture->run(
    sub ($server, $root) {
        my $owned_pid;
        my $session = $server->new_session(
            name    => 'main',
            command => ['/bin/sleep', '120'],
            width   => 160,
            height  => 48
        );
        $owned_pid =
            0 + $server->cmd('display-message', '-p', '#{pid}')->stdout;
        T2->is($session->name, 'main',
            'session creation returns captured data');
        my $window = $server->new_window(
            session => $session,
            name    => 'api-one',
            command => ['/bin/sleep', '120']
        );
        my $pane  = $window->panes->first;
        my $split = $server->split_pane(
            pane       => $pane,
            horizontal => true,
            command    => ['/bin/sleep', '120']
        );
        T2->ok($split->id ne $pane->id, 'split returns a new physical pane');
        $server->link_window(
            window  => $window,
            session => $session,
            index   => 3
        );
        my $other = $server->new_session(
            name    => 'other',
            command => ['/bin/sleep', '120']
        );
        $server->link_window(window => $window, session => $other, index => 2);
        my $snapshot = $server->snapshot;
        T2->is(
            $snapshot->window_links->where(
                {window => {-is => {id => $window->id}}}
            )->count,
            3,
            'same-session and cross-session links are preserved'
        );
        T2->is($snapshot->windows->where({id => $window->id})->count,
            1, 'physical window index is unique');
        T2->is(
            $snapshot->panes->where({window => {-is => {id => $window->id}}})
                ->count,
            2,
            'physical panes deduplicate contextual rows'
        );
        T2->ok($server->listings('pane')->@* > $snapshot->panes->count,
            'raw listings keep contextual rows');
        T2->ok(
            $snapshot->metadata->{capture_end} >=
                $snapshot->metadata->{capture_start},
            'capture interval recorded'
        );
        $server->rename_window(window => $window, name => 'api-new');
        T2->is($window->name, 'api-one',
            'mutation does not refresh captured handles');
        T2->is($server->snapshot->window_by_id($window->id)->name,
            'api-new', 'explicit acquisition observes mutation');

        $server->set_option(
            name   => '@test',
            value  => "zero 0\nback\\slash",
            scope  => 'session',
            target => $session->id
        );
        T2->is(
            $server->get_option(
                name   => '@test',
                scope  => 'session',
                target => $session->id
            ),
            "zero 0\nback\\slash",
            'option bytes survive embedded newline'
        );
        $server->set_environment(
            name    => 'LIBTMUX_TEST',
            value   => "line\nvalue",
            session => $session->id
        );
        T2->is(
            $server->get_environment(
                name    => 'LIBTMUX_TEST',
                session => $session->id
            ),
            "line\nvalue",
            'environment value preserves newline'
        );
        my $bytes = "buffer\0payload\n\xff";
        $server->set_buffer(name => 'test', data => $bytes);
        T2->is($server->show_buffer(name => 'test'),
            $bytes, 'stdin-backed buffers preserve binary bytes');
        $server->delete_buffer(name => 'test');
        my $deleted;
        try { $server->show_buffer(name => 'test') } catch ($error) {
            $deleted = $error
        }
        T2->ok(
            ref($deleted) && $deleted->isa('LibTmux::X::Command'),
            'deleted buffer cannot be read as an empty value'
        );
        $server->set_hook(
            name    => 'after-new-window[3]',
            command => 'display-message -p hook',
            target  => $session->id
        );
        T2->ok(
            index($server->show_hooks(target => $session->id),
                'after-new-window[3]') >= 0,
            'hook output keeps sparse indexes'
        );

        my $local = $server->query_panes(
            where    => {width => {-gte => 1}},
            pushdown => 'never'
        );
        my $pushed = $server->query_panes(
            where    => {width => {-gte => 1}},
            pushdown => 'require'
        );
        T2->is(
            [map { $_->id } @$pushed],
            [map { $_->id } @$local],
            'numeric native query agrees with local selection'
        );
        my $native_active =
            $server->query_panes(native_filter => '#{pane_active}');
        T2->is(
            $native_active->count,
            $server->snapshot->panes->where({active => true})->count,
            'native escape hatch selects candidate roots'
        );
        my $explain =
            $server->explain_panes(
            where => {title => {-contains => 'literal.v2'}});
        T2->like($explain->summary, qr/residual|local/,
            'unsupported exact lowering is explained');

        my $link = $server->snapshot->window_links->one(
            {session => {-is => {id => $session->id}}, index => 3});
        $server->unlink_window(link => $link);
        $server->cmd('new-window', '-d', '-t', $session->id . ':3',
            '/bin/sleep', '120');
        my $stale;
        try { $server->select_window(link => $link) } catch ($e) {
            $stale = $e
        }
        T2->ok(
            blessed($stale) && $stale->isa('LibTmux::X::StaleReference'),
            'reused session/index cannot retarget a captured link'
        );

        {
            my $tmux_bin = $server->{executable};
            my $sandbox  = "$root/sandbox";
            my $workdir  = "$root/cwd";
            mkdir($sandbox, 0700) or die $!;
            mkdir($workdir, 0700) or die $!;
            my $stop_daemon = sub ($srv) {
                my $pid =
                    0 + $srv->cmd('display-message', '-p', '#{pid}')->stdout;
                $srv->kill_server;
                waitpid($pid, 0);
            };
            my $saved_cwd = getcwd();
            chdir $workdir or die $!;
            my $rel_server;
            try {
                $rel_server = LibTmux::Server->new(
                    executable  => $tmux_bin,
                    config_file => '/dev/null',
                    timeout     => 0.8,
                    env         => {
                        LIBTMUX_SOCKET_PATH => 'rel.sock',
                        LIBTMUX_SOCKET      => 'ignored/slash',
                        TMUX                => "$root/s,123,0",
                    },
                );
            }
            catch ($err) {
                chdir $saved_cwd;
                die $err;
            }
            chdir $saved_cwd or die $!;
            $rel_server->new_session(
                name    => 'from-rel-path',
                command => ['/bin/sleep', '120']
            );
            T2->is($rel_server->snapshot->server_id, "$workdir/rel.sock",
'relative LIBTMUX_SOCKET_PATH reaches resolved daemon and ignores LIBTMUX_SOCKET'
            );
            my $explicit = LibTmux::Server->new(
                executable  => $tmux_bin,
                socket_path => "$root/s",
                timeout     => 0.8,
                env         => {
                    LIBTMUX_SOCKET_PATH => "$workdir/rel.sock",
                    LIBTMUX_SOCKET      => 'ignored/slash',
                },
            );
            T2->is(
                $explicit->snapshot->sessions->where({name => 'main'})->count,
                1,
'explicit socket_path beats LIBTMUX_SOCKET_PATH against live daemons'
            );
            $stop_daemon->($rel_server);

            my $named = LibTmux::Server->new(
                executable  => $tmux_bin,
                config_file => '/dev/null',
                timeout     => 0.8,
                env         => {
                    LIBTMUX_SOCKET_PATH  => "  \t ",
                    LIBTMUX_SOCKET       => 'env-named',
                    TMUX_TMPDIR          => $sandbox,
                    LIBTMUX_TEST_SANDBOX => $sandbox,
                    TMUX                 => "$root/s,123,0",
                },
            );
            $named->new_session(
                name    => 'from-socket-name',
                command => ['/bin/sleep', '120']
            );
            T2->is($named->snapshot->server_id, "$sandbox/tmux-$>/env-named",
'LIBTMUX_SOCKET reaches named daemon after blank LIBTMUX_SOCKET_PATH'
            );
            $stop_daemon->($named);

            my $via_tmux = LibTmux::Server->new(
                executable => $tmux_bin,
                timeout    => 0.8,
                env        => {TMUX => "$root/s,999,0"},
            );
            T2->is($via_tmux->snapshot->server_id, "$root/s",
'inherited TMUX reaches the daemon TMUX names when no selector is set'
            );
            my $nested = $via_tmux->new_session(
                name    => 'from-tmux-env',
                command => ['/bin/sleep', '120']
            );
            T2->is(
                $server->snapshot->session_by_id($nested->id)->name,
                'from-tmux-env',
'new_session succeeds against TMUX daemon with child TMUX cleared'
            );
            $via_tmux->kill_session(session => $nested);

            my $default_srv = LibTmux::Server->new(
                executable  => $tmux_bin,
                config_file => '/dev/null',
                timeout     => 0.8,
                env         => {
                    TMUX_TMPDIR          => $sandbox,
                    LIBTMUX_TEST_SANDBOX => $sandbox,
                },
            );
            $default_srv->new_session(
                name    => 'from-default',
                command => ['/bin/sleep', '120']
            );
            T2->is($default_srv->snapshot->server_id,
                "$sandbox/tmux-$>/default",
                'unset selectors and unset TMUX reach tmux default socket');
            $stop_daemon->($default_srv);
        }

        $server->kill_server;
        my $reaped = waitpid($owned_pid, 0);
        T2->is($reaped, $owned_pid, 'owned server exit is reaped');
        $owned_pid = undef;
        delete $server->{fixture_pid};
        while (waitpid(-1, 0) > 0) { }
        my $dead;
        try { $server->snapshot } catch ($e) {
            $dead = $e
        }
        T2->ok(
            blessed($dead) && $dead->isa('LibTmux::X::NoServer'),
            'acquisition failure remains a typed failure'
        );
        my $old_pane  = $snapshot->panes->first;
        my $restarted = $server->new_session(
            name    => 'restarted',
            command => ['/bin/sleep', '120']
        );
        $owned_pid =
            0 + $server->cmd('display-message', '-p', '#{pid}')->stdout;
        my $reused = $server->snapshot->panes->first;
        T2->is($reused->id, $old_pane->id,
            'a restarted daemon can reuse the same physical pane ID');
        T2->ok(
            $reused->generation ne $old_pane->generation,
            'daemon generation separates reused identities'
        );
        my $restart_stale;
        try { $server->select_pane(pane => $old_pane) } catch ($error) {
            $restart_stale = $error
        }
        T2->ok(
            blessed($restart_stale)
                && $restart_stale->isa('LibTmux::X::StaleReference'),
            'retained handles cannot mutate a reused ID after daemon restart'
        );
    }
);
T2->done_testing;
