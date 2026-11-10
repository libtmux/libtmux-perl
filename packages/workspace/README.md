<!-- libtmux-logo -->
<div align="center">
  <picture>
    <source srcset="assets/logo.svg" type="image/svg+xml">
    <img src="assets/logo.png" width="128" height="128" alt="libtmux for Perl workspace">
  </picture>
</div>
<!-- /libtmux-logo -->

<div align="center">

# LibTmux-Workspace

</div>

LibTmux-Workspace validates, plans, and loads versioned JSON workspaces through
public LibTmux core APIs. Requires stable Perl 5.44.0, the versioned core, and its
supported Linux/tmux environment. No non-core runtime dependency is added.
This development distribution is not published on CPAN.

[Install from source](https://github.com/libtmux/libtmux-perl/blob/master/docs/installation.md) ·
[API reference](https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace/) ·
[Examples](https://github.com/libtmux/libtmux-perl/blob/master/examples/README.md)

After installing the workspace distribution, save this as `workspace.json`:

```json
{
  "schema": "libtmux.workspace/v1",
  "sessions": [{
    "name": "example",
    "windows": [{
      "name": "main",
      "panes": [{"command": ["/bin/cat"]}]
    }]
  }]
}
```

Inspect the plan, then load it into the explicitly named `example` server:

```console
$ libtmux-workspace plan workspace.json
```

```console
$ libtmux-workspace load workspace.json \
    --socket-name example \
    --existing skip
```

Configurations use `schema: "libtmux.workspace/v1"`, sessions, named windows,
and panes. Each pane declares a literal `command` array or explicit
`shell_command` text. Working directories, inherited environments, and layouts
are supported. Planning performs no tmux I/O. Default existing-target behavior
is an error; `skip` leaves the whole pre-existing session unchanged.

Failures retain completed steps and original causes. Rollback affects only
sessions proven created by this load, including generation-scoped creation
receipts after capture failures. Unknown effects and cleanup failures remain
visible in the error report. Borrowed resources are never rollback targets.

The executable's `--help` documents command options and exit statuses. Read
installed `LibTmux::Workspace` POD and the repository
[workspace guide](https://github.com/libtmux/libtmux-perl/blob/master/docs/workspace.md).
Async support remains optional; MCP is excluded.
