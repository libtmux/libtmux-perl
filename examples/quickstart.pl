use v5.44;
use File::Temp ();
use LibTmux::Server;

# A private temporary directory holds the socket; it is removed at exit.
my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => "$private/tmux.sock",
    config_file => '/dev/null',
);

my $failure;
try {
    my $session = $server->new_session(
        name    => 'demo',
        command => ['/bin/cat']
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    my $right = $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => ['/bin/cat']
    );
    my $logs = $server->new_window(
        session => $session,
        name    => 'logs',
        command => ['/bin/cat']
    );
    $server->select_pane(pane => $right);
    my $snapshot = $server->snapshot;
    my $link     = $snapshot->window_links->one(
        {
            window => {-is => {id => $logs->id}}
        }
    );
    $server->select_window(link => $link);
    $snapshot = $server->snapshot;

    for my $entry ($snapshot->sessions->@*) {
        say 'session ', $entry->name;
        for my $link ($entry->window_links->@*) {
            my $window = $link->window;
            my $ids    = join ' ', map { $_->id } $window->panes->@*;
            my $label  = $link->index . ':' . $window->name;
            say '  window ', $label, ': ', $ids;
        }
    }
    my $panes =
        $snapshot->windows->one({name => 'editor'})
        ->panes->where({width => {-gte => 1}})
        ->grep(sub ($pane) { $pane->height >= 1 });
    my $selected = $panes->one({active => true});
    die 'unexpected pane membership' unless $panes->count == 2;
    my $name = $selected->window->name;
    say $selected->id, ' is in window ', $name;
}
catch ($error) { $failure = $error }

# Clean up the processes this demo starts, even if it fails.
try { $server->kill_server }
catch ($cleanup) {
    $failure //= $cleanup unless $cleanup isa LibTmux::X::NoServer;
}
if (defined $failure) {
    warn "tmux quickstart failed: $failure\n";
    die $failure;
}
