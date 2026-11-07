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

A partial AND conjunct can prune candidates. Partial OR/NOT cannot. Relations,
null, bytes, and unsupported scalar operators remain local. Relation pushdown
and serialized regex dialects are deferred. Complete relation domains are never
pruned before `every` or `none` evaluation.

`native_filter` is an explicit expert escape hatch, exclusive with portable
criteria and pushdown policy. It selects captured root IDs and rejects new IDs
that appeared outside capture. It has native tmux semantics, not wire semantics.
