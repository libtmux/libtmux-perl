---
title: Create and observe tmux resources
description: Create and observe tmux resources with the Perl libtmux distributions.
---

Constructing `LibTmux::Server` records connection settings without I/O. Pass a
socket name or socket path; the library clears inherited `TMUX` and
`TMUX_PANE` in subprocess environments. Acquisition and mutations are explicit.

```perl
use v5.44;
use LibTmux::Server;
my $server = LibTmux::Server->new(socket_name => 'example');
my $session = $server->new_session(
    name => 'main', command => ['/bin/sleep', '120'],
);
my $window = $server->new_window(
    session => $session, name => 'api', command => ['/bin/sleep', '120'],
);
my $pane = $window->panes->one;
my $split = $server->split_pane(
    pane => $pane, horizontal => true, command => ['/bin/sleep', '120'],
);
$server->select_layout(window => $window, layout => 'even-horizontal');
my $observed = $server->snapshot;
$server->kill_session(session => $session);
```

This example creates a session and explicitly removes it. Complete executed
programs in [examples](../examples) add exception-safe owned fixture cleanup.
Literal argv does not select a shell. `shell_command` explicitly requests
shell interpretation; one-element literal commands use the core exec shim.

All mutations live on Server. Entity readers are captured and read-only;
renaming a window does not change an old Window handle. Use a new snapshot.
`capture_pane` returns bytes including tmux's final newline. `send_text`
sends literal text with optional Enter; `send_keys` accepts named tmux keys.

Use `set_option`/`get_option`/`unset_option` for explicit scopes, including
inherited reads, and environment methods for global or session values. Hooks
retain sparse indexes in native output. Buffers use stdin for binary payloads.
`cmd` is the checked literal command escape hatch; `execute` retains nonzero
command results. Ordered `batch` returns one `{result, error}` record per
independent request, not per command inside a tmux command list.

Interactive terminal ownership stays with the caller: `attach_argv` returns
argv for a caller-owned terminal; `clients` captures client data and
`detach_client` reports command acceptance. Observe client exit separately.

The complete [quickstart program](../examples/quickstart.pl) creates a session,
splits a pane, adds a window, selects a window link, and filters captured
panes. Install core first, then run it from the source checkout:

```console
$ perl examples/quickstart.pl
```

The included standard-library fixture owns its private socket and verifies
child exit. The standalone demo enables Linux x86_64 LP64 child reaping; the
borrowed Server connection API does not change the application's reaper.
