use v5.44;
use Test2::V1;
use File::Spec;
use Scalar::Util qw(blessed);
use LibTmux::Server;

delete @ENV{qw(TMUX TMUX_PANE LIBTMUX_SOCKET LIBTMUX_SOCKET_PATH)};

sub failure ($code, $type, $label) {
    my $caught;
    try { $code->() } catch ($e) {
        $caught = $e
    }
    T2->ok(blessed($caught) && $caught->isa("LibTmux::X::$type"), $label);
}
my $server = LibTmux::Server->new(
    executable  => '/missing-libtmux-test',
    socket_name => 'never-start'
);
failure(sub { $server->cmd('display-message', {}) },
    'InvalidArgument', 'raw command references are rejected before I/O');
failure(sub { $server->new_session(name => 'x', bogus => 1) },
    'InvalidArgument', 'unknown operation options are rejected before I/O');
failure(sub { LibTmux::Server->new(timeout => 'wide') },
    'InvalidArgument', 'invalid deadlines fail at construction');
failure(sub { $server->query_panes(where => {width => {-gte => 'wide'}}) },
    'InvalidFilter', 'criteria validation precedes acquisition');
failure(sub { $server->new_window(session => '$1', command => []) },
    'InvalidArgument', 'empty command argv cannot select an implicit shell');
failure(
    sub {
        $server->split_pane(
            pane          => '%0',
            command       => ['cat'],
            shell_command => 'cat'
        );
    },
    'InvalidArgument',
    'shell and literal commands are exclusive'
);
my $keys     = ['A'];
my $prepared = $server->operation('send_keys', pane => '%0', keys => $keys);
$keys->[0] = 'B';
my $sent;
$prepared->run(
    sub ($request, $done, $fail) {
        my $stdout =
            $request->{argv}[-1] eq '-V' ? "tmux 3.8\n"
            : (grep { $_ eq 'display-message' } $request->{argv}->@*)
            ? "/owned\t123\t456\t3.8\n"
            : '';
        $sent = $request->{argv}[-1]
            if grep { $_ eq 'send-keys' } $request->{argv}->@*;
        $done->(
            bless {
                stdout     => $stdout,
                stderr     => '',
                exit_code  => 0,
                signal     => 0,
                raw_status => 0
            },
            'LibTmux::CommandResult'
        );
        return sub { };
    },
    sub { },
    sub ($error) { die $error }
);
T2->is($sent, 'A', 'prepared operation owns caller argument containers');
failure(
    sub { $server->select_layout(window => '@0', layout => 'no-such-layout') },
    'InvalidArgument',
    'unsafe invalid layout is refused before daemon dispatch'
);
T2->ok(
    !$server->explain_panes(where => {title => "nul\0text"})->lowering->{exact},
    'NUL text stays local because process arguments cannot represent it'
);

sub prefix_for (%args) {
    my $argv = LibTmux::Server->new(%args)->attach_argv(session => '$0');
    return [$argv->@[0 .. $#$argv - 3]];
}

T2->is(prefix_for(), ['tmux'],
    'default construction passes neither -S nor -L when selectors are unset');
{
    local $ENV{LIBTMUX_SOCKET_PATH} = '/tmp/from-env.sock';
    local $ENV{LIBTMUX_SOCKET}      = 'bad/slash';
    local $ENV{TMUX}                = '/tmp/from-tmux.sock,123,0';
    T2->is(
        prefix_for(socket_path => '/tmp/explicit.sock'),
        ['tmux', '-S', '/tmp/explicit.sock'],
        'explicit socket_path overrides env selectors without reading them'
    );
    T2->is(
        prefix_for(socket_name => 'explicit'),
        ['tmux', '-L', 'explicit'],
        'explicit socket_name overrides env selectors without reading them'
    );
    failure(
        sub {
            LibTmux::Server->new(
                socket_path => '/tmp/explicit.sock',
                socket_name => 'explicit'
            );
        },
        'InvalidArgument',
        'explicit socket_path and socket_name remain mutually exclusive'
    );
    T2->is(
        prefix_for(),
        ['tmux', '-S', '/tmp/from-env.sock'],
        'LIBTMUX_SOCKET_PATH wins over LIBTMUX_SOCKET and TMUX without error'
    );
}
{
    local $ENV{LIBTMUX_SOCKET_PATH} = '  rel/spaced.sock  ';
    T2->is(
        prefix_for(),
        ['tmux', '-S', File::Spec->rel2abs('  rel/spaced.sock  ')],
        'relative LIBTMUX_SOCKET_PATH resolves untrimmed against cwd'
    );
}
{
    local $ENV{LIBTMUX_SOCKET_PATH} = "  \t\n ";
    local $ENV{LIBTMUX_SOCKET}      = ' work ';
    local $ENV{TMUX}                = '/tmp/from-tmux.sock,123,0';
    T2->is(
        prefix_for(),
        ['tmux', '-L', ' work '],
        'whitespace-only LIBTMUX_SOCKET_PATH falls through to untrimmed name'
    );
}
{
    local $ENV{LIBTMUX_SOCKET_PATH} = '';
    local $ENV{LIBTMUX_SOCKET}      = '   ';
    T2->is(prefix_for(), ['tmux'],
        'empty and whitespace-only LIBTMUX_SOCKET* count as unset');
    local $ENV{LIBTMUX_SOCKET} = 'bad/name';
    failure(sub { LibTmux::Server->new },
        'InvalidArgument',
        'slash in LIBTMUX_SOCKET is rejected like explicit socket_name');
}
{
    local $ENV{TMUX} = '/tmp/pane.sock,1234,0';
    T2->is(
        prefix_for(),
        ['tmux', '-S', '/tmp/pane.sock'],
        'ambient TMUX resolves socket path before the first comma'
    );
    T2->is(
        prefix_for(env => {TMUX => 'rel/pane.sock,99,1'}),
        ['tmux', '-S', File::Spec->rel2abs('rel/pane.sock')],
        'relative TMUX socket path resolves against cwd'
    );
    for my $blank ('', ',1234,0', '   ', '   ,1234,0') {
        T2->is(prefix_for(env => {TMUX => $blank}),
            ['tmux'],
            'blank or comma-leading TMUX overrides ambient TMUX as unset');
    }
}
{
    local $ENV{LIBTMUX_SOCKET_PATH} = '/tmp/ambient.sock';
    T2->is(
        prefix_for(
            env => {LIBTMUX_SOCKET_PATH => '  ', LIBTMUX_SOCKET => 'override'}
        ),
        ['tmux', '-L', 'override'],
        'server env hash overrides process environment for selector precedence'
    );
}
T2->done_testing;
