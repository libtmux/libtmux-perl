---
title: Load a JSON workspace
description: Load a JSON workspace with the Perl libtmux distributions.
---

The separate distribution packages the `libtmux-workspace` CLI. Validate and
plan without tmux I/O; load explicitly through public core APIs.

```json
{
  "schema": "libtmux.workspace/v1",
  "sessions": [{
    "name": "main",
    "windows": [{
      "name": "api",
      "layout": "even-horizontal",
      "panes": [
        {"command": ["/bin/sleep", "120"]},
        {"command": ["/bin/sleep", "120"], "horizontal": true}
      ]
    }]
  }]
}
```

```console
$ libtmux-workspace validate workspace.json
```

```console
$ libtmux-workspace plan workspace.json
```

```console
$ libtmux-workspace load workspace.json \
    --socket-name example \
    --existing skip
```

`--dry-run` selects a nonmutating plan. Default `existing=error` checks all
session-name conflicts before creation. `skip` preserves the entire existing
session; repeated loads create only absent sessions. This is not convergence
or reconciliation of an existing layout.

Each pane requires literal `command` argv or explicit `shell_command`.
Environment inherits workspace → session → window → pane; cwd inherits from
window unless overridden. Layout applies after splitting. Configuration is
versioned JSON; no YAML adapter or MCP consumer is selected.

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
