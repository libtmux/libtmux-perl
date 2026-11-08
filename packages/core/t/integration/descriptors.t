use v5.44;
use Test2::V1;
use File::Temp qw(tempfile);
use POSIX      ();
use LibTmuxFixture;

my ($file, $path) =
    tempfile('libtmux-perl-daemon-fd-XXXX', TMPDIR => 1, UNLINK => 1);
my $fd = POSIX::dup(fileno($file));
die "dup: $!" unless defined $fd;
try {
    LibTmuxFixture->run(
        sub ($server, $root) {
            $server->new_session(
                name    => 'descriptor-owned',
                command => ['/bin/sleep', '120']
            );
            my $pid =
                0 + $server->cmd('display-message', '-p', '#{pid}')->stdout;
            opendir my $fds, "/proc/$pid/fd" or die $!;
            my @inherited = grep {
                /\A[0-9]+\z/ && (readlink("/proc/$pid/fd/$_") // '') eq $path
            } readdir $fds;
            closedir $fds;
            T2->is(\@inherited, [],
                'a newly started daemon inherits no caller descriptor');
        }
    );
    T2->is(POSIX::write($fd, 'parent', 6),
        6, 'daemon teardown preserves the caller descriptor');
}
catch ($error) { POSIX::close($fd); die $error }
POSIX::close($fd);
close $file;
T2->done_testing;
