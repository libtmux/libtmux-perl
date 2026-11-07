use v5.44;
use FindBin;
use lib "$FindBin::Bin/../packages/core/lib";
use Cwd qw(getcwd abs_path);
use LibTmux::Transport;
chdir "$FindBin::Bin/.." or die $!;
my $root      = getcwd();
my $installed = @ARGV && $ARGV[0] eq '--installed' ? $ARGV[1] : undef;
die 'Usage: run-examples.pl [--installed PREFIX]'
    if @ARGV && (!defined($installed) || @ARGV != 2);
my @libraries =
    $installed
    ? ("$installed/lib/perl5")
    : (
    "$root/local/lib/perl5",
    map { "$root/packages/$_/lib" } qw(core async workspace)
    );

for my $file (sort glob 'examples/*.pl') {
    my $result = LibTmux::Transport->run(
        argv    => ['python3', 'scripts/with-subreaper.py', $^X, $file],
        timeout => 2,
        env     => {PERL5LIB => join(':', @libraries)}
    );
    die "$file failed:\n" . $result->stdout . $result->stderr
        unless $result->success;
    print "$file: ", $result->stdout;
}
