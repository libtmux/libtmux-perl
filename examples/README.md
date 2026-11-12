# Examples

Start with the standalone programs in each native distribution. They use
installed public modules and ordinary Perl; no Python, author fixture, or
source-tree library path is required. The baseline is Perl 5.44 and Linux
x86_64 LP64 with tmux 3.3a–3.8.

## Run an installed-package example

[Install core](../docs/installation.md), then run the quick start from a
checkout with an explicit socket path:

```console
$ perl packages/core/examples/quickstart.pl "${TMPDIR:-/tmp}/libtmux-perl-$$.sock"
```

The example starts tmux if necessary, creates and removes its own session,
and preserves other sessions on that socket. Each live program accepts an
optional second argument naming the tmux executable. A conflicting example
session name is an error; existing sessions are never cleanup targets.

| Program | Task | Expected result |
| --- | --- | --- |
| [Core quick start](../packages/core/examples/quickstart.pl) | Create, split, rename, capture, clean up, and retain the graph. | `editor: 2 panes` and `logs: 1 pane`. |
| [Core workflow](../packages/core/examples/workflow.pl) | Arrange windows, send text, capture output, set environment, filter, compare quantifiers, and verify native queries. | `core workflow: ok`. |
| [Filter records](../packages/core/examples/filters.pl) | Match ordinary hash records, round-trip JSON, and inspect typed validation errors without tmux. | `%1` matches; the invalid numeric operand reports its criterion path. |
| [Async operations](../packages/async/examples/concurrent.pl) | Run concurrent Futures and ordered batches, remove the created session, and await close. | `first` before `second`; `async operations and cleanup: ok`. |
| [Workspace loading](../packages/workspace/examples/load.pl) | Read the adjacent JSON, plan, load, inspect two windows and three panes, repeat with skip, and clean up. | `workspace plan, load, repeat: ok`. |

Async requires the separate distribution and its Ppoll dependencies. Workspace
requires core and the workspace distribution. The packaged JSON uses literal
Perl commands. All examples ship alongside their own distribution's README
and logo assets.

## Run repository qualification programs

The programs in this directory exercise additional contracts through the
repository's fixture. Provision the [author environment](../.github/CONTRIBUTING.md#environment)
first. `Future::AsyncAwait` is needed only for `await.pl`.

```console
$ mise exec -- make examples
```

| Program | Contract |
| --- | --- |
| [quickstart.pl](quickstart.pl) | Select contextual window links, filter captured panes, and verify fixture cleanup. |
| [selection.pl](selection.pl) | Arrays, callbacks, cardinality, wire filters, relations, retained graphs, and native verification. |
| [workspace.pl](workspace.pl) | Plan, load, inspect panes, and repeat with `existing => 'skip'`. |
| [async.pl](async.pl) | Capture through a caller-owned Ppoll loop and await cleanup. |
| [await.pl](await.pl) | Use optional caller-side `async`/`await` syntax with core result objects. |
| [async-lifecycle.pl](async-lifecycle.pl) | Preserve failures, handle cancellation, and observe cleanup without destroying a borrowed server. |

`async-lifecycle.pl` also works with installed packages against an existing
explicit socket. Run its `--help` before using `--fail` or `--cancel`. A
cancelled operation does not prove cleanup has finished; continue driving
the loop until close succeeds.

## How the examples are checked

[The runner](../scripts/run-examples.pl) rejects nonzero exits and missing
expected output. Each live consumer runs with an owned private socket and a
pre-existing sentinel session. After the program exits, the runner verifies
that its session is gone and the borrowed session remains. Fixture teardown
checks process exit and removes owned files.

The tmux endpoint CI cells run the same programs. The installed-artifact job
extracts package examples from the exact native archives, verifies them against
the source, and runs them using only the external installation prefix. No
checkout module path supplies the consumer's imports.

README and guide code blocks marked with `example` come from the complete
program or a named region in it. Check for drift:

```console
$ mise exec -- make check-snippets
```

Keep expected output, source, and documentation consistent. The
[shared capability showcase](https://github.com/libtmux/docs/issues/243)
requires executed examples, recorded CI evidence, and an accurate tmux floor.
