---
title: Create and observe tmux resources
description: Create sessions, arrange windows, send input, and read captured state from Perl.
---

## Start with a complete program

After [installing core](installation.md), run the
[standalone quick start](../packages/core/examples/quickstart.pl):

```console
$ perl packages/core/examples/quickstart.pl
```

<!-- example: packages/core/examples/quickstart.pl -->
```perl
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
```

It prints `editor: 2 panes`, `logs: 1 pane` and `side pane: 20 columns`.

- Only the session `new_session` returned, or its creation receipt, is a
  cleanup target. Existing sessions stay untouched.
- If cleanup also fails, the original error stays primary.
- The captured graph stays readable after the session is removed.
- With no socket argument the program owns a private server. Pass a socket path
  to borrow one.

Constructing a [Server](https://libtmux.org/en/perl/latest/reference/libtmux-server/)
records settings without I/O. `new_session` starts a daemon when needed;
`snapshot` needs one running. The core clears inherited `TMUX` and `TMUX_PANE`
for subprocesses.

## Arrange a live window

The [longer workflow](../packages/core/examples/workflow.pl) adds layout
selection and a second window. It continues from the quick start's `$server`:

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

Run the complete program:

```console
$ perl packages/core/examples/workflow.pl
```

- Literal command arrays never select a shell. `shell_command` asks for one.
- A one-element literal command uses the core exec shim.
- `even-horizontal` works across the supported tmux range.

## Send literal text and capture the screen

[input.pl](../packages/core/examples/input.pl) runs its own server and covers
this section and the next:

<!-- example: packages/core/examples/input.pl -->
```perl
use v5.44;
use File::Temp ();
use LibTmux::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => "$private/tmux.sock",
    config_file => '/dev/null',
);
my $failure;
try {
    my $session = $server->new_session(
        name    => 'perl-input',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $pane = $session->window_links->one->window->panes->one;

    $server->send_text(
        pane  => $pane,
        text  => 'hello from Perl',
        enter => true
    );
    print $server->capture_pane(pane => $pane, start => -100) =~ s/\n+\z/\n/r;
    $server->set_environment(
        session => $session,
        name    => 'PROJECT',
        value   => 'api',
    );
    say 'PROJECT=',
        $server->get_environment(session => $session, name => 'PROJECT');
    my %build = (scope => 'session', target => $session->id, name => '@build');
    $server->set_option(%build, value => 'ok');
    say '@build=', $server->get_option(%build);

    # example: begin batch
    my $batch = $server->batch(
        [
            ['display-message', '-p', '-t', $pane->id, '#{session_name}'],
            ['display-message', '-p', '-t', $pane->id, '#{pane_index}'],
        ]
    );
    for my $entry ($batch->@*) {
        die $entry->{error} if defined $entry->{error};
        print $entry->{result}->stdout;
    }

    # example: end batch
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
```

It prints the echoed text, `PROJECT=api`, `@build=ok`, then `perl-input` and
`0`.

- `send_text` can append Enter and never interprets shell syntax.
- `send_keys` takes tmux key names.
- `capture_pane` returns bytes including the final newline; a negative `start`
  reads scrollback.
- Accepting a command does not mean the application finished. Wait on what the
  application shows before a step that depends on it.

## Read options, environment, and native results

- `set_option`, `get_option` and `unset_option` take an explicit scope and
  target. Inherited reads must be requested.
- Session environment operations accept captured handles and check their
  generation.
- Hooks keep sparse indexes. Buffer operations pass binary data through stdin.
- `cmd` is a checked literal tmux argv; `execute` returns nonzero results for
  callers that read the status.
- `batch` returns one `{result, error}` record per independent request, in
  input order. It reports no outcomes inside a tmux command list.

## Capture again after a mutation

Entity accessors read captured values and never issue a command. The workflow
renames a window without rewriting its old observation:

<!-- example: packages/core/examples/workflow.pl#graph -->
```perl
my $before = $snapshot->window_by_id($logs->id);
$server->rename_window(window => $logs, name => 'build');
die 'captured name changed' unless $before->name eq 'logs';
die 'new name missing'
    unless $server->snapshot->window_by_id($logs->id)->name eq 'build';
say 'captured name: ', $before->name;

```

- Every mutation lives on `Server` and takes explicit targets.
- Window selection, movement and unlinking use `WindowLink` targets.
- Terminal ownership stays with the caller: `attach_argv` returns argv, and
  `detach_client` reports acceptance, not that the client exited.

See [graph identity](graph.md), [filtering](filtering.md) and
[errors and recovery](errors.md).
