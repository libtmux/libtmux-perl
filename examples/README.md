# Examples

Run these programs from a provisioned checkout of [libtmux for Perl](../README.md).
They use Perl 5.44.0, Linux x86_64 LP64, and tmux 3.3a–3.8. The async programs
also use the dependencies in the [author setup](../.github/CONTRIBUTING.md#environment).
`Future::AsyncAwait` is needed only for `await.pl`.

## Run the examples

```console
$ mise exec -- make examples
```

The [runner](../scripts/run-examples.pl) rejects unsuccessful programs and
missing expected output. The installed-artifact CI job runs these same
programs against an isolated installation prefix. The two tmux CI cells run
them against the oldest supported and newest stable releases.

| Program | What it demonstrates | Expected result |
| --- | --- | --- |
| [quickstart.pl](quickstart.pl) | Create a session, rename and split a window, add a window, and traverse a snapshot. | Two windows named `editor` and `logs`; the selected pane belongs to `editor`. |
| [selection.pl](selection.pl) | `where`, `grep`, native arrays, cardinality, compiled filters, relations, retained graphs, and native query verification. | `selection, wire, graph lifetime, quantifiers, and query: ok` |
| [workspace.pl](workspace.pl) | Plan and load a JSON workspace, then repeat it with `existing => 'skip'`. | `workspace load and repeat: ok` |
| [async.pl](async.pl) | Capture through a caller-owned Ppoll loop and wait for executor cleanup. | `async capture and cleanup: ok` |
| [await.pl](await.pl) | Use optional caller-side `async`/`await` syntax with the same core result objects. | `optional caller await syntax: ok` |
| [async-lifecycle.pl](async-lifecycle.pl) | Preserve operation failures, handle cancellation, and observe cleanup without destroying a borrowed server. | Capture, failure, and cancellation scenarios all report completed executor cleanup. |

## Server ownership

The checkout demos use the repository's fixture to create a unique socket,
ignore user tmux configuration, and verify owned process exit during cleanup.
The fixture is author tooling, not an installed package API. The runner supplies
library paths and the child-reaping scope needed by these programs.

After installing core and async, `async-lifecycle.pl` also works as a standalone
consumer program. It takes an explicit socket path for an existing server and
closes only its executor:

```console
$ perl examples/async-lifecycle.pl --help
```

Read the [async guide](../docs/async.md) before using its failure or cancellation
options. Cancellation does not prove cleanup has finished; keep driving the
loop until `close` completes successfully.

## Quote tested source

The complete programs embedded in the reader guides use `example` markers.
[The snippet check](../scripts/check-snippets.pl) compares each marked block
with its source file:

```console
$ mise exec -- make check-snippets
```

Keep the program, its expected output in the runner, and its documentation
consistent. State fixture or existing-server prerequisites next to an excerpt.
Offer a capability only after its example runs and checks the claimed result;
the [shared showcase standard](https://github.com/libtmux/docs/issues/243)
describes the evidence required by libtmux.org.
