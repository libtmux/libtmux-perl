use v5.44;
use FindBin;
use lib "$FindBin::Bin/../scripts/lib";
use IO::Async::Loop;
use Future::AsyncAwait;
use LibTmux::Async::Server;
use LibTmuxFixture;
async sub capture_count ($server) {
    my $snapshot = await $server->snapshot;
    my $count    = $snapshot->panes->count;
    await $server->close;
    return $count;
}
LibTmuxFixture->run(
    sub ($sync, $root) {
        $sync->new_session(
            name    => 'await-example',
            command => ['/bin/sleep', '120']
        );
        my $loop   = IO::Async::Loop->new;
        my $server = LibTmux::Async::Server->new(
            loop        => $loop,
            socket_path => "$root/s",
            executable  => $ENV{LIBTMUX_TEST_TMUX} // 'tmux'
        );
        my $work = capture_count($server);
        $loop->await($work);
        die 'await result differs' unless $work->get == 1;
        say 'optional caller await syntax: ok';
    }
);
