use v5.44;
use FindBin;
use lib "$FindBin::Bin/../scripts/lib";
use IO::Async::Loop;
use LibTmux::Async::Server;
use LibTmuxFixture;
LibTmuxFixture->run(
    sub ($sync, $root) {
        $sync->new_session(
            name    => 'async-example',
            command => ['/bin/sleep', '120']
        );
        my $loop   = IO::Async::Loop->new;
        my $server = LibTmux::Async::Server->new(
            loop           => $loop,
            socket_path    => "$root/s",
            executable     => $ENV{LIBTMUX_TEST_TMUX} // 'tmux',
            max_concurrent => 2
        );
        my $snapshot = $server->snapshot;
        $loop->await($snapshot);
        die 'async snapshot missing pane'
            unless $snapshot->get->panes->count == 1;
        my $closed = $server->close;
        $loop->await($closed);
        die 'cleanup failed' unless $closed->is_done;
        say 'async capture and cleanup: ok';
    }
);
