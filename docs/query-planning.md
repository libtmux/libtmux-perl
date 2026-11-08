---
title: Explicit acquisition and native filters
description: Explicit acquisition and native filters with the Perl libtmux distributions.
---

`$snapshot->panes->where($criteria)` and callbacks evaluate eagerly without
I/O. `query_panes` explicitly acquires a graph and returns a PaneSelection.
`explain_panes` creates a local plan using support-floor capabilities; it does
not connect. Execution binds capabilities to the captured daemon generation.

| Policy | Behavior |
| --- | --- |
| `never` | Acquire and evaluate locally. |
| `auto` | Verify safe scalar native candidates; fall back to captured local results on disagreement. |
| `require` | Require complete exact lowering and native/captured agreement. |

The current implementation captures and evaluates the complete graph before
candidate verification, preserving local error behavior. It makes no I/O-saving
claim. Plans identify commands, lowered filters, residual reasons, and capability
requirements. Numeric lowering uses tmux numeric expressions. Literal operands
are escaped for the tmux grammar independently of argument-vector safety.

`auto` is the default. It costs an extra command and supervisor when lowering
is available. Select `never` when only the captured answer is needed. To inspect
the comparison, supply `on_verification => sub ($report) { ... }`. The observer
receives one detached hashref in void context; its return is ignored. It runs
inline once after a successful decision, including fallback. Exceptions
propagate unchanged unless the operation has already been cancelled;
cancellation suppresses subsequent result/error delivery.
Failed acquisition, decoding or native commands do not
invoke it and remain failures.

The report identifies `status`, `comparison`, capture generation/interval,
executed filter, residual reasons, and captured/local/native ID arrays.
`disabled` means `never`, and `local` means no safe lowering was available.
`agreed` distinguishes exact equality from partial candidate inclusion;
`disagreed` lists missing, unexpected and uncaptured IDs. `native` reports only
captured membership for the expert escape hatch. See
[`Server`'s report contract](../packages/core/lib/LibTmux/Server.pm)
and the [tested query example](../examples/selection.pl).

`require` disagreement throws `LibTmux::X::QueryMismatch`, with the report in
`details->{verification}`. The observer does not run before that failure.
A mismatch can reflect a race, a compiler defect or a backend difference;
it does not establish which occurred. Matching observations also do not prove
an atomic capture. [ADR 0003](dev/adr/0003-query-verification-diagnostics.md)
records the diagnostic and default-policy decision.

A partial AND conjunct can prune candidates. Partial OR/NOT cannot. Relations,
null, bytes, and unsupported scalar operators remain local. Relation pushdown
and serialized regex dialects are deferred. Complete relation domains are never
pruned before `every` or `none` evaluation.

`native_filter` is an explicit expert escape hatch, exclusive with portable
criteria and pushdown policy. It selects captured root IDs and rejects new IDs
that appeared outside capture. It has native tmux semantics, not wire semantics.
