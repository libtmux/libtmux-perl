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
