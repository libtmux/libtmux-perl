# Examples

Start with the standalone programs in each distribution. They use installed
public modules and ordinary Perl, with no Python, author fixture or source-tree
library path. They need Perl 5.44 or newer, tmux 3.3a or newer, and Linux.

## Run an installed-package example

[Install core](../docs/installation.md), then run the quick start from a
checkout:

```console
$ perl packages/core/examples/quickstart.pl
```

- It runs its own tmux server, creates and removes its own session, and stops.
- Pass a socket path to join a server you already run. The program then removes
  only its own session and leaves the rest.
- A second argument names the tmux executable.
- A session with the example's name is an error, never a cleanup target.

| Program | Task | Expected result |
| --- | --- | --- |
| [Core quick start](../packages/core/examples/quickstart.pl) | Create, split, rename, capture, clean up, and retain the graph. | `editor: 2 panes` and `logs: 1 pane`. |
| [Select panes](../packages/core/examples/select.pl) | Filter captured panes and handle an empty selection. | `editor panes: 2`. |
| [Send input](../packages/core/examples/input.pl) | Type, capture, set environment and options, and batch commands. | `PROJECT=api` and `@build=ok`. |
| [Explain a query](../packages/core/examples/explain.pl) | Show what tmux runs and what stays local, without tmux. | `tmux filter: ...` and `stays local: ...`. |
| [Retained graph](../packages/core/examples/graph.pl) | Keep an old capture across a rename. | `captured name: logs` and `live name: build`. |
| [Core workflow](../packages/core/examples/workflow.pl) | Arrange windows, filter, compare quantifiers, and verify native queries. | `core workflow: ok`. |
| [Filter records](../packages/core/examples/filters.pl) | Match hash records, round-trip JSON, and inspect validation errors without tmux. | `%1` matches; the invalid numeric operand reports its criterion path. |
| [Async operations](../packages/async/examples/concurrent.pl) | Run concurrent Futures and ordered batches, remove the session, and await close. | `first` before `second`; `async operations and cleanup: ok`. |
| [Workspace loading](../packages/workspace/examples/load.pl) | Plan, load, inspect two windows and three panes, repeat with skip, and clean up. | `workspace plan, load, repeat: ok`. |

Async needs its own distribution and Ppoll dependencies. Workspace needs core
and the workspace distribution. Every program ships with its distribution's
README and logo assets.

## Run repository qualification programs

These programs use the repository's fixture. Provision the
[author environment](../.github/CONTRIBUTING.md#environment) first.
`Future::AsyncAwait` is needed only for `await.pl`.

```console
$ mise exec -- make examples
```

| Program | Contract |
| --- | --- |
| [quickstart.pl](quickstart.pl) | Select contextual window links, filter captured panes, and verify fixture cleanup. |
| [selection.pl](selection.pl) | Arrays, callbacks, cardinality, wire filters, relations, retained graphs, and native verification. |
| [workspace.pl](workspace.pl) | Plan, load, inspect panes, and repeat with `existing => 'skip'`. |
| [async.pl](async.pl) | Capture through a caller-owned Ppoll loop and await cleanup. |
| [await.pl](await.pl) | Use optional caller `async`/`await` syntax with core result objects. |
| [async-lifecycle.pl](async-lifecycle.pl) | Preserve failures, handle cancellation, and observe cleanup without destroying a borrowed server. |

`async-lifecycle.pl` also works with installed packages against an existing
socket. Run its `--help` before `--fail` or `--cancel`. A cancelled operation
does not prove cleanup has finished; keep driving the loop until close
succeeds.

## How the examples are checked

[The runner](../scripts/run-examples.pl):

- Rejects a nonzero exit or missing expected output.
- Runs each live program with an owned private socket and a sentinel session,
  then checks that the program's session is gone and the sentinel remains.
- Runs the self-contained programs with no socket, and fails if one leaves a
  tmux server or files behind.

CI runs the same programs on the oldest and newest supported tmux. The
installed-artifact job extracts the examples from the native archives, checks
them against the source, and runs them from an external installation prefix.

Embedded README and guide blocks marked `example` come from a complete program
or a named region in it. Check for drift:

```console
$ mise exec -- make check-snippets
```

The [shared capability showcase](https://github.com/libtmux/docs/issues/243)
lists only executed examples with recorded CI evidence.
