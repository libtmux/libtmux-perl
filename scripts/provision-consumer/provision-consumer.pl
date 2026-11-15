use v5.44;
use FindBin;
use File::Temp   qw(tempdir);
use File::Path   qw(make_path);
use Getopt::Long qw(GetOptions);

# Provision the optional consumer runtime dependencies outside verification
# loops. The prefix is a temporary directory outside the checkout; its path is
# recorded in CACHE/consumer-prefix, which check-artifacts.pl reads, and a later
# run reuses it while it exists.
#
#   perl scripts/provision-consumer/provision-consumer.pl [--cpm PATH] [--cache DIR]
my $root  = "$FindBin::Bin/../..";
my $cpm   = "$root/.cache/cpm";
my $cache = "$root/.cache";
GetOptions('cpm=s' => \$cpm, 'cache=s' => \$cache)
    or die "Usage: provision-consumer.pl [--cpm PATH] [--cache DIR]\n";
my $record = "$cache/consumer-prefix";
my $prefix;

if (open my $in, '<', $record) {
    chomp($prefix = <$in> // '');
    undef $prefix unless -d $prefix;
}
unless (defined $prefix) {
    $prefix = tempdir('libtmux-perl-consumer-XXXX', TMPDIR => 1, CLEANUP => 0);
    make_path($cache);
    open my $out, '>', $record or die "$record: $!\n";
    print {$out} "$prefix\n";
    close $out or die "$record: $!\n";
}
chdir $root or die "$root: $!\n";
system(
    $^X,               $cpm,
    'install',         '--local-lib-contained',
    $prefix,           '--final-install',
    'runtime',         'Future@0.54',
    'IO::Async@0.805', 'IO::Async::Loop::Ppoll@0.10',
    'IO::Ppoll@0.14',  'Future::AsyncAwait@0.71',
) == 0 or die "cpm install failed with status $?\n";
