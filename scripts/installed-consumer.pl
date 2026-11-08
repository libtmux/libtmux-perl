use v5.44;
use Cwd qw(abs_path);
use Pod::Simple::SimpleTree;
use LibTmux;
use LibTmux::Server;
use LibTmux::PaneSelection;
my $prefix = $ENV{LIBTMUX_CONSUMER_PREFIX} // die 'missing prefix';
die 'core loaded optional async dependencies'
    if grep { /\A(?:Future|IO\/(?:Async|Ppoll))/ } keys %INC;
use LibTmux::Workspace;
my $plan = LibTmux::Workspace->new(
    config => {schema => 'libtmux.workspace/v1', sessions => []})->plan;
die 'empty workspace plan' unless $plan->{sessions}->@* == 0;
require LibTmux::Async::Server;

for my $module (
    grep {
/\A(?:LibTmux(?:\/|\.pm)|Future(?:\/|\.pm)|IO\/(?:Async(?:\/|\.pm)|Ppoll\.pm))/
    } keys %INC
    )
{
    die "module origin outside installed artifact: $module"
        unless index(abs_path($INC{$module}), abs_path($prefix) . '/') == 0;
}
for my $module (qw(LibTmux::Server LibTmux::Workspace LibTmux::Async::Server)) {
    (my $key = $module) =~ s!::!/!g;
    my $pod = $INC{$key . '.pm'};
    die "installed POD absent: $module"
        unless $pod && index(abs_path($pod), abs_path($prefix) . '/') == 0;
    my $parser = Pod::Simple::SimpleTree->new;
    $parser->parse_file($pod);
    die "installed POD has no content: $module" unless @{$parser->root} > 2;
}
print
    "installed module/POD origins and optional-dependency boundary verified\n";
