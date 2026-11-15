use v5.44;
use FindBin;
use lib "$FindBin::Bin/../../packages/core/lib";
use Digest::SHA      ();
use File::Temp       qw(tempdir);
use Getopt::Long     qw(GetOptions);
use IO::Select       ();
use POSIX            qw(setsid);
use Text::ParseWords qw(shellwords);
use LibTmux::Platform::Linux;

# Outer regression for lost child-exit wakeups. It compiles a C interposer,
# preloads it into a probe that runs under this process as a child subreaper,
# and fails when the probe does not report the injected exit or times out.
#
#   perl scripts/check-wakeup/check-wakeup.pl async [--loop Ppoll|Poll]
#   perl scripts/check-wakeup/check-wakeup.pl supervisor
#
# `async` injects the exit at the IO::Async wait boundary. `--loop Poll` is the
# negative control: it fails on the rejected backend. `supervisor` injects it at
# the private supervisor's wait. Both need a C compiler; set CC to choose one.
$| = 1;
my $root = "$FindBin::Bin/../..";
my %mode = (
    async => {
        probe   => 'scripts/check-wakeup/async/observe.pl',
        inject  => 'scripts/check-wakeup/async/inject.c',
        libs    => [qw(local/lib/perl5 packages/core/lib packages/async/lib)],
        failure => 'FAIL: child-exit wakeup was not proved',
        success =>
            'PASS: injected exit wakes the loop without a fallback timer',
        required => [],
    },
    supervisor => {
        probe   => 'scripts/check-wakeup/supervisor/observe.pl',
        inject  => 'scripts/check-wakeup/supervisor/inject.c',
        libs    => ['packages/core/lib'],
        failure => 'FAIL: supervisor completion was not proved',
        success =>
            'PASS: injected exit wakes the supervisor without a fallback timer',
        required => ['completed=0'],
    },
);
my $loop = 'Ppoll';
GetOptions('loop=s' => \$loop)
    or die "Usage: check-wakeup.pl async|supervisor\n";
my $name   = shift @ARGV // '';
my $config = $mode{$name};
die "Usage: check-wakeup.pl async [--loop Ppoll|Poll] | supervisor\n"
    unless $config && !@ARGV && $loop =~ /\A(?:Ppoll|Poll)\z/;
chdir $root or die "$root: $!\n";
LibTmux::Platform::Linux::_subreaper();

# Kill one process and, first, its descendants, including those in other
# process groups. A pidfd names the process, so a reused PID is never signaled.
sub terminate_owned ($pid) {
    my $fd = syscall(434, $pid, 0);    # pidfd_open on x86_64
    return if $fd < 0;
    if (open my $in, '<', "/proc/$pid/task/$pid/children") {
        terminate_owned($_) for split ' ', do { local $/; <$in> }
            // '';
    }
    syscall(424, $fd, 9, 0, 0);        # pidfd_send_signal SIGKILL
    POSIX::close($fd);
}

my $directory = tempdir('libtmux-perl-wakeup-XXXX', TMPDIR => 1, CLEANUP => 1);
my $injected  = "$directory/inject.so";
my @compiler  = shellwords($ENV{CC} // 'cc');
system(@compiler, qw(-shared -fPIC -Wall -Wextra -Werror),
    '-o', $injected, $config->{inject}, '-ldl') == 0
    or die "compiling $config->{inject} failed\n";
open my $version, '-|', @compiler, '--version' or die "$compiler[0]: $!\n";
print scalar <$version>;
close $version;
open my $object, '<:raw', $injected or die "$injected: $!\n";
say 'injection sha256: ', Digest::SHA->new(256)->addfile($object)->hexdigest;
close $object;

pipe(my $read, my $write) or die $!;
my $pid = fork() // die $!;
if (!$pid) {
    close $read;
    setsid();
    open STDIN,  '<',  '/dev/null' or POSIX::_exit(126);
    open STDOUT, '>&', $write      or POSIX::_exit(126);
    open STDERR, '>&', $write      or POSIX::_exit(126);
    $ENV{LD_PRELOAD}    = $injected;
    $ENV{IO_ASYNC_LOOP} = $loop if $name eq 'async';
    exec $^X, (map { "-I$_" } $config->{libs}->@*), $config->{probe}
        or POSIX::_exit(127);
}
close $write;
my ($output, $deadline) = ('', time() + 2);
my $select = IO::Select->new($read);
while (1) {
    my $left = $deadline - time();
    if ($left <= 0) {
        terminate_owned($pid);
        1 while waitpid(-1, 0) > 0;
        die "FAIL: the probe did not finish within 2 seconds\n";
    }
    next unless $select->can_read($left);
    my $count = sysread($read, my $chunk, 65536);
    last unless $count;
    $output .= $chunk;
}
waitpid($pid, 0);
my $status = $?;
1 while waitpid(-1, 0) > 0;
print $output;
die "$config->{failure}\n"
    if $status
    || $output =~ /LOST_WAKEUP/
    || $output !~ /INJECTED_EXIT/
    || grep { index($output, $_) < 0 } $config->{required}->@*;
say $config->{success};
