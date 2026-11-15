use v5.44;
use File::Temp ();
use IO::Async::Loop::Ppoll;
use LibTmux::Async::Server;
use LibTmux::Server;

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
        name    => 'async-example',
        command => ['/bin/sleep', '120']
    );
    my $loop   = IO::Async::Loop::Ppoll->new;
    my $server = LibTmux::Async::Server->new(
        loop           => $loop,
        socket_path    => $socket,
        max_concurrent => 2
    );
    my $snapshot = $server->snapshot;
    $loop->await($snapshot);
    die 'async snapshot missing pane'
        unless $snapshot->get->panes->count == 1;
    my $closed = $server->close;
    $loop->await($closed);
    die 'cleanup failed' unless $closed->is_done;
}
catch ($error) { $failure = $error }

# Clean up the processes this demo starts, even if it fails.
try { $sync->kill_server }
catch ($cleanup) {
    $failure //= $cleanup unless $cleanup isa LibTmux::X::NoServer;
}
die $failure if defined $failure;
say 'async capture and cleanup: ok';
