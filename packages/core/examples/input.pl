use v5.44;
use File::Temp ();
use LibTmux::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => "$private/tmux.sock",
    config_file => '/dev/null',
);
my $failure;
try {
    my $session = $server->new_session(
        name    => 'perl-input',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $pane = $session->window_links->one->window->panes->one;

    $server->send_text(
        pane  => $pane,
        text  => 'hello from Perl',
        enter => true
    );
    print $server->capture_pane(pane => $pane, start => -100) =~ s/\n+\z/\n/r;
    $server->set_environment(
        session => $session,
        name    => 'PROJECT',
        value   => 'api',
    );
    say 'PROJECT=',
        $server->get_environment(session => $session, name => 'PROJECT');
    my %build = (scope => 'session', target => $session->id, name => '@build');
    $server->set_option(%build, value => 'ok');
    say '@build=', $server->get_option(%build);

    # example: begin batch
    my $batch = $server->batch(
        [
            ['display-message', '-p', '-t', $pane->id, '#{session_name}'],
            ['display-message', '-p', '-t', $pane->id, '#{pane_index}'],
        ]
    );
    for my $entry ($batch->@*) {
        die $entry->{error} if defined $entry->{error};
        print $entry->{result}->stdout;
    }

    # example: end batch
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
