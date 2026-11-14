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
        name    => 'perl-graph',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $window = $session->window_links->one->window;
    $server->rename_window(window => $window, name => 'logs');
    my $before = $server->snapshot->window_by_id($window->id);
    $server->rename_window(window => $window, name => 'build');
    say 'captured name: ', $before->name;
    say 'live name: ',     $server->snapshot->window_by_id($window->id)->name;
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
