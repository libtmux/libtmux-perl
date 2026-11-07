# LibTmux-Workspace

Validate, inspect, and load versioned JSON workspaces through public LibTmux
core APIs. Requires stable Perl 5.44.0, the versioned LibTmux core, and its
supported Linux/tmux environment. No non-core runtime dependency is added.
This development distribution is not published on CPAN.

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
