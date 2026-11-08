use v5.44;
use LibTmux::Transport;
$ENV{LIBTMUX_PROBE_ROOT} = $$;
my $job = LibTmux::Transport->start(
    argv => [$^X, '-e', 'close STDOUT; close STDERR; kill "STOP", $$; exit 0'],
    timeout => 0.2,
);
try {
    my $result = $job->wait;
    say 'completed=', $result->exit_code;
    die 'cleanup incomplete' unless $job->cleanup_complete;
}
catch ($error) {
    warn "$error\n";
    warn 'raw_status=', $error->result->raw_status,   "\n" if $error->result;
    warn 'cleanup_complete=', $job->cleanup_complete, "\n";
    exit 1;
}
