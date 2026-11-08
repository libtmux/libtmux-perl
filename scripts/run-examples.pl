use v5.44;
use FindBin;
use lib "$FindBin::Bin/../packages/core/lib";
use lib "$FindBin::Bin/lib";
use Cwd qw(getcwd abs_path);
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

for my $file (sort glob 'examples/*.pl') {
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
    my $result = LibTmux::Transport->run(
        argv    => ['python3', 'scripts/with-subreaper.py', $^X, $file],
        timeout => 2,
        env     => {PERL5LIB => join(':', @libraries)}
    );
    die "$file failed:\n" . $result->stdout . $result->stderr
        unless $result->success;
    print "$file: ", $result->stdout;
}
