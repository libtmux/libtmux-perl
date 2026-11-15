use v5.44;
use Test2::V1;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin;
use JSON::PP ();

# A fake checkout: one passing, one failing and one hanging integration suite,
# stand-ins for the subreaper wrapper and the example runner, and a fake tmux.
my $root = tempdir('libtmux-perl-compat-test-XXXX', TMPDIR => 1, CLEANUP => 1);

sub write_file ($path, $text) {
    make_path($path =~ s{/[^/]+\z}{}r);
    open my $out, '>', $path or die "$path: $!";
    print {$out} $text;
    close $out or die "$path: $!";
}
write_file("$root/scripts/with-subreaper/with-subreaper.pl",
    'exec {$ARGV[0]} @ARGV');
write_file("$root/scripts/run-examples.pl",                 'exit 0');
write_file("$root/packages/core/t/integration/pass.t",      'exit 0');
write_file("$root/packages/async/t/integration/fail.t",     'exit 3');
write_file("$root/packages/workspace/t/integration/hang.t", 'sleep 30');
my $tmux = "$root/tmux";
write_file($tmux, "#!$^X\nprint \"tmux \$ENV{FAKE_TMUX_VERSION}\\n\";\n");
chmod 0700, $tmux or die $!;
system('git', 'init', '-q', $root) == 0 or die 'git init failed';
system('git', '-C', $root, '-c', 'user.name=t', '-c',
    'user.email=t@example.com',
    'commit', '-q', '--allow-empty', '-m', 'fixture') == 0
    or die 'git commit failed';

sub qualify ($version, %env) {
    local @ENV{keys %env} = values %env;
    my $status = system($^X, "$FindBin::Bin/../compatibility.pl",
        '--root', $root, '--timeout', 1, "$version=$tmux") >> 8;
    open my $in, '<', "$root/.cache/compatibility/evidence-$version.json"
        or die "no evidence for $version: $!";
    return ($status, JSON::PP->new->decode(do { local $/; <$in> }));
}

local $ENV{FAKE_TMUX_VERSION} = '3.8';
my ($status, $evidence) = qualify('3.3a');
T2->is($status, 1, 'a binary of another version fails');
T2->like(
    $evidence->{cells}[0]{reason},
    qr/reports 'tmux 3\.8', not 'tmux 3\.3a'/,
    'the cell names the version mismatch'
);

local $ENV{FAKE_TMUX_VERSION} = '3.8';
($status, $evidence) = qualify('3.8');
my %code = map { $_->{argv}[-1] =~ s{.*/}{}r => $_->{exit_status} }
    $evidence->{cells}[0]{checks}->@*;
T2->is($status, 1, 'a failing or hanging suite fails the cell');
T2->is(
    \%code,
    {'pass.t' => 0, 'fail.t' => 3, 'hang.t' => 124, 'run-examples.pl' => 0},
    'each command keeps its exit status and a hang is cut off with 124'
);
T2->ok(-e "$root/.cache/compatibility/3.8-0.log", 'each command has a log');

unlink "$root/packages/async/t/integration/fail.t",
    "$root/packages/workspace/t/integration/hang.t";
($status, $evidence) = qualify('3.8');
T2->is($status, 0, 'passing suites and examples pass the cell');
T2->is($evidence->{cells}[0]{status}, 'PASS', 'the evidence records PASS');
T2->done_testing;
