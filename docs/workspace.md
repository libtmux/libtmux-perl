---
title: Load a JSON workspace
description: Load a JSON workspace with the Perl libtmux distributions.
---

The separate distribution packages the `libtmux-workspace` CLI. Validate and
plan without tmux I/O; load explicitly through public core APIs.

Save [the packaged configuration](../packages/workspace/examples/workspace.json)
as `workspace.json`, or use that file from the checkout. Its commands are Perl
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

Loading leaves the workspace running. The
[standalone Perl example](../packages/workspace/examples/load.pl) additionally
checks the resulting graph, repeats with `skip`, and removes its own session:

```console
$ perl packages/workspace/examples/load.pl "${TMPDIR:-/tmp}/libtmux-perl-workspace-$$.sock"
```

Its plan is local and performs no tmux I/O:

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

It then loads and inspects captured public core objects:

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

The complete program imports installed modules and reads its adjacent JSON;
it needs no author helper. Its output confirms one planned session, two loaded
windows, two editor panes, and one skipped session.

`--dry-run` selects a nonmutating plan. Default `existing=error` checks all
session-name conflicts before creation. `skip` preserves the entire existing
session; repeated loads create only absent sessions. This is not convergence
or reconciliation of an existing layout.

Each pane requires literal `command` argv or explicit `shell_command`.
Environment inherits workspace → session → window → pane; cwd inherits from
window unless overridden. Layout applies after splitting. Configuration is
versioned JSON; no YAML adapter is selected.

On failure, inspect completed steps, failed step, created IDs, dispatch
uncertainty, and cleanup errors. Rollback targets only sessions proven created
by this invocation. Application readiness requires caller-specific assertions.
CLI exit statuses: success 0; usage/configuration 2; loading 3; conflict 4.

`LibTmux::Workspace::X::Load->report` retains each cleanup exception with its
captured target identity and attempted action. These entries replace the
earlier string-only `cleanup_errors` values. `cause` remains the original load
failure; a cleanup failure never replaces it. Catch and inspect the exception
class, dispatch evidence, and bounded native result when choosing recovery.

`report_data` returns a detached diagnostic export for JSON, including the
primary cause and cleanup error classes. Native stdout/stderr use explicit
base64 fields to preserve arbitrary octets. The CLI prints this export on
standard error; the library report keeps the original exception objects.
