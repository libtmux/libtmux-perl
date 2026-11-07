use v5.44;
use Test2::V1;
use LibTmuxFixture;
use LibTmux::Workspace;
use LibTmux::Operation;

package FaultAfterCreate {
    use parent 'LibTmux::Server';

    sub snapshot ($self, %args) {
        my $snapshot = $self->SUPER::snapshot(%args);
        $self->{inject_capture_fault} = true;
        return $snapshot;
    }

    sub _capture_op ($self) {
        return $self->SUPER::_capture_op unless $self->{inject_capture_fault};
        return LibTmux::Operation->value(undef)->then(
            sub {
                LibTmux::X::Codec->throw(
                    message => 'injected post-create capture failure');
            }
        );
    }
}
LibTmuxFixture->run(
    sub ($server, $root) {
        $server->new_session(
            name    => 'borrowed',
            command => ['/bin/sleep', '120']
        );
        my $fault = FaultAfterCreate->new(
            socket_path => "$root/s",
            config_file => '/dev/null',
            executable  => $ENV{LIBTMUX_TEST_TMUX} // 'tmux'
        );
        my $workspace = LibTmux::Workspace->new(
            config => {
                schema   => 'libtmux.workspace/v1',
                sessions => [
                    {
                        name    => 'effect-before-failure',
                        windows =>
                            [{panes => [{command => ['/bin/sleep', '120']}]}]
                    }
                ]
            }
        );
        my $error;
        try { $workspace->load(server => $fault) } catch ($caught) {
            $error = $caught
        }
        T2->ok(ref($error) && $error->isa('LibTmux::Workspace::X::Load'),
            'post-dispatch failure is a load failure');
        T2->is(scalar $error->report->{created}->@*,
            1, 'known creation effect remains in the partial report');
        T2->is([map { $_->name } $server->snapshot->sessions->@*],
            ['borrowed'],
            'known receipt allows rollback while preserving borrowed session');
    }
);
T2->done_testing;
