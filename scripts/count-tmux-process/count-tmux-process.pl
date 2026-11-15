#!/usr/bin/env perl
use v5.44;
use Fcntl    qw(O_WRONLY O_APPEND O_CREAT);
use JSON::PP ();

# The benchmark runs this in place of tmux. It appends the command and
# supervisor process ids to LIBTMUX_BENCH_LOG, then execs LIBTMUX_BENCH_TMUX
# with the same arguments, so the log counts the processes each mode starts.
sub setting ($name) { $ENV{$name} // die("$name is not set\n") }
my $log    = setting('LIBTMUX_BENCH_LOG');
my $tmux   = setting('LIBTMUX_BENCH_TMUX');
my %record = (
    mode           => setting('LIBTMUX_BENCH_MODE'),
    command_pid    => $$,
    supervisor_pid => getppid(),
);
sysopen(my $out, $log, O_WRONLY | O_APPEND | O_CREAT, 0600)
    or die "$log: $!\n";
syswrite($out, JSON::PP->new->canonical->encode(\%record) . "\n");
close $out or die "$log: $!\n";
exec {$tmux} $tmux, @ARGV or die "exec $tmux: $!\n";
