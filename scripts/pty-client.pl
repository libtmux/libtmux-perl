use v5.44;
use FindBin;
use lib "$FindBin::Bin/../local/lib/perl5";
use IO::Pty ();
use POSIX   ();

# Own one interactive tmux client and observe its exit through a PTY. Core Perl
# cannot allocate a PTY, so this author-only helper uses IO::Pty. The client
# runs with TERM=xterm-256color and without TMUX or TMUX_PANE; the helper drains
# the terminal until the client closes it, then prints client_exit=<code> and
# exits with that code.
#
#   perl scripts/pty-client.pl PROGRAM [ARGS...]
die "Usage: pty-client.pl PROGRAM [ARGS...]\n" unless @ARGV;
my $pty   = IO::Pty->new;
my $slave = $pty->slave;
my $pid   = fork() // die "fork: $!\n";

if (!$pid) {
    POSIX::dup2($slave->fileno, $_) // POSIX::_exit(126) for 0 .. 2;
    close $pty;
    close $slave;
    $ENV{TERM} = 'xterm-256color';
    delete @ENV{qw(TMUX TMUX_PANE)};
    exec {$ARGV[0]} @ARGV or POSIX::_exit(127);
}
$pty->close_slave;
while (1) {
    my $count = sysread($pty, my $buffer, 65536);
    next if !defined($count) && $!{EINTR};
    last if !defined($count) && $!{EIO};
    die "read: $!\n" unless defined $count;
    last             unless $count;
}
close $pty;
waitpid($pid, 0);
my $code = $? & 127 ? 128 + ($? & 127) : $? >> 8;
say "client_exit=$code";
exit $code;
