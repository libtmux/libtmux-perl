use v5.44;
use FindBin;
use lib "$FindBin::Bin/../packages/core/lib";
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Copy qw(copy);
use Cwd        qw(abs_path getcwd);
use Archive::Tar;
use CPAN::Meta;
use JSON::PP    ();
use Digest::SHA qw(sha256_hex);
use LibTmux::Transport;
chdir "$FindBin::Bin/.." or die $!;
my $root = getcwd();
open my $prefix_file, '<', '.cache/consumer-prefix'
    or die "Provision the isolated consumer prefix first\n";
chomp(my $prefix = <$prefix_file>);
close $prefix_file;
die 'consumer prefix must be outside the checkout'
    if index(abs_path($prefix), $root) == 0;
my $build = tempdir('libtmux-perl-artifacts-XXXX', TMPDIR => 1, CLEANUP => 1);
make_path('.cache/artifacts');
open my $log, '>:raw', '.cache/artifacts/build.log' or die $!;
my @evidence;

sub run ($cwd, @argv) {
    my $old = getcwd();
    chdir $cwd or die $!;
    my $result = LibTmux::Transport->run(
        argv       => \@argv,
        timeout    => 25,
        max_output => 8 * 1024 * 1024,
        env        => {PERL5LIB => "$prefix/lib/perl5:$root/local/lib/perl5"}
    );
    chdir $old or die $!;
    print {$log} join(' ', @argv), "\n", $result->stdout, $result->stderr;
    die "Artifact command failed; see .cache/artifacts/build.log\n"
        unless $result->success;
    return $result;
}
for my $package (qw(core workspace async)) {
    my $dir = "$root/packages/$package";
    unlink $_
        or die $!
        for grep { -f $_ } (
        "$dir/MANIFEST",
        glob("$dir/LibTmux*.tar"),
        glob("$dir/LibTmux*.tar.gz")
        );
    run($dir, $^X,    'Makefile.PL');
    run($dir, 'make', 'manifest');
    run($dir, 'make', 'dist');
    my @archives = glob "$dir/LibTmux*.tar.gz";
    die "expected one $package archive" unless @archives == 1;
    (my $name = $archives[0]) =~ s!.*/!!;
    my $target = "$root/.cache/artifacts/$name";
    copy($archives[0], $target) or die $!;
    my $tar   = Archive::Tar->new($target, 1);
    my @files = $tar->list_files;
    (my $top = $name) =~ s/\.tar\.gz\z//;
    my %included = map { $_ => true } @files;
    die 'missing independent package files'
        unless !grep { !$included{"$top/$_"} }
        qw(LICENSE README.md cpanfile Makefile.PL MANIFEST META.json META.yml);
    die 'archive contains build or author environment'
        if grep { m!/(?:blib|local|\.cache)/! } @files;
    die 'archive contains another archive'
        if grep { /\.tar(?:\.gz)?\z/ } @files;
    my $meta = CPAN::Meta->load_json_string($tar->get_content("$top/META.json"),
        {lazy_validation => 0});
    my $prereqs = $meta->effective_prereqs;

    for my $tool (qw(Test2::V1 Perl::Tidy Module::CPANfile)) {
        die "author/configure dependency leaked to runtime: $tool"
            if defined $prereqs->requirements_for('runtime', 'requires')
            ->requirements_for_module($tool);
    }
    die 'test bundle is not explicit'
        unless defined $prereqs->requirements_for('test', 'requires')
        ->requirements_for_module('Test2::V1');
    chdir $build  or die $!;
    $tar->extract or die 'extract archive';
    chdir $root   or die $!;
    run("$build/$top", $^X,    'Makefile.PL', 'INSTALL_BASE=' . $prefix);
    run("$build/$top", 'make', 'test');
    run("$build/$top", 'make', 'install');
    open my $archive, '<:raw', $target or die $!;
    my $digest = Digest::SHA->new(256)->addfile($archive)->hexdigest;
    close $archive;
    push @evidence,
        {
        package => $package,
        file    => $name,
        sha256  => $digest,
        modules => [sort keys $meta->provides->%*]
        };
    print "$name installed and native tests passed\n";
}
my $consumer = LibTmux::Transport->run(
    argv    => [$^X, "$root/scripts/installed-consumer.pl"],
    timeout => 1,
    env => {PERL5LIB => "$prefix/lib/perl5", LIBTMUX_CONSUMER_PREFIX => $prefix}
);
print {$log} $consumer->stdout, $consumer->stderr;
die 'installed import/POD provenance check failed' unless $consumer->success;
open my $out, '>:raw', '.cache/artifacts/evidence.json' or die $!;
print {$out} JSON::PP->new->canonical->pretty->encode(
    {
        schema    => 1,
        artifacts => \@evidence,
        consumer  => 'PASS',
        perl      => "$^V",
        source    => run($root, 'git', 'rev-parse', 'HEAD')->stdout
    }
);
close $out;
print "Installed consumer origins, isolated core imports, and POD: PASS\n";
