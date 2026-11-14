use v5.44;
use File::Temp ();
use LibTmux::Server;

# Without a socket argument, a private temporary directory holds the server.
my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $socket  = shift @ARGV // "$private/tmux.sock";
my $server  = LibTmux::Server->new(
    socket_path => $socket,
    executable  => shift(@ARGV) // 'tmux',
    config_file => '/dev/null',
);
my ($session, $snapshot, $side, $failure);
try {
    $session = $server->new_session(
        name    => 'perl-quickstart',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    $side = $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $server->resize_pane(pane => $side, width => 20);
    $server->new_window(
        session => $session,
        name    => 'logs',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $snapshot = $server->snapshot;
}
catch ($error) {
    $failure = $error;
    $session //= $error->created if $error isa LibTmux::X::Creation;
}
if ($session) {
    try { $server->kill_session(session => $session) }
    catch ($cleanup) {
        warn "session cleanup failed: $cleanup\n";
        $failure //= $cleanup;
    }
}
die $failure if defined $failure;

# The captured graph remains readable after its live session has gone.
for my $link ($snapshot->session_by_id($session->id)->window_links->@*) {
    my $count = $link->window->panes->count;
    say $link->window->name, ': ', $count, $count == 1 ? ' pane' : ' panes';
}
say 'side pane: ', $snapshot->pane_by_id($side->id)->width, ' columns';
