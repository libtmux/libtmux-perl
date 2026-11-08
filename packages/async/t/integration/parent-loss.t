use v5.44;
use Test2::V1;
use POSIX      qw(mkfifo WNOHANG);
use File::Temp qw(tempdir);
my $root = tempdir('libtmux-perl-parent-loss-XXXX', TMPDIR => 1, CLEANUP => 1);
mkfifo("$root/ready", 0600) or die $!;
open my $ready, '+<', "$root/ready" or die $!;
my $caller_code = q{
    use v5.44;use IO::Async::Loop::Ppoll;use LibTmux::Async::Transport;
    my $loop=IO::Async::Loop::Ppoll->new;
    my $transport=LibTmux::Async::Transport->new(loop=>$loop,max_concurrent=>2);
    my $program=q{$|=1;print 'x'x131072;open my $r,'>',$ARGV[0] or die $!;print {$r} "$$\n";close $r;sleep 120};
    my @futures=map {$transport->execute(argv=>[$^X,'-e',$program,$ARGV[0]],timeout=>0.8)} 1..2;
    $loop->run;
};
my $caller = fork();
die $! unless defined $caller;

if (!$caller) {
    exec {$^X} $^X, (map { ('-I', $_) } grep { !ref($_) } @INC), '-e',
        $caller_code, "$root/ready";
    die $!;
}
my $markers = '';
while (scalar(() = $markers =~ /\n/g) < 2) {
    my $n = sysread($ready, my $chunk, 128);
    die $! unless $n;
    $markers .= $chunk;
}
open my $children, '<', "/proc/$caller/task/$caller/children" or die $!;
my @supervisors = split /\s+/, do { local $/; <$children> };
close $children;
kill 'KILL', $caller;
waitpid($caller, 0);
my ($exited, $failure) = (0, undef);
{
    local $SIG{ALRM} =
        sub { die 'owned supervisors did not exit after caller loss' };
    try {
        alarm 1;
        while (waitpid(-1, 0) > 0) { $exited++ }
        alarm 0
    }
    catch ($error) { alarm 0; $failure = $error }
}
if ($failure) {
    kill 'KILL', @supervisors;
    while (waitpid(-1, 0) > 0) { }
}
T2->ok(!defined($failure),
    'overlapping jobs close foreign pipes and exit after caller loss');
T2->is($exited, 2, 'both isolated supervisors exit and are reaped');
close $ready;
T2->done_testing;
