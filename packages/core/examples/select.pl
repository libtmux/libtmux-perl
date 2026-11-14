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
        name    => 'perl-select',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => [$^X, '-e', 'while (<STDIN>) { print }'],
    );

    my $snapshot = $server->snapshot;
    my $panes =
        $snapshot->windows->one({name => 'editor'})
        ->panes->where({width => {-gte => 1}})
        ->grep(sub ($pane) { $pane->height > 0 });
    my $active = $panes->one({active => true});
    say 'editor panes: ',          $panes->count;
    say 'active pane belongs to ', $active->window->name;

    # example: begin nomatch
    try { $panes->one({width => {-gt => 10_000}}) }
    catch ($error) {
        die $error unless $error isa LibTmux::X::NoMatch;
        say 'no pane is that wide';
    }

    # example: end nomatch
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
