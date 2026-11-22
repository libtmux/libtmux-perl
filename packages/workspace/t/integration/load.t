use v5.44;
use Test2::V1;
use JSON::PP     ();
use Scalar::Util qw(blessed);
use LibTmuxFixture;
use LibTmux::Workspace;
use LibTmux::Transport;
LibTmuxFixture->run(
    sub ($server, $root) {
        my $workspace = LibTmux::Workspace->new(
            config => {
                schema      => 'libtmux.workspace/v1',
                environment => {LIBTMUX_WORKSPACE_TEST => 'literal value'},
                sessions    => [
                    {
                        name    => 'workspace',
                        windows => [
                            {
                                name   => 'api',
                                cwd    => $root,
                                layout => 'even-horizontal',
                                panes  => [
                                    {command => ['/bin/sleep', '120']},
                                    {
                                        command    => ['/bin/sleep', '120'],
                                        horizontal => true
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        );
        my $report = $workspace->load(server => $server);
        T2->is($report->{status}, 'loaded', 'workspace load succeeds');
        my $snapshot = $server->snapshot;
        T2->is($snapshot->panes->count, 2, 'all configured panes exist');
        T2->is($snapshot->windows->one->name,
            'api', 'initial window receives the configured name');
        T2->is($snapshot->panes->first->current_path,
            $root, 'working directory reaches initial process');
        my $pid = $snapshot->panes->first->pid;
        open my $env, '<:raw', "/proc/$pid/environ" or die $!;
        my $bytes = do { local $/; <$env> };
        close $env;
        T2->ok(index($bytes, "LIBTMUX_WORKSPACE_TEST=literal value\0") >= 0,
            'environment reaches the initial process');
        T2->is(
            $workspace->load(server => $server, existing => 'skip')->{skipped},
            ['workspace'],
            'repeat skip preserves the existing session'
        );
        my $conflict;
        try { $workspace->load(server => $server) } catch ($error) {
            $conflict = $error
        }
        T2->ok(
            blessed($conflict)
                && $conflict->isa('LibTmux::Workspace::X::Conflict'),
            'repeat error reports a conflict'
        );
        my $bad = LibTmux::Workspace->new(
            config => {
                schema   => 'libtmux.workspace/v1',
                sessions => [
                    {
                        name    => 'broken',
                        windows => [
                            {
                                name   => 'bad',
                                layout => 'no-such-layout',
                                panes  => [{command => ['/bin/sleep', '120']}]
                            }
                        ]
                    }
                ]
            }
        );
        my $failure;
        try { $bad->load(server => $server) } catch ($error) {
            $failure = $error
        }
        T2->ok(
            scalar(
                       blessed($failure)
                    && $failure->isa('LibTmux::Workspace::X::Load')
                    && $failure->report->{failed_step} =~ /layout/
            ),
            'failed step retains a partial report'
        );
        T2->is([map { $_->name } $server->snapshot->sessions->@*],
            ['workspace'], 'rollback removes only the newly owned session');
        my $file = "$root/workspace.json";
        open my $out, '>:raw', $file or die $!;
        print {$out} JSON::PP->new->utf8->encode(
            $workspace->plan->{sessions}
            ? {schema => 'libtmux.workspace/v1', sessions => []}
            : {}
        );
        close $out;
        my @cli = ($^X, map { ('-I', $_) } grep { !ref($_) } @INC);
        push @cli, $ENV{LIBTMUX_TEST_CLI}
            // 'packages/workspace/bin/libtmux-workspace';
        my $help = LibTmux::Transport->run(argv => [@cli, '--help']);
        T2->ok(scalar($help->success && $help->stdout =~ /Usage:/),
            'packaged CLI help works');
        my $plan = LibTmux::Transport->run(
            argv => [
                @cli, 'load', $file, '--dry-run', '--tmux', '/missing-libtmux'
            ]
        );
        T2->ok(
            scalar($plan->success && $plan->stdout =~ /"mutates"\s*:\s*false/),
            'CLI dry-run performs no process acquisition'
        );
        open $out, '>:raw', $file or die $!;
        print {$out} JSON::PP->new->utf8->encode(
            {
                schema   => 'libtmux.workspace/v1',
                sessions => [
                    {
                        name    => 'cli-loaded',
                        windows => [
                            {
                                name  => 'cli',
                                panes => [{command => ['/bin/sleep', '120']}]
                            }
                        ]
                    }
                ]
            }
        );
        close $out;
        my @load = (
            @cli, 'load', $file, '--socket-path', "$root/s", '--tmux',
            $ENV{LIBTMUX_TEST_TMUX} // 'tmux'
        );
        my $loaded = LibTmux::Transport->run(argv => \@load);
        T2->ok(
            $loaded->success
                && $server->snapshot->sessions->where({name => 'cli-loaded'})
                ->count == 1,
            'CLI load creates the configured session on the owned socket'
        );
        T2->is(LibTmux::Transport->run(argv => \@load)->exit_code,
            4, 'repeat CLI load reports conflict with its dedicated status');
        T2->ok(
            LibTmux::Transport->run(argv => [@load, '--existing', 'skip'])
                ->success,
            'repeat CLI skip is idempotent for existing sessions'
        );
        {
            my $tmux_bin = $server->{executable};
            my $env_file = "$root/workspace-env.json";
            my $write_ws = sub ($session_name) {
                open my $ws_out, '>:raw', $env_file or die $!;
                print {$ws_out} JSON::PP->new->utf8->encode(
                    {
                        schema   => 'libtmux.workspace/v1',
                        sessions => [
                            {
                                name    => $session_name,
                                windows => [
                                    {
                                        name  => 'cli',
                                        panes => [
                                            {command => ['/bin/sleep', '120']}
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                );
                close $ws_out;
            };
            $write_ws->('cli-env-path');
            my $via_path = LibTmux::Transport->run(
                argv => [@cli, 'load', $env_file, '--tmux', $tmux_bin],
                env  => {
                    LIBTMUX_SOCKET_PATH => "$root/s",
                    LIBTMUX_SOCKET      => 'ignored/slash',
                },
            );
            T2->ok(
                $via_path->success && $server->snapshot->sessions->where(
                    {name => 'cli-env-path'}
                )->count == 1,
'CLI load without flags uses LIBTMUX_SOCKET_PATH over LIBTMUX_SOCKET'
            );

            my $sandbox = "$root/ws-sandbox";
            mkdir($sandbox, 0700) or die $!;
            $write_ws->('cli-env-name');
            my $via_name = LibTmux::Transport->run(
                argv => [@cli, 'load', $env_file, '--tmux', $tmux_bin],
                env  => {
                    LIBTMUX_SOCKET_PATH  => '   ',
                    LIBTMUX_SOCKET       => 'ws-named',
                    TMUX_TMPDIR          => $sandbox,
                    LIBTMUX_TEST_SANDBOX => $sandbox,
                },
            );
            my $named_srv = LibTmux::Server->new(
                executable  => $tmux_bin,
                socket_path => "$sandbox/tmux-$>/ws-named",
                timeout     => 0.8,
            );
            T2->ok(
                $via_name->success && $named_srv->snapshot->sessions->where(
                    {name => 'cli-env-name'}
                )->count == 1,
'CLI load falls through blank LIBTMUX_SOCKET_PATH to LIBTMUX_SOCKET'
            );
            my $named_pid =
                0 + $named_srv->cmd('display-message', '-p', '#{pid}')->stdout;
            $named_srv->kill_server;
            waitpid($named_pid, 0);

            $write_ws->('cli-tmux-env');
            my $via_tmux = LibTmux::Transport->run(
                argv => [
                    $^X,
                    '-e',
'$ENV{TMUX} = shift @ARGV; exec {$ARGV[0]} @ARGV or exit 127',
                    "$root/s,42,0",
                    @cli,
                    'load',
                    $env_file,
                    '--tmux',
                    $tmux_bin,
                ],
            );
            T2->ok(
                $via_tmux->success && $server->snapshot->sessions->where(
                    {name => 'cli-tmux-env'}
                )->count == 1,
'CLI load without flags or LIBTMUX_SOCKET* reaches the TMUX server'
            );
        }
        open $out, '>:raw', $file or die $!;
        print {$out} JSON::PP->new->utf8->encode(
            {
                schema   => 'libtmux.workspace/v1',
                sessions => $bad->plan->{sessions}
            }
        );
        close $out;
        my $failed_cli = LibTmux::Transport->run(argv => \@load);
        T2->is($failed_cli->exit_code, 3,
            'CLI partial failure retains its exit status');
        my $diagnostic = $failed_cli->stderr =~ s/\A[^\n]*\n//r;
        my $export     = JSON::PP->new->utf8->decode($diagnostic);
        T2->is($export->{cause}{class},
            'LibTmux::X::InvalidArgument',
            'CLI emits the typed primary cause in valid JSON');
        T2->is($export->{cleanup_errors},
            [], 'CLI reports successful rollback separately');
        open $out, '>:raw', $file or die $!;
        print {$out} '{bad';
        close $out;
        T2->is(
            LibTmux::Transport->run(argv => [@cli, 'validate', $file])
                ->exit_code,
            2,
            'malformed JSON has configuration exit status'
        );
    }
);
T2->done_testing;
