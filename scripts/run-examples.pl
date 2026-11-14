use v5.44;
use FindBin;
use lib "$FindBin::Bin/../packages/core/lib";
use lib "$FindBin::Bin/lib";
use Cwd qw(getcwd abs_path);
use Archive::Tar;
use File::Temp     qw(tempdir);
use File::Path     qw(make_path);
use File::Basename qw(dirname);
use LibTmux::Transport;
use LibTmux::Platform::Linux;
use LibTmuxFixture;
chdir "$FindBin::Bin/.." or die $!;
LibTmux::Platform::Linux::_subreaper();
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
my $example_root = $root;

if ($installed) {
    $example_root =
        tempdir('libtmux-perl-examples-XXXX', TMPDIR => 1, CLEANUP => 1);
    for my $package (qw(core async workspace)) {
        my $distribution =
            $package eq 'core'
            ? 'LibTmux'
            : 'LibTmux-' . ucfirst($package);
        my @archives = glob ".cache/artifacts/$distribution-[0-9]*.tar.gz";
        die "expected one $package native archive\n" unless @archives == 1;
        my $tar = Archive::Tar->new($archives[0], 1);
        for my $entry ($tar->list_files) {
            next unless $entry =~ m!\A[^/]+/(examples/[a-z-]+\.(?:pl|json))\z!;
            my $relative = "packages/$package/$1";
            open my $source, '<:raw', $relative or die "$relative: $!";
            my $expected = do { local $/; <$source> };
            close $source;
            my $content = $tar->get_content($entry);
            die "native archive example differs from source: $relative\n"
                unless $content eq $expected;
            my $target = "$example_root/$relative";
            make_path(dirname($target));
            open my $out, '>:raw', $target or die "$target: $!";
            print {$out} $content;
            close $out or die $!;
        }
    }
}
my %expected_stdout = (
    'packages/core/examples/quickstart.pl' =>
        ['editor: 2 panes', 'logs: 1 pane', 'side pane: 20 columns'],
    'examples/quickstart.pl' => [
        'session demo',
        'window 0:editor:',
        'window 1:logs:',
        'is in window editor'
    ],
    'examples/selection.pl' =>
        ['selection, wire, graph lifetime, quantifiers, and query: ok'],
    'examples/workspace.pl' => ['workspace load and repeat: ok'],
    'examples/async.pl'     => ['async capture and cleanup: ok'],
    'examples/await.pl'     => ['optional caller await syntax: ok'],
    'packages/core/examples/workflow.pl' => [
        'editor panes: 2',
        'active pane belongs to editor',
        'PROJECT=api',
        'restored filter matches: 1',
        'same child: 0',
        'different children: 1',
        'native verification: agreed',
        'captured name: logs',
        'core workflow: ok',
    ],
    'packages/core/examples/select.pl' => [
        'editor panes: 2',
        'active pane belongs to editor',
        'no pane is that wide',
    ],
    'packages/core/examples/input.pl' =>
        ['PROJECT=api', '@build=ok', "perl-input\n0\n",],
    'packages/core/examples/graph.pl' =>
        ['captured name: logs', 'live name: build',],
    'packages/core/examples/explain.pl' => [
        'tmux filter: #{&&:#{==:#{pane_active},1},#{e|>=:#{pane_width},1}}',
        'stays local: window requires local relation',
        'pushdown off: local evaluation; pushdown disabled',
    ],
    'packages/core/examples/filters.pl' => [
        'matching records: %1',
        'restored filter matches: 1',
        'invalid operand at pane.where.width.-gte',
        'expected: safe decimal integer',
        'filter records and wire: ok',
    ],
    'packages/async/examples/concurrent.pl' => [
        'async active panes: 1',
        "first\nsecond\n",
        'async operations and cleanup: ok',
    ],
    'packages/workspace/examples/load.pl' => [
        'planned sessions: 1',
        'loaded windows: 2',
        'editor panes: 2',
        'skipped existing sessions: 1',
        'workspace plan, load, repeat: ok',
    ],
);

my %owned_only = map { $_ => true } qw(
    packages/core/examples/select.pl
    packages/core/examples/input.pl
    packages/core/examples/graph.pl
);

# With no socket argument a program owns its private server and removes it.
my $run_owned = sub ($file, $program, $socket_root) {
    my $private  = "$socket_root/private";
    my $selected = $ENV{LIBTMUX_TEST_TMUX} // 'tmux';
    mkdir $private or die "$private: $!";
    my %before = map { $_ => true } LibTmuxFixture::_children($$);
    my $owned  = LibTmux::Transport->run(
        argv    => [$^X, $program],
        timeout => 3,
        env     => {
            PERL5LIB => join(':', @libraries),
            TMPDIR   => $private,
            $selected =~ m!/!
            ? (PATH => dirname($selected) . ":$ENV{PATH}")
            : (),
        },
    );
    die "$file failed without a socket argument:\n"
        . $owned->stdout
        . $owned->stderr
        unless $owned->success;
    for my $line ($expected_stdout{$file}->@*) {
        die "$file missing expected output without a socket: $line\n"
            unless index($owned->stdout, $line) >= 0;
    }

    # A daemon that outlived the program is still a child of this subreaper.
    local $SIG{ALRM} = sub { die "$file left its tmux server running\n" };
    alarm 1;
    waitpid($_, 0) for grep { !$before{$_} } LibTmuxFixture::_children($$);
    alarm 0;
    opendir my $directory, $private or die "$private: $!";
    my @left = grep { !/\A\.\.?\z/ } readdir $directory;
    die "$file left $left[0] in its private directory\n" if @left;
    print "$file: ", $owned->stdout;
};

for my $file (sort(glob('examples/*.pl'), glob('packages/*/examples/*.pl'))) {
    my $program = $file =~ m!\Apackages/! ? "$example_root/$file" : $file;
    die "example absent from native archive: $file\n"
        if $installed && $file =~ m!\Apackages/! && !-f $program;
    if ($owned_only{$file}) {
        LibTmuxFixture->run(
            sub ($server, $socket_root) {
                $run_owned->($file, $program, $socket_root);
            }
        );
        next;
    }
    if ($file =~ m!\Apackages/! && $file !~ m!/(?:filters|explain)\.pl\z!) {
        LibTmuxFixture->run(
            sub ($server, $socket_root) {
                my $sentinel = $server->new_session(
                    name    => 'borrowed-session',
                    command => [$^X, '-e', 'while (<STDIN>) { print }'],
                );
                my $result = LibTmux::Transport->run(
                    argv => [
                        $^X,              $program,
                        "$socket_root/s", $ENV{LIBTMUX_TEST_TMUX} // 'tmux'
                    ],
                    timeout => 3,
                    env     => {PERL5LIB => join(':', @libraries)},
                );
                die "$file failed:\n" . $result->stdout . $result->stderr
                    unless $result->success;
                for my $line ($expected_stdout{$file}->@*) {
                    die "$file missing expected output: $line\n"
                        unless index($result->stdout, $line) >= 0;
                }
                my $remaining = $server->snapshot->sessions->one;
                die
"$file changed borrowed resources or left its session behind"
                    unless $remaining->id eq $sentinel->id;
                print "$file: ", $result->stdout;

                $run_owned->($file, $program, $socket_root);
            }
        );
        next;
    }
    if ($file eq 'examples/async-lifecycle.pl') {
        LibTmuxFixture->run(
            sub ($server, $socket_root) {
                $server->new_session(
                    name    => 'async-consumer',
                    command => ['/bin/sleep', '120']
                );
                for my $mode ('', '--fail', '--cancel') {
                    my $result = LibTmux::Transport->run(
                        argv => [
                            $^X,
                            $file,
                            '--socket',
                            "$socket_root/s",
                            '--tmux',
                            $ENV{LIBTMUX_TEST_TMUX} // 'tmux',
                            length($mode) ? ($mode) : ()
                        ],
                        timeout => 2,
                        env     => {PERL5LIB => join(':', @libraries)},
                    );
                    my $expected =
                          $mode eq '--cancel' ? 'capture cancelled'
                        : $mode eq '--fail'   ? 'LibTmux::X::Command'
                        :                       'captured panes: 1';
                    die "$file $mode did not complete its lifecycle:\n"
                        . $result->stdout
                        . $result->stderr
                        unless $result->success == ($mode ne '--fail')
                        && index($result->stdout . $result->stderr, $expected)
                        >= 0
                        && index($result->stdout, 'executor cleanup: complete')
                        >= 0;
                    die 'closing the example destroyed its borrowed server'
                        unless $server->snapshot->sessions->one->name eq
                        'async-consumer';
                    print "$file $mode: ", $result->stdout;
                }
            }
        );
        next;
    }
    my $expected = $expected_stdout{$file}
        // die "$file has no declared expected output\n";
    my $result = LibTmux::Transport->run(
        argv => $file =~ m!\Apackages/!
        ? [$^X, $program]
        : ['python3', 'scripts/with-subreaper.py', $^X, $file],
        timeout => 2,
        env     => {PERL5LIB => join(':', @libraries)}
    );
    die "$file failed:\n" . $result->stdout . $result->stderr
        unless $result->success;
    for my $line (@$expected) {
        die "$file missing expected output: $line\n"
            unless index($result->stdout, $line) >= 0;
    }
    print "$file: ", $result->stdout;
}
