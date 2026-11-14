---
title: Load a JSON workspace
description: Load a JSON workspace with the Perl libtmux distributions.
---

The separate workspace distribution packages the `libtmux-workspace` CLI.
Validate and plan without tmux I/O; load through public core APIs.

## Describe a workspace

Save [the packaged configuration](../packages/workspace/examples/workspace.json)
as `workspace.json`, or use it from the checkout. Its commands are Perl
programs, with two editor panes and a logs window:

<!-- example: packages/workspace/examples/workspace.json -->
```json
{
  "schema": "libtmux.workspace/v1",
  "environment": {"PROJECT": "api"},
  "sessions": [{
    "name": "perl-workspace",
    "windows": [{
      "name": "editor",
      "layout": "even-horizontal",
      "panes": [
        {"command": ["perl", "-e", "while (<STDIN>) { print }"]},
        {"command": ["perl", "-e", "while (<STDIN>) { print }"], "horizontal": true}
      ]
    }, {
      "name": "logs",
      "panes": [{"command": ["perl", "-e", "while (<STDIN>) { print }" ]}]
    }]
  }]
}
```

- Each pane takes a literal `command` argv or an explicit `shell_command`.
- Environment inherits workspace, session, window, pane. The working directory
  inherits from the window unless overridden.
- Layout applies after splitting.
- The format is versioned JSON; no YAML adapter is selected.

## Run the CLI

From the repository root:

```console
$ libtmux-workspace validate packages/workspace/examples/workspace.json
```

```console
$ libtmux-workspace plan packages/workspace/examples/workspace.json
```

```console
$ libtmux-workspace load packages/workspace/examples/workspace.json \
    --socket-path "${TMPDIR:-/tmp}/libtmux-perl-workspace-$$.sock" \
    --existing skip
```

- `load` leaves the workspace running; the CLI has no stop verb.
- `--dry-run` makes a nonmutating plan.
- The default `existing=error` checks every session-name conflict before it
  creates anything.
- `skip` keeps the whole existing session. Repeated loads create only absent
  sessions; this is not reconciliation of an existing layout.
- Exit status: 0 success, 2 usage or configuration, 3 load failure, 4 conflict.

## Load from Perl

The [standalone Perl example](../packages/workspace/examples/load.pl) plans,
loads, checks the graph, repeats with `skip`, and removes its own session. It
runs its own tmux server:

```console
$ perl packages/workspace/examples/load.pl
```

The plan is local and performs no tmux I/O:

<!-- example: packages/workspace/examples/load.pl#plan -->
```perl
use v5.44;
use FindBin;
use LibTmux::Workspace;

open my $in, '<:raw', "$FindBin::Bin/workspace.json" or die $!;
my $json = do { local $/; <$in> };
close $in or die $!;
my $workspace = LibTmux::Workspace->from_json($json);
my $plan      = $workspace->plan;
say 'planned sessions: ', scalar $plan->{sessions}->@*;
die 'plan must not mutate' if $plan->{mutates};

```

It loads and inspects captured public core objects:

<!-- example: packages/workspace/examples/load.pl#load -->
```perl
my $report   = $workspace->load(server => $server);
my $snapshot = $server->snapshot;
$session = $snapshot->sessions->one({name => 'perl-workspace'});
my $windows = $session->window_links;
say 'loaded windows: ', $windows->count;
my $editor = $windows->one({window => {-is => {name => 'editor'}}})->window;
say 'editor panes: ', $editor->panes->count;

```

Repeating with `skip` preserves the whole existing session:

<!-- example: packages/workspace/examples/load.pl#repeat -->
```perl
my $again = $workspace->load(server => $server, existing => 'skip');
say 'skipped existing sessions: ', scalar $again->{skipped}->@*;

```

The program prints one planned session, two loaded windows, two editor panes
and one skipped session.

## Recover from a failed load

- A failed load reports the completed steps, the failed step, the created IDs,
  dispatch uncertainty and cleanup errors.
- Rollback removes only sessions this load proved it created.
- Application readiness needs assertions of your own.
- `LibTmux::Workspace::X::Load->report` keeps each cleanup exception with its
  captured target and attempted action. `cause` stays the original failure; a
  cleanup failure never replaces it.
- `report_data` returns a detached, JSON-safe export with the primary cause and
  the cleanup error classes. Native stdout and stderr use explicit base64
  fields. The CLI prints it on standard error.
