use v5.44;
use Test2::V1;
use LibTmuxFixture;

# Outer: native daemon receipts, hooks and replacement need owned processes.
LibTmuxFixture->run(
    sub ($server, $root) {
        my $cold;
        try { $server->capabilities } catch ($error) {
            $cold = $error
        }
        T2->ok(
            ref($cold) && $cold->isa('LibTmux::X::NoServer'),
            'cold discovery refuses without starting a daemon'
        );
        T2->ok(!-e "$root/s", 'cold discovery creates no socket');
        $server->new_session(
            name    => 'capabilities',
            command => ['/bin/sleep', '120']
        );
        my $version =
            $server->cmd('display-message', '-p', '#{version}')->stdout;
        chomp $version;
        my $native_shape =
            $server->cmd('list-panes', '-F', '#{cursor_shape}')->stdout;
        chomp $native_shape;
        my $expected = length($native_shape) ? true : false;

        my $wrapper = "$root/client";
        open my $out, '>', $wrapper or die $!;
        print {$out} "#!$^X\n", <<'CLIENT';
use v5.44;
open my $log, '>>', $ENV{LIBTMUX_CAPABILITY_LOG} or die $!;
print {$log} join("\0", @ARGV), "\n";
close $log or die $!;
die 'discovery invoked client -V' if grep { $_ eq '-V' } @ARGV;
my $client = $ENV{LIBTMUX_CAPABILITY_CLIENT};
exec {$client} $client, @ARGV or die $!;
CLIENT
        close $out or die $!;
        chmod 0700, $wrapper or die $!;
        my $probe = LibTmux::Server->new(
            socket_path => "$root/s",
            config_file => '/dev/null',
            executable  => $wrapper,
            env         => {
                LIBTMUX_CAPABILITY_LOG    => "$root/requests",
                LIBTMUX_CAPABILITY_CLIENT => $ENV{LIBTMUX_TEST_CLIENT_TMUX}
                    // $ENV{LIBTMUX_TEST_TMUX} // 'tmux'
            }
        );
        $server->set_hook(
            name    => 'after-display-message',
            global  => true,
            command => 'set-option -g @capability-hook fired'
        );
        $server->cmd('display-message', '-p', 'control');
        T2->is($server->get_option(name => '@capability-hook', global => true),
            'fired', 'the armed display hook fires for its positive control');
        $server->set_option(
            name   => '@capability-hook',
            global => true,
            value  => 'clear'
        );

        my $armed = $server->execute(
            argv => [
                'set-hook',      '-g',
                'command-error', 'set-option -g @capability-error fired'
            ]
        )->success;
        if ($armed) {
            $server->execute(
                argv => ['has-session', '-t', '=missing-capability-control']);
            T2->is(
                $server->get_option(
                    name   => '@capability-error',
                    global => true
                ),
                'fired',
                'the armed error hook fires for its positive control'
            );
            $server->set_option(
                name   => '@capability-error',
                global => true,
                value  => 'clear'
            );
        }

        $server->set_option(
            name  => 'command-alias[999]',
            scope => 'server',
            value => 'run-shell=display-message -p capability-alias-control'
        );
        T2->is(
            $server->cmd('run-shell')->stdout,
            "capability-alias-control\n",
            'an exact run-shell alias is active'
        );
        $server->set_option(
            name   => '@capability-hook',
            global => true,
            value  => 'clear'
        );
        my $census = sub {
            return [
                map { $server->cmd(@$_)->stdout }
                    ['list-sessions', '-F', '#{session_id}'],
                ['list-windows', '-a', '-F', '#{window_id}'],
                ['list-panes',   '-a', '-F', '#{pane_id}'],
                ['list-buffers', '-F', '#{buffer_name}:#{buffer_size}']
            ];
        };
        my $before = $census->();
        my $report = $probe->capabilities;
        T2->is($report->version, $version,
            'the report names the actual daemon');
        T2->is($report->supports('cursor-shape'),
            $expected, 'the optional feature matches the native daemon field');
        $report->features->[0]{supported}                      = !$expected;
        $report->status('cursor-shape')->{since}               = '1.0';
        $report->status('cursor-shape')->{commands}[0]{format} = 'changed';
        T2->is($probe->capabilities->supports('cursor-shape'),
            $expected, 'returned metadata cannot change a later native report');
        T2->is($census->(), $before,
            'discovery preserves sessions, windows, panes and buffers');
        T2->is($server->get_option(name => '@capability-hook', global => true),
            'clear', 'discovery fires no display hook');
        T2->is($server->get_option(name => '@capability-error', global => true),
            'clear', 'the parser receipt fires no command-error hook')
            if $armed;
        open my $log, '<', "$root/requests" or die $!;
        my @requests = <$log>;
        close $log;
        T2->is(scalar @requests,
            2, 'each public discovery executes one fresh client request');
        T2->ok(!scalar(grep { /(?:\A|\0)-V(?:\0|\n)/ } @requests),
            'native discovery never runs client -V');
        T2->ok(
            !scalar(grep { !/(?:\A|\0)-N\0/ } @requests),
            'every native discovery forbids daemon creation'
        );

        my $pane = $server->snapshot->panes->one;
        if ($expected) {
            T2->is($pane->cursor_shape, $native_shape,
                'the shared gate admits the supported captured field');
        }
        else {
            my $error;
            try { $pane->cursor_shape } catch ($caught) {
                $error = $caught
            }
            T2->ok(
                ref($error) && $error->isa('LibTmux::X::Unsupported'),
'the shared gate refuses the unavailable captured field after metadata edits'
            );
        }
        my $old_identity = $report->identity;
        $server->kill_server;
        {
            local $SIG{ALRM} = sub { die 'owned old daemon did not exit' };
            alarm 1;
            waitpid($old_identity->{pid}, 0);
            alarm 0;
        }
        $server->new_session(
            name    => 'replacement',
            command => ['/bin/sleep', '120']
        );
        my $replacement = $probe->capabilities;
        T2->is($report->identity, $old_identity,
            'a saved report remains historical');
        T2->isnt($replacement->identity->{pid},
            $old_identity->{pid},
            'a later call observes the selected replacement daemon');
    }
);
T2->done_testing;
