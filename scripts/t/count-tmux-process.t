use v5.44;
use Test2::V1;
use File::Temp qw(tempdir);
use FindBin;
use JSON::PP ();

my $root = tempdir('libtmux-perl-count-test-XXXX', TMPDIR => 1, CLEANUP => 1);
my $tmux = "$root/tmux";
open my $fake, '>', $tmux or die "$tmux: $!";
print {$fake} "#!$^X\nprint join('|', \@ARGV), \"\\n\";\n";
close $fake;
chmod 0700, $tmux or die $!;
local $ENV{LIBTMUX_BENCH_MODE} = 'sync';
local $ENV{LIBTMUX_BENCH_TMUX} = $tmux;
local $ENV{LIBTMUX_BENCH_LOG}  = "$root/processes";

sub wrapped (@argv) {
    my $pid =
        open(my $out, '-|', "$FindBin::Bin/../count-tmux-process.pl", @argv)
        // die $!;
    my $text = do { local $/; <$out> };
    close $out;
    return ($pid, $text);
}

my ($pid, $text) = wrapped('display-message', '-p');
T2->is($text, "display-message|-p\n",
    'the wrapper runs tmux with its arguments');
wrapped('list-panes');
open my $in, '<', "$root/processes" or die $!;
my @records = map { JSON::PP->new->decode($_) } <$in>;
T2->is(
    $records[0],
    {mode => 'sync', command_pid => $pid, supervisor_pid => $$},
    'the record names the exec-preserved command and its supervisor'
);
T2->is(scalar(@records),                    2, 'each run appends one record');
T2->is((stat "$root/processes")[2] & 07777, 0600, 'the log is private');
T2->done_testing;
