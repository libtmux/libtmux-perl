# ADR 0003: Observable native candidate verification

## Status

Accepted, 2026-11-08. Refines the query execution contract in
[ADR 0001](0001-core-async-workspace-architecture.md#verify-scalar-native-candidates-against-captured-local-semantics).

## Context

The query executor captures and evaluates the complete graph before checking
native candidates. `auto` returns the captured selection even when those
candidates disagree. Discarding that comparison makes the extra command
unobservable. `require` reports disagreement as `AcquisitionRace`, although a
translation defect or backend difference can produce the same evidence.

## Decision

Keep the `PaneSelection` return and the `auto`, `never` and `require` policies.
Add an optional `on_verification => sub ($report) { ... }` observer to
`query_panes`. Validate the coderef before I/O. The callback receives one fresh
hashref in void context; its return, including a Future, is ignored. It runs
inline once after a successful query decision, including `auto` fallback.
The library neither interrupts nor awaits it. Callback exceptions propagate
unchanged unless the operation has already been cancelled. Acquisition,
command, decoding and policy failures do not invoke it.
Cancellation before a query decision suppresses the callback with the remaining
operation continuations. If an observer cancels its query or closes the async
facade, cancellation remains authoritative even if it then throws. The async
facade uses the same operation contract.

Reports distinguish `disabled`, `local`, `agreed`, `disagreed` and `native`.
They identify the policy, captured generation and interval, actual lowering,
translation exactness, comparison kind, captured/local/native IDs and residual
reasons. Mismatch arrays identify missing local candidates, uncaptured native
IDs and, for exact lowering, unexpected native matches. ID arrays have stable
order and are independent of graph membership. The callback cannot rewrite
the already selected result by editing its report.

The report has these keys:

| Key | Value |
| --- | --- |
| `policy` | `auto`, `never`, `require`, or `native` for the expert escape hatch |
| `status` | One of the five statuses below |
| `comparison` | `none`, `exact_ids`, `candidate_superset`, or `captured_membership` |
| `native_checked` | Boolean; true only after a valid native result |
| `translation_exact` | Boolean, or `undef` for disabled/expert execution |
| `native_filter` | Actual tmux expression, or `undef` when none ran |
| `reasons` | Fresh arrayref of lowering reasons |
| `server_id`, `generation`, `daemon_version` | Captured identity strings |
| `capture_start`, `capture_end` | Capture wall-clock seconds since the epoch |
| `captured_ids` | Physical IDs in captured order |
| `local_ids` | Local matches in selection order; `undef` in expert mode |
| `native_ids` | Unique IDs in native first-occurrence order; `undef` if no check ran |
| `missing_ids` | Local IDs absent natively, in local order |
| `unexpected_ids` | Exact native matches absent locally, in native order |
| `uncaptured_ids` | Native IDs absent from the graph, in native order |

All containers are detached copies; the report retains no entity handles or
graph store. Empty arrays mean an observed empty set. `undef` native IDs mean
no native result was observed. Nonapplicable mismatch arrays are empty.

| Status | Comparison and outcome |
| --- | --- |
| `disabled` | `never`; `none`, no native check |
| `local` | `auto` has no safe lowering; `none`, no native check |
| `agreed` | Exact ID equality or partial candidate inclusion, with no uncaptured IDs |
| `disagreed` | At least one applicable mismatch array is nonempty |
| `native` | Expert filter's IDs all belong to the capture; `captured_membership` only |

An exact translation and matching observations are separate facts. Partial
lowering checks that native candidates include every local match and refer
only to captured roots; it does not establish equality with the complete
filter. An expert `native_filter` reports native selection, not portable
equivalence. No report claims an atomic capture or identifies the cause of a
discrepancy.

Use `LibTmux::X::QueryMismatch` when `require` disagrees or an expert native
filter returns an uncaptured ID. Its `details->{verification}` contains the
report. Do not call an observer before throwing these failures: an observer
exception must not replace the query's failure. Existing operational errors
retain their original exception object and bounded process result.

Retain the `auto` default during this compatibility correction. It makes a
backend comparison available to callers supplying the observer without an
additional policy switch. It costs one extra command and supervisor when
lowering is available, and can expose another operational failure. It saves
neither acquisition nor local evaluation. Callers that only need the captured
answer should select `never`. Reconsider the default with caller evidence or
an independently qualified acquisition optimization; do not infer a latency
benefit from successful candidate agreement.

## Alternatives and costs

- Selection metadata would require side storage around mutable blessed arrays.
- A server's last report would race between concurrent operations.
- A second result wrapper would add another query return contract.
- A callback keeps the established return and has an explicit exception and
  async-completion cost. Reports describe completed decisions, not partial
  acquisition progress, and are separate from the filter wire format.

## Verification

Use controlled operation responses to prove all statuses, exact and partial
mismatches, stable ID order, report mutation isolation, callback arity/context,
thrown-object identity and operational failure preservation. Live tmux tests
compare supported scalar queries with local results on a controlled graph.
Exercise the callback through the optional async facade and an installed
consumer example. A passing comparison is evidence for that observed state,
not a proof about every possible concurrent server mutation.
