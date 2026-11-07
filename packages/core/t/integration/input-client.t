use v5.44;
use Test2::V1;
use LibTmuxFixture;
use LibTmux::Transport;
LibTmuxFixture->run(
    sub ($server, $root) {
        my $session = $server->new_session(
            name    => 'input-client',
            command => ['/bin/sleep', '120']
        );
        my $window  = $session->window_links->one->window;
        my $program = q{
        $|=1;
        my ($tmux,$socket)=@ARGV;
        print "READY\n";
        system {$tmux} $tmux,'-S',$socket,'wait-for','-S','program-ready';
        while (defined(my $line=<STDIN>)) {
            print 'READ:'.$line;
            system {$tmux} $tmux,'-S',$socket,'wait-for','-S','line-read';
        }
    };
        my $pane = $server->split_pane(
            pane    => $window->panes->one,
            command => [
                $^X, '-e', $program, $ENV{LIBTMUX_TEST_TMUX} // 'tmux',
                "$root/s"
            ]
        );
        $server->cmd('wait-for', 'program-ready');
        my $text = 'literal ; $(unsafe) #{pid}';
        $server->send_text(pane => $pane, text => $text, enter => true);
        $server->cmd('wait-for', 'line-read');
        T2->ok(
            index($server->capture_pane(pane => $pane), 'READ:' . $text) >= 0,
            'literal text and Enter reach the application before capture'
        );
        $server->send_keys(pane => $pane, keys => ['x', 'Enter']);
        $server->cmd('wait-for', 'line-read');
        T2->ok(
            index($server->capture_pane(pane => $pane, start => 0, end => 20),
                'READ:x') >= 0,
            'named keys reach the explicitly targeted pane'
        );
        $server->set_hook(
            name    => 'client-attached',
            command => 'wait-for -S client-attached',
            target  => $session->id
        );
        my $job = LibTmux::Transport->start(
            argv => [
                'python3', 'scripts/pty-client.py',
                $server->attach_argv(session => $session->id)->@*
            ],
            timeout => 0.8
        );
        $server->cmd('wait-for', 'client-attached');
        my $client = $server->clients->one;
        T2->ok(
            $client->pid > 0 && defined($client->session),
            'real interactive client appears in captured data'
        );
        $server->detach_client(client => $client);
        my $exit = $job->wait;
        T2->ok(
            scalar($exit->success && $exit->stdout =~ /client_exit=0/),
            'detach acceptance is followed by observed owned client exit'
        );
        T2->is($server->clients->count, 0, 'detached client no longer appears');
    }
);
T2->done_testing;
