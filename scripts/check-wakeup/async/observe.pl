use v5.44;
use IO::Async::Loop;
use POSIX ();
pipe(my $read, my $write) or die $!;
my $pid = fork();
die $! unless defined $pid;
if (!$pid) {
    close $write;
    sysread($read, my $go, 1) == 1 or POSIX::_exit(93);
    POSIX::_exit(7);
}
close $read;
$ENV{LIBTMUX_PROBE_GO_FD} = fileno($write);
$ENV{LIBTMUX_PROBE_CHILD} = $pid;
my $loop = IO::Async::Loop->new;
if (ref($loop) eq 'IO::Async::Loop::Ppoll') {
    require LibTmux::Async::Transport;
    my $transport = LibTmux::Async::Transport->new(loop => $loop);
    $transport->close->get;
}

my $ready = $loop->new_future;
$loop->watch_process($pid, sub ($child, $status) { $ready->done($status) });
$loop->await($ready);
die 'wrong child result' unless $ready->get == (7 << 8);
close $write;
say ref($loop), " observed child exit on Perl $^V";
if ($INC{'IO/Ppoll.pm'}) { say "IO::Ppoll ", IO::Ppoll->VERSION }
