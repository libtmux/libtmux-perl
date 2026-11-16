use v5.44;
use Test2::V1;
use JSON::PP     ();
use Scalar::Util qw(blessed);
use LibTmux::Server;
use LibTmux::Schema;
use LibTmux::CommandResult;

for my $case (
    ['3.3',         '3.3a',     false],
    ['3.3a',        '3.3a',     true],
    ['next-3.8',    '3.8',      false],
    ['3.8-rc',      '3.8',      false],
    ['3.8-rc2',     '3.8',      false],
    ['3.8-rc2',     '3.6',      true],
    ['3.8',         '3.8',      true],
    ['3.8a',        '3.8',      true],
    ['3.7z',        '3.8',      false],
    ['openbsd-7.4', '3.3a',     false],
    ['tmux 3.8',    '3.8',      false],
    ['3.3a-rc1',    '3.3a',     false],
    ['next-3.8',    '3.8-rc',   false],
    ['3.8-rc2',     '3.8-rc10', false],
    ['3.8-rc10',    '3.8-rc2',  true],
    ['next-3.8a',   '3.6',      false],
    ["3.8\n",       '3.6',      false]
    )
{
    T2->is(!!LibTmux::Schema->_version_at_least($case->[0], $case->[1]),
        $case->[2],
        "$case->[0] against $case->[1] follows whole-release ordering");
}

my $server = LibTmux::Server->new(
    executable  => '/owned/test-client',
    socket_path => '/owned/daemon.sock'
);
T2->ok($server->can('capabilities'), 'public capability discovery exists');
my $operation;
try { $operation = $server->operation('capabilities') } catch ($error) {
}
T2->ok(blessed($operation) && $operation->isa('LibTmux::Operation'),
    'discovery is a shared prepared Operation');

if ($operation) {
    my (@requests, $report, $failure);
    $operation->run(
        sub ($request, $done, $fail) {
            push @requests, $request;
            my ($marker) =
                $request->{argv}[-1] =~ /\A(libtmux-capabilities-[0-9a-f]+-)/;
            unless ($marker) {
                $fail->(
                    LibTmux::X::Transport->new(
                        message => 'discovery did not send its daemon probe'
                    )
                );
                return sub { };
            }
            $done->(
                bless {
                    stdout     => '',
                    stderr     => "unknown command: ${marker}17_42_3.3a\n",
                    exit_code  => 1,
                    signal     => 0,
                    raw_status => 256
                },
                'LibTmux::CommandResult'
            );
            return sub { };
        },
        sub ($value) { $report  = $value },
        sub ($error) { $failure = $error }
    );
    T2->ok(!defined($failure),
        'daemon receipt decodes without a client preflight');
    T2->is(scalar @requests, 1, 'only the daemon probe runs');
    T2->ok(
        !scalar(grep { $_ eq '-V' } $requests[0]{argv}->@*),
        'client -V cannot decide daemon feature support'
    );
    T2->ok(scalar(grep { $_ eq '-N' } $requests[0]{argv}->@*),
        'the probe cannot start a daemon');
    T2->ok($requests[0]{timeout} <= 0.75,     'probe deadline is bounded');
    T2->ok($requests[0]{max_output} <= 16384, 'probe output is bounded');
    T2->ok(blessed($report) && $report->isa('LibTmux::Capabilities'),
        'the operation returns a public report value');
    if ($report) {
        T2->is($report->version, '3.3a', 'report names the actual daemon');
        T2->is(
            $report->identity,
            {pid => '17', start_time => '42'},
            'report identity is captured without a persistent binding'
        );
        T2->ok(
            !$report->supports('cursor-shape'),
            'floor daemon lacks cursor shape'
        );
        my $status = $report->status('cursor-shape');
        T2->is($status->{since}, '3.6',
            'feature requirement comes from the registry');
        $status->{since}                  = '1.0';
        $status->{apis}[0]                = 'changed';
        $status->{commands}[0]{command}   = 'changed';
        $report->features->[0]{supported} = true;
        T2->is($report->status('cursor-shape')->{since},
            '3.6', 'returned metadata cannot change the saved report');
        T2->is($report->status('cursor-shape')->{commands}[0]{command},
            'list-panes', 'nested command metadata is detached');
        T2->is($report->status('cursor-shape')->{apis}[0],
            'LibTmux::Pane/cursor_shape', 'nested API metadata is detached');
        $report->identity->{pid} = '0';
        T2->is($report->identity->{pid}, '17', 'identity is detached');
        T2->ok(
            !$report->supports('cursor-shape'),
            'returned decisions cannot change support'
        );
        T2->is($report->workarounds, [],
            'no unimplemented workaround is advertised');
        my $replacement;
        $server->operation('capabilities')->run(
            sub ($request, $done, $fail) {
                my ($marker) = $request->{argv}[-1] =~
                    /\A(libtmux-capabilities-[0-9a-f]+-)/;
                $done->(
                    bless {
                        stdout     => '',
                        stderr     => "unknown command: ${marker}18_43_3.8\n",
                        exit_code  => 1,
                        signal     => 0,
                        raw_status => 256
                    },
                    'LibTmux::CommandResult'
                );
                return sub { };
            },
            sub ($value) { $replacement = $value },
            sub ($error) { die $error }
        );
        T2->ok($replacement->supports('cursor-shape'),
            'a replacement daemon report has its own feature decision');
        T2->ok(!$report->supports('cursor-shape'),
            'a later discovery cannot change an earlier report decision');
        my $unknown;
        try { $report->status('break-pane-misnames-windows') } catch ($error) {
            $unknown = $error;
        }
        T2->ok(
            blessed($unknown) && $unknown->isa('LibTmux::X::InvalidArgument'),
            'an unregistered feature or workaround is an explicit error'
        );
    }
}
for my $case (
    ['3.2',         'Unsupported'],
    ['openbsd-7.4', 'Unsupported'],
    ['3.8-extra',   'Unsupported'],
    ['3.8',         'Codec', 'extra'],
    ['3.8',         'Codec', '', 0],
    ['3.8', 'NoServer',      '', 1, 'no server running on /owned/daemon.sock'],
    ['3.8', 'Codec',         '', 1, 'unknown command: unrelated']
    )
{
    my $error;
    $server->operation('capabilities')->run(
        sub ($request, $done, $fail) {
            my ($marker) =
                $request->{argv}[-1] =~ /\A(libtmux-capabilities-[0-9a-f]+-)/;
            my $exit = $case->[3] // 1;
            $done->(
                bless {
                    stdout => $case->[2] // '',
                    stderr => (
                        $case->[4]
                            // "unknown command: ${marker}17_42_$case->[0]"
                        )
                        . "\n",
                    exit_code  => $exit,
                    signal     => 0,
                    raw_status => $exit << 8
                },
                'LibTmux::CommandResult'
            );
            return sub { };
        },
        sub { },
        sub ($caught) { $error = $caught }
    );
    T2->ok(
        blessed($error) && $error->isa("LibTmux::X::$case->[1]"),
        "$case->[0] receipt has explicit $case->[1] failure"
    );
}
T2->done_testing;
