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
            defined($signal) && "$signal" =~ /interrupted by TERM/,
'catchable cancellation runs teardown before returning the signal failure'
        );
        T2->is($borrowed->snapshot->sessions->count,
            1, 'signal teardown preserves borrowed fixture resources');
    }
);
T2->done_testing;
