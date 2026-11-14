---
title: Explicit acquisition and native filters
description: Explicit acquisition and native filters with the Perl libtmux distributions.
---

## See what runs in tmux and what stays local

- `$snapshot->panes->where($criteria)` and callbacks evaluate in Perl, with no
  I/O.
- `query_panes` acquires a graph and returns a `PaneSelection`.
- `explain_panes` builds a plan with no I/O, using the support-floor tmux
  capabilities. Running a query binds capabilities to the captured daemon.

[explain.pl](../packages/core/examples/explain.pl) needs no tmux server:

<!-- example: packages/core/examples/explain.pl -->
```perl
use v5.44;
use LibTmux::Server;

# Planning does no I/O, so this program needs no tmux server.
my $server = LibTmux::Server->new;

my $criteria = {active => true, width => {-gte => 1}};
my $plan     = $server->explain_panes(where => $criteria);
say 'tmux filter: ', $plan->to_data->{native_filter};

my $relation = {window => {-is => {name => 'editor'}}};
my $residual = $server->explain_panes(where => $relation);
say 'stays local: ', $residual->to_data->{residual_reasons}[0];

my $never = $server->explain_panes(where => $criteria, pushdown => 'never');
say 'pushdown off: ', $never->summary;
```

It prints the tmux filter for the first plan, the reason the second stays
local, and the summary with pushdown off.

## Compare local and native results

The [installed-package workflow](../packages/core/examples/workflow.pl) runs
both on a controlled graph. It continues from the quick start's `$server`:

<!-- example: packages/core/examples/workflow.pl#query -->
```perl
my $where = {active => true, width => {-gte => 1}};
my $local = $server->query_panes(where => $where, pushdown => 'never');
my $verification;
my $verified = $server->query_panes(
    where           => $where,
    pushdown        => 'require',
    on_verification => sub ($report) { $verification = $report },
);
say 'native verification: ', $verification->{status};

```

It prints `native verification: agreed` after checking that both calls return
the same IDs.

| Policy | Behavior |
| --- | --- |
| `never` | Acquire and evaluate locally. |
| `auto` | Verify safe scalar native candidates; fall back to captured local results on disagreement. |
| `require` | Require complete exact lowering and native/captured agreement. |

- `auto` is the default. It costs one extra command when lowering is
  available. Pick `never` when you only need the captured answer.
- Every policy still acquires and evaluates the complete graph first, so local
  errors stay visible. The native check saves no I/O.
- Either result is a captured local selection.
- A plan lists commands, lowered filters, residual reasons and capability
  needs. Numeric lowering uses tmux numeric expressions, and literal operands
  are escaped for the tmux grammar.

## Read the verification report

Pass `on_verification => sub ($report) { ... }` to inspect the comparison.

- The observer gets one detached hashref, runs inline once after a successful
  decision (including a fallback), and its return value is ignored.
- Its exceptions propagate unless the operation was cancelled; cancellation
  drops later results and errors.
- A failed acquisition, decode or native command never calls it.

The report holds:

- `status`, `comparison`, the capture generation and interval, the executed
  filter, and residual reasons.
- Captured, local and native ID arrays.

Statuses:

- `disabled` means `never`; `local` means nothing could be lowered safely.
- `agreed` separates exact equality from partial candidate inclusion.
- `disagreed` lists missing, unexpected and uncaptured IDs.
- `native` reports only captured membership, for the expert escape hatch.

See [`Server`'s report contract](../packages/core/lib/LibTmux/Server.pm) and the
[tested query example](../examples/selection.pl).

## When native and local disagree

- Under `require`, a disagreement throws `LibTmux::X::QueryMismatch`. The
  report sits under the `verification` key of `LibTmux::X::details`, and the
  observer does not run.
- A mismatch can be a race, a compiler defect or a backend difference; it
  does not say which. Matching results do not prove an atomic capture. [ADR 0003](dev/adr/0003-query-verification-diagnostics.md) records
  the decision.

## What tmux can check

- A partial AND conjunct can prune candidates. A partial OR or NOT cannot.
- Relations, null, bytes and unsupported scalar operators stay local, and a
  complete relation domain is never pruned before `every` or `none` runs.
- Relation pushdown and serialized regexes are deferred.
- `native_filter` is an expert escape hatch, exclusive with portable criteria
  and the pushdown policy. It selects captured root IDs, rejects IDs that
  appeared after capture, and uses native tmux semantics rather than wire
  semantics.
