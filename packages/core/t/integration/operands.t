use v5.44;
use Test2::V1;
use LibTmuxFixture;
LibTmuxFixture->run(
    sub ($server, $root) {
        my $session = $server->new_session(
            name    => 'boundaries',
            command => ['/bin/sleep', '120']
        );
        my $pane  = $session->window_links->one->window->panes->one;
        my $other = $server->split_pane(
            pane    => $pane,
            command => ['/bin/sleep', '120']
        );
        $server->cmd('copy-mode', '-t', $other->id);
        T2->is(
            0 + $server->cmd('display-message', '-p', '-t', $other->id,
                '#{pane_in_mode}')->stdout,
            1,
            'other pane starts in copy mode'
        );
        $server->send_keys(
            pane => $pane,
            keys => ['-t', $other->id, '-X', 'cancel']
        );
        T2->is(
            0 + $server->cmd('display-message', '-p', '-t', $other->id,
                '#{pane_in_mode}')->stdout,
            1,
            'key operands cannot override a validated target'
        );
    }
);
T2->done_testing;
