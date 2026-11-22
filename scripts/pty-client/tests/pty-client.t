use v5.44;
use Test2::V1;
use FindBin;

my $script = "$FindBin::Bin/../pty-client.pl";

sub client ($code) {
    my $pid  = open(my $out, '-|', $^X, $script, $^X, '-e', $code) // die $!;
    my $text = do { local $/; <$out> };
    close $out;
    return ($? >> 8, $text);
}

# The client sees a terminal, the fixed TERM and no ambient tmux selectors.
local $ENV{TMUX}                = '/tmp/outer,1,0';
local $ENV{TMUX_PANE}           = '%9';
local $ENV{LIBTMUX_SOCKET}      = 'outer-name';
local $ENV{LIBTMUX_SOCKET_PATH} = '/tmp/outer.sock';
local $ENV{TERM}                = 'dumb';
my $terminal = <<'PERL';
exit(-t STDIN && -t STDOUT && -t STDERR && $ENV{TERM} eq 'xterm-256color'
    && !exists $ENV{TMUX} && !exists $ENV{TMUX_PANE}
    && !exists $ENV{LIBTMUX_SOCKET} && !exists $ENV{LIBTMUX_SOCKET_PATH}
    ? 0 : 1)
PERL
T2->is([client($terminal)], [0, "client_exit=0\n"], 'the client owns a PTY');
T2->is(
    [client('exit 5')],
    [5, "client_exit=5\n"],
    'the client exit code is kept'
);
T2->is(
    [client('print "x" x 65536 for 1 .. 16; exit 0')],
    [0, "client_exit=0\n"],
    'output beyond the PTY buffer is drained until the client exits'
);
T2->done_testing;
