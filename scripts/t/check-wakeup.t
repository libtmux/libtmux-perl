use v5.44;
use Test2::V1;
use FindBin;

# Each run compiles a C interposer, so this needs a C compiler like the
# make check-async-wakeup and check-supervisor-wakeup targets.
my $script = "$FindBin::Bin/../check-wakeup.pl";

sub check (@argv) {
    my $pid = open(my $out, '-|') // die $!;
    if (!$pid) {
        open STDERR, '>&', \*STDOUT or die $!;
        exec $^X, $script, @argv or die "$script: $!";
    }
    my $text = do { local $/; <$out> };
    close $out;
    return ($? >> 8, $text);
}

my ($status, $text) = check('async');
T2->is($status, 0, 'an injected exit wakes the Ppoll loop');
T2->like($text, qr/^PASS: injected exit wakes the loop/m, 'async reports it');
($status, $text) = check('supervisor');
T2->is($status, 0, 'an injected exit wakes the supervisor');
T2->like($text, qr/^completed=0$/m, 'the supervisor completed the job');
($status, $text) = check('async', '--loop', 'Poll');
T2->isnt($status, 0, 'the negative control fails on the rejected backend');
T2->like($text, qr/^LOST_WAKEUP$/m,
    'the failure is the lost wakeup, not a setup error');
($status, $text) = check('other');
T2->isnt($status, 0, 'an unknown mode is a usage error');
T2->like($text, qr/^Usage: check-wakeup\.pl/m, 'the usage line is printed');
T2->done_testing;
