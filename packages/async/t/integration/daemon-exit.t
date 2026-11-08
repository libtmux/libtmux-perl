use v5.44;
use Test2::V1;
use IO::Async::Loop::Ppoll;
use LibTmux::Async::Server;
use LibTmuxFixture;

LibTmuxFixture->run(
    sub ($sync, $root) {
        my $loop   = IO::Async::Loop::Ppoll->new;
        my $tmux   = $ENV{LIBTMUX_TEST_TMUX} // 'tmux';
        my $server = LibTmux::Async::Server->new(
            loop        => $loop,
            socket_path => "$root/s",
            config_file => '/dev/null',
            executable  => $tmux,
        );
        my $created = $server->new_session(
            name    => 'async-exit',
            command => [
                '/bin/sh', '-c', '"$@" wait-for release; exit 0',
                'sh', $tmux, '-S', "$root/s"
            ],
        );
        $loop->await($created);
        T2->ok(
            $created->get isa LibTmux::Session,
            'async creates the owned daemon'
        );
        my $pid   = 0 + $sync->cmd('display-message', '-p', '#{pid}')->stdout;
        my $close = $server->close;
        $loop->await($close);
        T2->ok($close->is_done,
            'close cleans up clients and leaves the daemon alive');
        $sync->cmd('wait-for', '-S', 'release');
        my $error;
        {
            local $SIG{ALRM} =
                sub { die 'daemon did not observe its pane exit' };
            try {
                alarm 1;
                my $waited = waitpid($pid, 0);
                alarm 0;
                T2->is($waited, $pid,
                    'daemon handles SIGCHLD and exits after its final pane');
            }
            catch ($caught) { alarm 0; $error = $caught }
        }
        die $error if defined $error;
    }
);
T2->done_testing;
