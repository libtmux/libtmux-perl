---
title: Snapshots and linked-window identity
description: Snapshots and linked-window identity with the Perl libtmux distributions.
---

A physical window can appear at several indexes in one session and in several
sessions. `WindowLink` owns session-relative index and active state. A Pane's
`window` always returns the physical Window. Session changes use explicit links.

Snapshot `windows` and `panes` contain each physical identity once. Raw
`listings` retain contextual rows and multiplicity. Selection filters retain
their own input order and duplicates. Two occurrences of one identity still
make `one` ambiguous.

Selections may combine captures from the same server generation. Each handle
retains its own observed graph; combining them does not reconcile capture times
or create a new snapshot. Mixing server scopes or daemon generations is an
`InvalidSelection` error. Use one snapshot when a query needs one capture interval.

IDs remain strings. Write session IDs as `'$1'` in Perl so regex captures do
not interpolate. Identity includes server, daemon generation, kind, and ID.
Captured handles prevent silent retargeting after a restart; probes and
commands remain separate observations, so they do not form a transaction.

The store owns scalar records and ID adjacency. Handles strongly retain that
store, which does not strongly own handles. A retained pane keeps its observed
window even when the Snapshot wrapper leaves scope. Retaining one handle can
retain the graph; `to_record` exports detached scalar data instead.

Acquisition records start/end and completeness. Strict live capture rejects
missing required topology. Unloaded fields and relations throw when needed;
null and loaded-empty relations remain distinct. Accessors return independent
membership arrays. Query methods are nonmutating, while native arrays remain
mutable and every library query validates their members.
