# Perl core and workspace

The core owns explicit tmux acquisition and commands. Captured entity handles
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
handlers intact. It owns child groups, bounded pipes, cancellation, deadlines,
and reaping. Argument vectors have no shell wrapper. Creating a pane from an
explicit shell command is a separate caller choice. A single-item command
array uses a fixed exec-ARGV shim because tmux otherwise invokes a shell.

The listing codec escapes backslashes, tabs, and newlines with one field lookup
per value. Length-prefixing through two lookups is unsafe for dynamic fields.
Text decoding is strict UTF-8; paths are octets. Non-UTF-8 path operands remain
usable locally and are refused by the initial JSON wire representation.

Live query plans preserve captured local evaluation, including errors. Native
candidate disagreement causes local fallback under auto and a race error under
require. Probes do not make multiple subprocess calls transactional.

Workspace owns JSON configuration and orchestration through public core APIs.
Its native distribution depends on the versioned core. Runtime code prefers
Perl's standard library. MCP is excluded. Persistent control, parallel
submission, notification streaming, and command lists are deferred; the first
implementation selects subprocess execution and ordered independent batches.

The declarations describe the implementation contract. Runtime, artifact,
compatibility, documentation, and independent adoption checks establish which
parts are qualified; architecture review alone does not establish support.
