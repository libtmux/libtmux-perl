use v5.44;
use Test2::V1;
use File::Temp qw(tempdir);
use FindBin;

my $root =
    tempdir('libtmux-perl-provision-test-XXXX', TMPDIR => 1, CLEANUP => 1);
my $cpm = "$root/cpm";
open my $fake, '>', $cpm or die "$cpm: $!";
print {$fake} <<'PERL';
open my $log, '>>', "$ENV{PROVISION_LOG}" or die $!;
print {$log} join(' ', @ARGV), "\n";
exit($ENV{PROVISION_FAIL} ? 3 : 0);
PERL
close $fake;
local $ENV{PROVISION_LOG} = "$root/calls";
my $script = "$FindBin::Bin/../provision-consumer.pl";

sub provision (%env) {
    local @ENV{keys %env} = values %env;
    return system($^X, $script, '--cpm', $cpm, '--cache', "$root/cache") >> 8;
}

T2->is(provision(), 0, 'the first run provisions');
open my $in, '<', "$root/cache/consumer-prefix" or die $!;
chomp(my $prefix = <$in>);
T2->ok(-d $prefix, 'the recorded consumer prefix exists');
T2->like($prefix, qr/libtmux-perl-consumer-/,
    'the prefix is a temporary directory');
provision();
open my $calls, '<', "$root/calls" or die $!;
my @calls = <$calls>;
T2->is(
    $calls[0],
    "install --local-lib-contained $prefix --final-install runtime "
        . "Future\@0.54 IO::Async\@0.805 IO::Async::Loop::Ppoll\@0.10 "
        . "IO::Ppoll\@0.14 Future::AsyncAwait\@0.71\n",
    'cpm installs the pinned runtime modules into the prefix'
);
T2->is($calls[1], $calls[0], 'a second run reuses the recorded prefix');
T2->isnt(provision(PROVISION_FAIL => 1),
    0, 'a failed cpm install fails the run');
unlink "$root/cache/consumer-prefix";
rmdir $prefix;
T2->done_testing;
