---
title: Create and observe tmux resources
description: Create sessions, arrange windows, send input, and read captured state from Perl.
---

## Start with a complete program

After [installing core](installation.md), run the
[standalone quick start](../packages/core/examples/quickstart.pl):

```console
$ perl packages/core/examples/quickstart.pl "${TMPDIR:-/tmp}/libtmux-perl-$$.sock"
```

<!-- example: packages/core/examples/quickstart.pl -->
```perl
use v5.44;
use LibTmux::Server;

my $socket = shift @ARGV // die "Usage: $0 SOCKET_PATH [TMUX]\n";
my $server = LibTmux::Server->new(
    socket_path => $socket,
    executable  => shift(@ARGV) // 'tmux',
    config_file => '/dev/null',
);
my ($session, $snapshot, $failure);
try {
    $session = $server->new_session(
        name    => 'perl-quickstart',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
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
```

It prints `editor: 2 panes` and `logs: 1 pane`. Only the session returned by
creation, or its generation-scoped creation receipt, is a cleanup target.
The original operation error remains primary if cleanup also fails. Existing
sessions remain untouched. The captured graph stays readable after removal.

Constructing [Server](https://libtmux.org/en/perl/latest/reference/libtmux-server/)
records connection settings without I/O. `new_session` starts a daemon when
needed; `snapshot` requires one to exist. Pass an explicit socket path or name.
The core clears inherited `TMUX` and `TMUX_PANE` for subprocesses.

## Arrange a live window

The [longer workflow](../packages/core/examples/workflow.pl) adds layout
selection and a second window before capturing:

<!-- example: packages/core/examples/workflow.pl#create -->
```perl
$session = $server->new_session(
    name    => 'perl-workflow',
    command => [$^X, '-e', 'while (<STDIN>) { print }'],
);
my $editor = $session->window_links->one->window;
$server->rename_window(window => $editor, name => 'editor');
my $right = $server->split_pane(
    pane       => $editor->panes->one,
    horizontal => true,
    command    => [$^X, '-e', 'while (<STDIN>) { print }'],
);
$server->select_layout(window => $editor, layout => 'even-horizontal');
my $logs = $server->new_window(
    session => $session,
    name    => 'logs',
    command => [$^X, '-e', 'while (<STDIN>) { print }'],
);

```

Run the complete program with an explicit socket:

```console
$ perl packages/core/examples/workflow.pl "${TMPDIR:-/tmp}/libtmux-perl-$$.sock"
```

Literal command arrays do not select a shell. `shell_command` explicitly
requests shell interpretation; a one-element literal command uses the core
exec shim. `even-horizontal` is supported throughout the declared tmux range.

## Send literal text and capture the screen

In that same live workflow:

<!-- example: packages/core/examples/workflow.pl#input -->
```perl
$server->send_text(
    pane  => $right,
    text  => 'hello from Perl',
    enter => true
);
my $screen = $server->capture_pane(pane => $right, start => -100);
say 'captured bytes: ', length $screen;
$server->set_environment(
    session => $session,
    name    => 'PROJECT',
    value   => 'api',
);
say 'PROJECT=',
    $server->get_environment(session => $session, name => 'PROJECT');

```

`send_text` optionally appends Enter and does not interpret shell syntax.
`send_keys` accepts tmux key names. `capture_pane` returns bytes including the
final newline; negative `start` values request scrollback. Sending Enter or
accepting a command does not establish application completion. A read returns
the observed screen; use the application's own observable handshake when a
later step depends on completed work.

## Read options, environment, and native results

Use `set_option`, `get_option`, and `unset_option` with explicit scope and
target. Inherited option reads must be requested explicitly. Session-scoped
environment operations accept captured handles and check their generation.
Hooks preserve sparse indexes. Buffer operations use stdin for binary payloads.

`cmd` is a checked literal tmux argv escape hatch; `execute` returns nonzero
command results for callers that inspect status themselves. `batch` returns
one `{result, error}` record per independent request, in input order. It does
not report individual outcomes inside an arbitrary tmux command list.

## Capture again after a mutation

Entity accessors read captured values; they never refresh or issue a command.
The workflow demonstrates a rename without rewriting its old observation:

<!-- example: packages/core/examples/workflow.pl#graph -->
```perl
my $before = $snapshot->window_by_id($logs->id);
$server->rename_window(window => $logs, name => 'build');
die 'captured name changed' unless $before->name eq 'logs';
die 'new name missing'
    unless $server->snapshot->window_by_id($logs->id)->name eq 'build';
say 'captured name: ', $before->name;

```

All mutations live on Server and accept explicit targets. Context-sensitive
window selection, movement, and unlinking use WindowLink targets. Interactive
terminal ownership stays with the caller: `attach_argv` returns argv;
`detach_client` reports command acceptance, not observed client exit.
See [graph identity](graph.md), [filtering](filtering.md), and
[errors and recovery](errors.md).
