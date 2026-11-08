use v5.44;
use Test2::V1;
use LibTmuxFixture;
my ($inner_root, $inner_pid, $primary);
my $thrown = bless {}, 'FixtureFailure';
LibTmuxFixture->run(
    sub ($borrowed, $root) {
        $borrowed->new_session(
            name    => 'borrowed-fixture',
            command => ['/bin/sleep', '120']
        );
        try {
            LibTmuxFixture->run(
                sub($owned, $dir) {
                    $inner_root = $dir;
                    $owned->new_session(
                        name    => 'fails',
                        command => ['/bin/sleep', '120']
                    );
                    $inner_pid = 0 +
                        $owned->cmd('display-message', '-p', '#{pid}')->stdout;
                    die $thrown;
                }
            );
        }
        catch ($error) { $primary = $error }
        T2->is($primary, $thrown,
            'fixture preserves the original thrown object');
        T2->ok(!-e $inner_root && !kill(0, $inner_pid),
            'exception cleanup removes owned server and temporary files');
        T2->is($borrowed->snapshot->sessions->one->name,
            'borrowed-fixture',
            'nested cleanup preserves the pre-existing server');
        my $signal;
        try {
            LibTmuxFixture->run(
                sub($owned, $dir) {
                    $owned->new_session(
                        name    => 'signal',
                        command => ['/bin/sleep', '120']
                    );
                    kill 'TERM', $$;
                    die 'TERM was not handled';
                }
            );
        }
        catch ($error) { $signal = $error }
        T2->ok(
            scalar(defined($signal) && "$signal" =~ /interrupted by TERM/),
'catchable cancellation runs teardown before returning the signal failure'
        );
        T2->is($borrowed->snapshot->sessions->count,
            1, 'signal teardown preserves borrowed fixture resources');

        for my $body_failure (undef, $thrown) {
            my $cleanup = LibTmux::X::Timeout->new(
                message    => 'injected kill-server failure',
                dispatched => true
            );
            my ($pid, $directory, $caught, @warnings);
            {
                no warnings qw(redefine once);
                local *LibTmuxFixture::Server::kill_server =
                    sub { die $cleanup };
                local $SIG{__WARN__} = sub { push @warnings, @_ };
                try {
                    LibTmuxFixture->run(
                        sub ($owned, $dir) {
                            $directory = $dir;
                            $owned->new_session(
                                name    => 'cleanup-failure',
                                command => ['/bin/sleep', '120']
                            );
                            $pid = $owned->{fixture_pid};
                            die $body_failure if defined $body_failure;
                        }
                    );
                }
                catch ($error) { $caught = $error }
            }
            T2->diag( "fixture failed before injected cleanup: "
                    . ($caught // 'no exception') . "\n"
                    . join('', @warnings))
                unless defined $pid;
            T2->is(
                refaddr($caught),
                refaddr($body_failure // $cleanup),
                'cleanup keeps the primary or original cleanup exception'
            );
            T2->ok(defined($pid) && !kill(0, $pid),
                'failed kill command still reaps the owned daemon');
            T2->ok(!-e $directory,
                'failed kill command still removes the owned directory');
            T2->like(
                join('', @warnings),
                qr/injected kill-server failure/,
                'secondary cleanup failure is reported'
            ) if defined $body_failure;
            T2->is($borrowed->snapshot->sessions->count,
                1, 'failed inner cleanup preserves the borrowed server');
        }
    }
);
my $diagnostic = LibTmux::Transport->run(
    argv => [
        $^X, (map { ('-I', $_) } grep { !ref($_) } @INC), '-e', q{
            use v5.44; use LibTmuxFixture;
            LibTmuxFixture->run(sub ($server, $root) {
                die LibTmux::X::Creation->new(
                    message => 'accepted creation',
                    cause => LibTmux::X::AcquisitionRace->new(
                        message => 'observed topology changed')
                );
            });
        }
    ]
);
T2->ok(!$diagnostic->success, 'fixture preserves a failing process exit');
T2->like(
    $diagnostic->stderr,
qr/AcquisitionRace: observed topology changed.*Creation: accepted creation/s,
    'failed fixture reports acquisition cause and primary failure'
);
T2->done_testing;
