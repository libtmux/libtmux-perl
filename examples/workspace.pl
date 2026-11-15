use v5.44;
use File::Temp ();
use LibTmux::Server;
use LibTmux::Workspace;

# A private temporary directory holds the socket; it is removed at exit.
my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => "$private/tmux.sock",
    config_file => '/dev/null',
);

my $failure;
try {
    my $workspace = LibTmux::Workspace->new(
        config => {
            schema   => 'libtmux.workspace/v1',
            sessions => [
                {
                    name    => 'workspace-example',
                    windows => [
                        {
                            name   => 'api',
                            cwd    => "$private",
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
}
catch ($error) { $failure = $error }

# Clean up the processes this demo starts, even if it fails.
try { $server->kill_server }
catch ($cleanup) {
    $failure //= $cleanup unless $cleanup isa LibTmux::X::NoServer;
}
die $failure if defined $failure;
say 'workspace load and repeat: ok';
