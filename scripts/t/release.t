use v5.44;
use Test2::V1;
use File::Temp qw(tempdir);
use Archive::Tar;
use Digest::SHA ();
use JSON::PP    ();
use LibTmuxRelease;
my $json   = JSON::PP->new->canonical->utf8;
my $source = 'a' x 40;

sub fixture (%changes) {
    my $root =
        tempdir('libtmux-perl-release-test-XXXX', TMPDIR => 1, CLEANUP => 1);
    my @records;
    for my $kind (qw(core workspace async)) {
        my $dist = 'LibTmux' . ($kind eq 'core' ? '' : '-' . ucfirst($kind));
        my $main = 'LibTmux' . ($kind eq 'core' ? '' : '::' . ucfirst($kind));
        my $version = '0.002';
        my $meta    = {
            'meta-spec' => {
                version => 2,
                url     => 'https://metacpan.org/pod/CPAN::Meta::Spec'
            },
            name           => $dist,
            version        => $version,
            abstract       => 'Release test fixture',
            author         => ['libtmux contributors'],
            license        => ['mit'],
            generated_by   => 'release tests',
            dynamic_config => 0,
            release_status => $changes{status} // 'stable',
            provides => {$main => {file => 'lib/Main.pm', version => $version}},
            prereqs  => {
                runtime => {
                    requires => {
                        perl => '5.044000',
                        $kind eq 'core'
                        ? ()
                        : (LibTmux => $changes{core} // $version)
                    }
                }
            },
        };
        my $tar = Archive::Tar->new;
        $tar->add_data("$dist-$version/META.json", $json->encode($meta));
        my $name = "$dist-$version.tar.gz";
        $tar->write("$root/$name", 1);
        open my $in, '<:raw', "$root/$name" or die $!;
        my $digest = Digest::SHA->new(256)->addfile($in)->hexdigest;
        close $in;
        push @records, {package => $kind, file => $name, sha256 => $digest};
    }
    open my $out, '>:raw', "$root/evidence.json" or die $!;
    print {$out} $json->encode(
        {
            source    => $changes{source}   // $source,
            consumer  => $changes{consumer} // 'PASS',
            clean     => exists($changes{clean}) ? $changes{clean} : true,
            artifacts => \@records
        }
    );
    close $out;
    return $root;
}
my $root = fixture();
my $plan = LibTmuxRelease->plan(
    tag       => 'v0.002',
    source    => $source,
    directory => $root
);
T2->is(
    [map { $_->{package} } $plan->{order}->@*],
    [qw(core workspace async)],
    'validated archives preserve dependency upload order'
);
for my $case (
    [{source   => 'b' x 40},  qr/source differs/,  'another source'],
    [{clean    => false},     qr/clean committed/, 'dirty source'],
    [{clean    => 'false'},   qr/clean committed/, 'invalid clean flag'],
    [{consumer => 'FAIL'},    qr/verification did not pass/, 'failed consumer'],
    [{status   => 'testing'}, qr/ordinary indexed/,          'trial metadata'],
    [{core => '0.001_001'},   qr/core requirement/, 'stale sibling dependency'],
    )
{
    my $directory = fixture($case->[0]->%*);
    my $error;
    try {
        LibTmuxRelease->plan(
            tag       => 'v0.002',
            source    => $source,
            directory => $directory
        )
    }
    catch ($caught) { $error = $caught }
    T2->like($error // '', $case->[1], "reject $case->[2] before upload");
}
my $wrong_tag;
try {
    LibTmuxRelease->plan(
        tag       => 'v0.003',
        source    => $source,
        directory => $root
    )
}
catch ($error) { $wrong_tag = $error }
T2->like($wrong_tag, qr/filename/, 'tag must identify the tested version');
open my $changed, '>>:raw', "$root/LibTmux-0.002.tar.gz" or die $!;
print {$changed} 'tampered';
close $changed;
my $tamper;
try {
    LibTmuxRelease->plan(
        tag       => 'v0.002',
        source    => $source,
        directory => $root
    )
}
catch ($error) { $tamper = $error }
T2->like($tamper, qr/digest differs/, 'modified archive is refused');

my $missing;
try { LibTmuxRelease->upload($plan) }
catch ($error) { $missing = $error }
T2->like($missing, qr/PAUSE_TOKEN/,
    'missing credentials fail before loading release-only HTTP dependencies');

my $repository =
    tempdir('libtmux-perl-tag-test-XXXX', TMPDIR => 1, CLEANUP => 1);
local $ENV{GIT_CONFIG_GLOBAL}   = '/dev/null';
local $ENV{GIT_CONFIG_NOSYSTEM} = 1;
system('git', '-C', $repository, 'init', '--quiet', '--initial-branch=master')
    == 0
    or die 'git init';
system('git', '-C', $repository, 'remote', 'add', 'origin',
    'https://github.com/libtmux/libtmux-perl.git') == 0
    or die 'git remote';
system(
    'git',                             '-C',
    $repository,                       '-c',
    'user.name=Release test',          '-c',
    'user.email=test@example.invalid', 'commit',
    '--allow-empty',                   '--quiet',
    '-m',                              'fixture'
) == 0 or die 'git commit';
open my $git, '-|', 'git', '-C', $repository, 'rev-parse', 'HEAD' or die $!;
chomp(my $commit = <$git>);
close $git;
system('git', '-C', $repository, 'update-ref', 'refs/remotes/origin/master',
    $commit) == 0
    or die 'git ref';
system(
    'git',                             '-C',
    $repository,                       '-c',
    'user.name=Release test',          '-c',
    'user.email=test@example.invalid', 'tag',
    '--annotate',                      'v0.002',
    '--message',                       'release fixture'
) == 0 or die 'git tag';
T2->ok(LibTmuxRelease->check_tag('v0.002', $commit, $repository),
    'tag binds the tested commit on master');
my $moved;
try { LibTmuxRelease->check_tag('v0.002', 'b' x 40, $repository) }
catch ($error) { $moved = $error }
T2->like($moved, qr/another commit/, 'tag/source mismatch is refused');
system(
    'git',                             '-C',
    $repository,                       '-c',
    'user.name=Release test',          '-c',
    'user.email=test@example.invalid', 'commit',
    '--allow-empty',                   '--quiet',
    '-m',                              'unmerged fixture'
) == 0 or die 'git commit';
open my $next, '-|', 'git', '-C', $repository, 'rev-parse', 'HEAD' or die $!;
chomp(my $unmerged = <$next>);
close $next;
system('git', '-C', $repository, 'tag', 'v0.003') == 0 or die 'git tag';
my $not_master;
try { LibTmuxRelease->check_tag('v0.003', $unmerged, $repository) }
catch ($error) { $not_master = $error }
T2->like(
    $not_master,
    qr/reachable from origin\/master/,
    'an unmerged release commit is refused'
);
system('git', '-C', $repository, 'remote', 'set-url', 'origin',
    'https://example.invalid/another-repository.git') == 0
    or die 'git remote';
my $not_origin;
try { LibTmuxRelease->check_tag('v0.002', $commit, $repository) }
catch ($error) { $not_origin = $error }
T2->like(
    $not_origin,
    qr/canonical libtmux\/libtmux-perl/,
    'a noncanonical origin is refused without contacting it'
);
T2->done_testing;
