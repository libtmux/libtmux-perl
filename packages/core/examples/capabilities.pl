use v5.44;
use File::Temp ();
use LibTmux::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => shift(@ARGV) // "$private/tmux.sock",
    executable  => shift(@ARGV) // 'tmux',
    config_file => '/dev/null',
);
my ($session, $report, $failure);
try {
    $session = $server->new_session(
        name    => 'perl-capabilities',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $report = $server->capabilities;
    my $feature = $report->status('cursor-shape');
    say 'daemon: tmux ', $report->version;
    say 'cursor-shape: ', $feature->{supported}
        ? 'available'
        : 'requires tmux ' . $feature->{since};
}
catch ($error) {
    $failure = $error;
    $session //= $error->created if $error isa LibTmux::X::Creation;
}
if ($session) {
    try { $server->kill_session(session => $session) }
    catch ($cleanup) { $failure //= $cleanup }
}
die $failure if defined $failure;
