use v5.44;
use Test2::V1;
use File::Temp qw(tempdir);
use POSIX      qw(mkfifo WNOHANG);
use Errno      qw(ECHILD);
use LibTmux::Transport;
use LibTmux::Platform::Linux;
my $root = tempdir('libtmux-perl-lifecycle-XXXX', TMPDIR => 1, CLEANUP => 1);
mkfifo("$root/ready", 0600) or die $!;
open my $fifo, '+<', "$root/ready" or die $!;
my $code = q{
    my $child=fork();die $! unless defined $child;
    if (!$child) {
        $SIG{TERM}='IGNORE';close STDIN;close STDOUT;close STDERR;
        open my $ready,'>',$ARGV[0] or die $!;
        print {$ready} "$$\n";close $ready;
        sleep 120;exit;
    }
    waitpid($child,0);
};

for my $mode (qw(cancel INT TERM broken_signal)) {
    my ($signal_r, $signal_w, $job);
    my $start = sub {
        LibTmux::Transport->start(
            argv    => [$^X, '-e', $code, "$root/ready"],
            timeout => 0.8
        );
    };
    if ($mode eq 'broken_signal') {
        pipe($signal_r, $signal_w) or die $!;
        no warnings 'redefine';
        local *LibTmux::Platform::Linux::_signal_handle = sub { $signal_r };
        $job = $start->();
        close $signal_r;
    }
    else { $job = $start->() }
    my $ready = '';

    while ($ready !~ /\n/) {
        sysread($fifo, my $part, 32) or die $!;
        $ready .= $part;
    }
    my $descendant = 0 + $ready;
    if    ($mode eq 'cancel') { $job->cancel }
    elsif ($mode eq 'broken_signal') {
        syswrite($signal_w, 'x') == 1 or die $!;
        close $signal_w;
    }
    else { kill $mode, $job->pid }
    my $error;
    try { $job->wait } catch ($caught) {
        $error = $caught
    }
    my $type = $mode eq 'broken_signal' ? 'Transport' : 'Cancelled';
    T2->ok(ref($error) && $error->isa("LibTmux::X::$type"),
        "$mode retains typed outcome");
    my $waited   = waitpid($descendant, WNOHANG);
    my $no_child = $waited < 0 && $! == ECHILD;
    my $alive    = kill 0, $descendant;
    if ($alive) { kill 'KILL', $descendant; waitpid($descendant, 0) }
    T2->ok(
        $no_child && !$alive && $job->cleanup_complete,
        "$mode reaps the owned descendant before completion"
    );
}
my $cancel_code = q{
    use v5.44;use LibTmux::Transport;
    $SIG{PIPE}='DEFAULT';
    my $job=LibTmux::Transport->start(argv=>[$^X,'-e','exit 0']);
    waitpid($job->pid,0);
    $job->cancel;
    print 'caller survived';
};
my $result = LibTmux::Transport->run(argv =>
        [$^X, (map { ('-I', $_) } grep { !ref($_) } @INC), '-e', $cancel_code]);
T2->is(
    $result->stdout,
    'caller survived',
    'late cancellation cannot signal the caller'
);
T2->is($result->signal, 0, 'SIGPIPE disposition does not kill the caller');
close $fifo;
T2->done_testing;
