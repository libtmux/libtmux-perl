use v5.44;
use FindBin;
use lib "$FindBin::Bin/lib";
use Getopt::Long qw(GetOptions);
use JSON::PP     ();
use LibTmuxRelease;

my ($tag, $source, $directory, $publish, $check_tag);
GetOptions(
    'tag=s'       => \$tag,
    'source=s'    => \$source,
    'artifacts=s' => \$directory,
    'publish'     => \$publish,
    'check-tag'   => \$check_tag
    )
    or die
"Usage: release.pl --tag v0.002 --source SHA --artifacts DIRECTORY [--publish]\n";
die "Unexpected positional arguments\n" if @ARGV;
my $plan = LibTmuxRelease->plan(
    tag       => $tag,
    source    => $source,
    directory => $directory
);
LibTmuxRelease->check_tag($tag, $source) if $check_tag || $publish;

if ($publish) {
    my $receipt = LibTmuxRelease->upload($plan, token => $ENV{PAUSE_TOKEN},);
    say JSON::PP->new->canonical->pretty->encode($receipt);
}
else {
    say JSON::PP->new->canonical->pretty->encode({%$plan, publish => false});
}
