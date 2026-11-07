use v5.44;
use FindBin;
use lib "$FindBin::Bin/../scripts/lib";
use LibTmuxFixture;
use LibTmux::Workspace;
LibTmuxFixture->run(
    sub ($server, $root) {
        my $workspace = LibTmux::Workspace->new(
            config => {
                schema   => 'libtmux.workspace/v1',
                sessions => [
                    {
                        name    => 'workspace-example',
                        windows => [
                            {
                                name   => 'api',
                                cwd    => $root,
                                layout => 'even-horizontal',
                                panes  => [
                                    {command => ['/bin/sleep', '120']},
                                    {
                                        command    => ['/bin/sleep', '120'],
                                        horizontal => true
                                    },
                                ],
                            }
                        ],
                    }
                ],
            }
        );
        die 'plan mutated state' if $workspace->plan->{mutates};
        my $loaded = $workspace->load(server => $server);
        die 'load failed'   unless $loaded->{status} eq 'loaded';
        die 'panes missing' unless $server->snapshot->panes->count == 2;
        die 'repeat did not skip'
            unless $workspace->load(server => $server, existing => 'skip')
            ->{skipped}->@* == 1;
        say 'workspace load and repeat: ok';
    }
);
