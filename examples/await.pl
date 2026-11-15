use v5.44;
use File::Temp ();
use IO::Async::Loop::Ppoll;
use Future::AsyncAwait;
use LibTmux::Async::Server;
use LibTmux::Server;

async sub capture_count ($server) {
    my $snapshot = await $server->snapshot;
    my $count    = $snapshot->panes->count;
    await $server->close;
    return $count;
}

# A private temporary directory holds the socket; it is removed at exit.
my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $socket  = "$private/tmux.sock";
my $sync    = LibTmux::Server->new(
    socket_path => $socket,
    config_file => '/dev/null',
);

my $failure;
try {
    $sync->new_session(
        name    => 'await-example',
        command => ['/bin/sleep', '120']
    );
    my $loop   = IO::Async::Loop::Ppoll->new;
    my $server = LibTmux::Async::Server->new(
        loop        => $loop,
        socket_path => $socket,
    );
    my $work = capture_count($server);
    $loop->await($work);
    die 'await result differs' unless $work->get == 1;
}
catch ($error) { $failure = $error }

# Clean up the processes this demo starts, even if it fails.
try { $sync->kill_server }
catch ($cleanup) {
    $failure //= $cleanup unless $cleanup isa LibTmux::X::NoServer;
}
die $failure if defined $failure;
say 'optional caller await syntax: ok';
