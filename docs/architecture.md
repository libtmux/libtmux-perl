# Perl core, async and workspace

Core Operation plans share preparation, target validation, parsing and recovery
between synchronous and asynchronous executors. ProcessJob shares subprocess
ownership. Server methods perform mutations using explicit targets; entity
accessors read captured values. The core owns explicit tmux acquisition and commands. Captured entity handles
retain a graph of records and ID adjacency; they retain no transport. Field
readers and relationships perform no tmux I/O. A new snapshot observes new
state without modifying old handles.

[The catalog](../packages/core/lib/LibTmux/schema.json) defines field types,
relations, wire names, operators, and source capabilities. The
[behavior inventory](behavior-inventory.json) defines the required native
operation signatures and adaptations from the pinned Python reference.

Physical windows and panes have one identity per server generation. WindowLink
records preserve each session/index association, including repeated links.
Session-relative selection, movement, and unlinking require a link target.

Selections are blessed array references. Their query methods copy membership,
preserve order and duplicates, and have fixed return types. Native array
mutation remains possible; library methods validate membership. Compiled
filters copy their input, use schema-directed comparisons, and validate the
whole tree before evaluation. Missing data differs from known null.

The process adapter uses a private supervisor, leaving application signal
handlers intact. It owns child groups, bounded pipes, cancellation, command timeouts,
and reaping. Argument vectors have no shell wrapper. Creating a pane from an
explicit shell command is a separate caller choice. A single-item command
array uses a fixed exec-ARGV shim because tmux otherwise invokes a shell.
Trailing semicolons are escaped for tmux's command grammar independently of
shell safety. Each request forks a supervisor and a command child. Command
timeouts exclude queue waiting, setup and the total of a multi-command
operation; cleanup has a separate allowance. See [failure recovery](errors.md).

The supervisor uses Linux's child-subreaper facility so orphaned descendants
remain owned and can be reaped before cleanup is reported complete. The
qualified syscall adapter is Linux x86_64 LP64; other ABIs fail before dispatch.
The syscall number and `PR_SET_CHILD_SUBREAPER` constant come from the pinned
Linux v6.18 syscall table and prctl header. This avoids a non-core runtime
dependency without claiming untested architectures.

The listing codec escapes backslashes, tabs, and newlines with one field lookup
per value. Length-prefixing through two lookups is unsafe for dynamic fields.
Text decoding is strict UTF-8; paths are octets. Non-UTF-8 path operands remain
usable locally and are refused by the initial JSON wire representation.

Live query plans preserve captured local evaluation, including errors. Native
candidate disagreement causes local fallback under auto and an error under
require. A mismatch does not establish its cause; the baseline's race label and
hidden auto diagnostics require correction. Probes do not make multiple
subprocess calls transactional. See [query planning](query-planning.md).

Workspace owns JSON configuration and orchestration through public core APIs.
Its native distribution depends on the versioned core. Runtime code prefers
Perl's standard library. MCP is excluded.

The optional `LibTmux-Async` distribution adds bounded concurrent subprocess
submission through an injected caller-owned IO::Async loop. Standard Future
objects yield one result; Future::AsyncAwait is optional caller syntax. Core
command preparation, framing, graph parsing, and errors are shared through
Operation and ProcessJob. Core and workspace have no async runtime dependency.
Cancelling a Future requests cleanup; only successful close-observer completion
proves owned jobs and pipes exited. Cancelling observers cannot cancel private
cleanup. The caller keeps driving and retains ownership of its loop.

| Capability | Decision | Evidence and boundary |
| --- | --- | --- |
| Literal subprocess I/O | Selected default | Standard-library supervisor; bounded outputs/command timeouts; separate status/error channels. |
| Ordered independent batches | Selected | One result/error record per request in input order; no tmux command-list attribution claim. |
| Bounded concurrency | Selected in async only | Future/IO::Async already provide loop ownership, readiness, and process reaping; FIFO pipe tests require overlapping progress. |
| Persistent control mode | Deferred | Unsolicited notifications, framing, client lifetime, and daemon-loss recovery need a separate qualification project. |
| Streaming output API | Deferred | Current transport drains pipes but returns bounded completed results; no public subscription/backpressure API is promised. |
| tmux command chaining | Deferred | Group-level completion cannot establish per-command outcomes without a distinct contract. |

The optional dependencies are runtime requirements only of async. PPI is an
author-only documentation parser: native B::Deparse inspection lowers signatures
into argument checks and cannot preserve authored defaults. Pod::Simple remains
the native POD parser; runtime consumers need neither tool. No core object
framework or experimental syntax is selected.

Native documentation treats each declared Perl package as its own namespace.
A `::` name prefix does not create an enclosing class or package declaration.
Methods retain their declaring package owner; `use parent` supplies the separate
inheritance relation. Authored POD links keep their exact package/method targets.
The exporter also records PPI function spans and code tokens for the shared
command index. Each file binds those records to its source digest. POD/comments
never become code evidence. Dynamic operation plans require reviewed command
and scope claims rather than inferring dispatch from a string literal.

The declarations describe the implementation contract. Runtime, artifact,
compatibility, documentation, and independent adoption checks establish which
parts are qualified; architecture review alone does not establish support.
The [architecture decision](dev/adr/0001-core-async-workspace-architecture.md)
records required locale/framing, descriptor and Workspace ownership corrections
separately from the accepted model.
