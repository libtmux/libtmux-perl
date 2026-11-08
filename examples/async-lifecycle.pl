use v5.44;
use Getopt::Long qw(GetOptions);
use IO::Async::Loop::Ppoll;
use LibTmux::Async::Server;

my ($socket, $executable, $fail, $cancel, $help);
GetOptions(
    'socket=s' => \$socket,
    'tmux=s'   => \$executable,
    'fail'     => \$fail,
    'cancel'   => \$cancel,
    'help'     => \$help,
) or die "Use --help for arguments\n";
if ($help) {
    say
'Usage: perl async-lifecycle.pl --socket PATH [--tmux EXE] [--fail | --cancel]';
    say
'Observe an existing server and close the executor without destroying that server.';
    exit 0;
}
die "Supply --socket PATH; --fail and --cancel are mutually exclusive\n"
    if !defined($socket) || @ARGV || ($fail && $cancel);

my $loop   = IO::Async::Loop::Ppoll->new;
my $server = LibTmux::Async::Server->new(
    loop        => $loop,
    socket_path => $socket,
    defined($executable) ? (executable => $executable) : (),
);
my ($operation_error, $cleanup_error);
try {
    my $operation =
          $fail
        ? $server->cmd('libtmux-example-invalid-command')
        : $server->snapshot;
    $operation->cancel if $cancel;
    $loop->await($operation);
    if ($operation->is_cancelled) { say 'capture cancelled' }
    else {
        my $snapshot = $operation->get;
        say 'captured panes: ' . $snapshot->panes->count;
    }
}
catch ($error) { $operation_error = $error }

try {
    my $cleanup = $server->close;
    $loop->await($cleanup);
    $cleanup->get;
    say 'executor cleanup: complete';
}
catch ($error) { $cleanup_error = $error }

if (defined $operation_error) {
    warn "executor cleanup also failed: $cleanup_error\n"
        if defined $cleanup_error;
    die $operation_error;
}
die $cleanup_error if defined $cleanup_error;
