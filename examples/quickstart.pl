use v5.44;
use Config;
use FindBin;
use lib "$FindBin::Bin/../scripts/lib";
use LibTmuxFixture;

# This complete demo owns a Linux child-reaping scope, including tmux panes.
BEGIN {
    die 'Requires Linux x86_64 LP64'
        unless $^O eq 'linux'
        && $Config::Config{archname} =~ /x86_64/
        && $Config::Config{ptrsize} == 8
        && $Config::Config{ivsize} == 8;
    syscall(157, 36, 1, 0, 0, 0) == 0 or die "subreaper: $!";
}

try {
    LibTmuxFixture->run(
        sub ($server, $root) {
            my $session = $server->new_session(
                name    => 'demo',
                command => ['/bin/cat']
            );
            my $failure;
            try {
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
                        my $ids   = join ' ', map { $_->id } $window->panes->@*;
                        my $label = $link->index . ':' . $window->name;
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
            $server->kill_session(session => $session);
            die $failure if defined $failure;
        }
    );
}
catch ($error) {
    warn "tmux quickstart failed: $error\n";
    die $error;
}
