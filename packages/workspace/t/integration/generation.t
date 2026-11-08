use v5.44;
use Test2::V1;
use LibTmuxFixture;
use LibTmux::Workspace;

package RestartAfterWorkspaceCreate {
    use parent 'LibTmux::Server';

    sub new_session ($self, %args) {
        my $created = $self->SUPER::new_session(%args);
        my $pid     = 0 + $self->cmd('display-message', '-p', '#{pid}')->stdout;
        $self->kill_server;
        {
            local $SIG{ALRM} = sub { die 'old daemon exit deadline' };
            alarm 1;
            die 'old daemon exit not observed' unless waitpid($pid, 0) == $pid;
            alarm 0;
        }
        $self->{replacement} = $self->SUPER::new_session(
            name    => 'replacement',
            command => ['/bin/sleep', '120']
        );
        $self->{original} = $created;
        return $created;
    }
}

LibTmuxFixture->run(
    sub ($owner, $root) {
        my $server = RestartAfterWorkspaceCreate->new(
            socket_path => "$root/s",
            config_file => '/dev/null',
            executable  => $ENV{LIBTMUX_TEST_TMUX} // 'tmux',
            timeout     => 0.8
        );
        my $workspace = LibTmux::Workspace->new(
            config => {
                schema   => 'libtmux.workspace/v1',
                sessions => [
                    {
                        name        => 'original',
                        environment => {LIBTMUX_RESTART => 'written'},
                        windows     =>
                            [{panes => [{command => ['/bin/sleep', '120']}]}]
                    }
                ]
            }
        );
        my $error;
        try { $workspace->load(server => $server) } catch ($caught) {
            $error = $caught;
        }
        T2->isa_ok($error, ['LibTmux::Workspace::X::Load'], 'load fails');
        T2->isa_ok(
            $error->cause,
            ['LibTmux::X::StaleReference'],
            'original generation failure remains typed'
        );
        T2->is(
            $server->{original}->id,
            $server->{replacement}->id,
            'replacement actually reused the session ID'
        );
        T2->isnt(
            $server->{original}->generation,
            $server->{replacement}->generation,
            'replacement actually changed the daemon generation'
        );
        T2->is(
            $error->report->{failed_step},
            'set environment original.LIBTMUX_RESTART',
            'generation is checked before the environment mutation'
        );
        my $cleanup = $error->report->{cleanup_errors}[0];
        T2->isa_ok(
            $cleanup->{error},
            ['LibTmux::X::StaleReference'],
            'rollback preserves its own stale-generation exception'
        );
        T2->is(
            $cleanup->{target},
            $server->{original}->identity,
            'rollback failure names the original captured target'
        );

        for my $operation (
            qw(set_environment get_environment unset_environment))
        {
            my $stale;
            try {
                $server->$operation(
                    session => $server->{original},
                    name    => 'LIBTMUX_RESTART',
                    $operation eq 'set_environment' ? (value => 'changed') : ()
                );
            }
            catch ($caught) { $stale = $caught }
            T2->isa_ok(
                $stale,
                ['LibTmux::X::StaleReference'],
                "$operation rejects a captured target from the old daemon"
            );
        }
        my ($value, $missing);
        try {
            $value = $server->get_environment(
                session => $server->{replacement}->id,
                name    => 'LIBTMUX_RESTART'
            );
        }
        catch ($caught) { $missing = $caught }
        T2->is($value, undef, 'replacement received no environment value');
        T2->isa_ok($missing, ['LibTmux::X::Command'],
            'replacement variable is absent');
        T2->is($server->snapshot->sessions->one->name,
            'replacement', 'rollback preserves the replacement session');
    }
);
T2->done_testing;
