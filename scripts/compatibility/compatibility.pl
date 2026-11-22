use v5.44;
use FindBin;
use Cwd          qw(abs_path);
use Digest::SHA  ();
use File::Path   qw(make_path);
use Getopt::Long qw(GetOptions);
use JSON::PP     ();
use POSIX        qw(setsid);
use Time::HiRes  qw(time);

# Qualify owned Linux tmux fixtures. Each argument is VERSION=BINARY, such as
# 3.3a=/path/to/tmux. For every one the script checks that the binary reports
# that version, then runs every integration suite and the runnable examples
# against it, one cell per tmux in parallel. It writes a log per command and
# evidence-VERSION.json (evidence-all.json for several) under .cache/compatibility.
#
#   perl scripts/compatibility/compatibility.pl \
#       [--installed PREFIX] VERSION=BINARY...
#
# --installed runs the suites against a qualified consumer prefix outside the
# checkout. --root and --timeout exist for the script's own test.
my $root      = abs_path("$FindBin::Bin/../..");
my $timeout   = 25;
my $installed = undef;
GetOptions(
    'installed=s' => \$installed,
    'root=s'      => \$root,
    'timeout=i'   => \$timeout
) or die "Usage: compatibility.pl [--installed PREFIX] VERSION=BINARY...\n";
my %binary;

for my $pair (@ARGV) {
    my ($version, $path) = $pair =~ /\A([0-9][^=]*)=(.+)\z/
        or die
        "Usage: compatibility.pl [--installed PREFIX] VERSION=BINARY...\n";
    $binary{$version} = abs_path($path) // die "$path: $!\n";
}
die "Usage: compatibility.pl [--installed PREFIX] VERSION=BINARY...\n"
    unless %binary;
die "required qualification platform is Linux\n" unless $^O eq 'linux';
chdir $root or die "$root: $!\n";
my $logs = "$root/.cache/compatibility";
make_path($logs);

sub text_of (@command) {
    open my $out, '-|', @command or die "$command[0]: $!\n";
    my $text = do { local $/; <$out> };
    close $out;
    return $text;
}

# Run one command with its output in a log. After $timeout seconds the command's
# whole process group is killed and the status is 124.
sub run_logged ($log, @command) {
    my $start = time();
    my $pid   = fork() // die "fork: $!\n";
    if (!$pid) {
        setsid();
        open STDIN,  '<',  '/dev/null' or POSIX::_exit(126);
        open STDOUT, '>',  $log        or POSIX::_exit(126);
        open STDERR, '>&', \*STDOUT    or POSIX::_exit(126);
        exec {$command[0]} @command or POSIX::_exit(127);
    }
    my $code;
    {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm $timeout;
        my $finished = eval { waitpid($pid, 0); 1 };
        alarm 0;
        if ($finished) {
            $code = $? & 127 ? 128 + ($? & 127) : $? >> 8;
        }
        else {
            kill 'KILL', -$pid;
            waitpid($pid, 0);
            $code = 124;
        }
    }
    return ($code, time() - $start);
}

sub qualify ($version, $tmux) {
    my $reported = text_of($tmux, '-V');
    chomp $reported;
    return {
        version => $version,
        status  => 'FAIL',
        reason  => "binary reports '$reported', not 'tmux $version'"
        }
        unless $reported eq "tmux $version";
    my @libraries =
        $installed
        ? ("-I$installed/lib/perl5", '-Ilocal/lib/perl5', '-Iscripts/lib')
        : (
        '-Ilocal/lib/perl5',    '-Ipackages/core/lib',
        '-Ipackages/async/lib', '-Ipackages/workspace/lib',
        '-Iscripts/lib'
        );
    delete local @ENV{qw(TMUX TMUX_PANE LIBTMUX_SOCKET LIBTMUX_SOCKET_PATH)};
    local $ENV{LIBTMUX_TEST_TMUX} = $tmux;
    local $ENV{LIBTMUX_TEST_CLI}  = "$installed/bin/libtmux-workspace"
        if $installed;
    my @suites = map { sort glob("packages/$_/t/integration/*.t") }
        qw(core async workspace);
    my @commands = (
        (
            map {
                [
                    $^X, 'scripts/with-subreaper/with-subreaper.pl',
                    $^X, @libraries, $_
                ]
            } @suites
        ),
        [
            $^X,
            'scripts/run-examples.pl',
            $installed ? ('--installed', $installed) : ()
        ],
    );
    my @checks;

    for my $index (0 .. $#commands) {
        my $log = "$logs/$version-$index.log";
        my ($code, $elapsed) = run_logged($log, $commands[$index]->@*);
        push @checks,
            {
            argv            => $commands[$index],
            exit_status     => $code,
            elapsed_seconds => 0 + sprintf('%.4f', $elapsed),
            evidence        => ".cache/compatibility/$version-$index.log",
            };
    }
    my $status = (grep { $_->{exit_status} } @checks) ? 'FAIL' : 'PASS';
    return {
        version => $version,
        status  => $status,
        binary  => $tmux,
        checks  => \@checks
    };
}

my $start = time();
my %reader;
for my $version (sort keys %binary) {
    pipe(my $read, my $write) or die $!;
    my $pid = fork() // die "fork: $!\n";
    if (!$pid) {
        close $read;
        my $cell = qualify($version, $binary{$version});
        say "$version: $cell->{status}";
        print {$write} JSON::PP->new->canonical->encode($cell);
        close $write;
        STDOUT->flush;
        POSIX::_exit(0);
    }
    close $write;
    $reader{$version} = [$pid, $read];
}
my @cells;
for my $version (sort keys %reader) {
    my ($pid, $read) = $reader{$version}->@*;
    my $json = do { local $/; <$read> };
    waitpid($pid, 0);
    push @cells, JSON::PP->new->decode($json);
}
my $diff =
    Digest::SHA->new(256)->add(text_of('git', 'diff', 'HEAD'))->hexdigest;
my $evidence = {
    schema          => 1,
    source_revision => text_of('git', 'rev-parse', 'HEAD') =~ s/\s+\z//r,
    diff_sha256     => $diff,
    perl            => "$^V",
    os              => text_of('uname', '-srm') =~ s/\s+\z//r,
    elapsed_seconds => 0 + sprintf('%.4f', time() - $start),
    cells           => \@cells,
};
my $name = @cells == 1 ? $cells[0]{version} : 'all';
open my $out, '>', "$logs/evidence-$name.json" or die "evidence: $!\n";
print {$out} JSON::PP->new->canonical->pretty->encode($evidence);
close $out or die "evidence: $!\n";
exit((grep { $_->{status} ne 'PASS' } @cells) ? 1 : 0);
