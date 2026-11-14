---
title: Filter captured selections
description: Native Perl arrays, strict criteria, graph quantifiers, and wire filters.
---

Use `where({...})` for query data and `grep(sub ($pane) {...})` for arbitrary
Perl behavior. Native `->@*`, indexing, `grep`, `map`, `sort`, and List::Util
remain available. `to_array` returns a fresh unblessed array reference.

Fields select comparison semantics: text, safe decimal integers, booleans,
nullability, allowed operators, and relation cardinality come from one catalog.
False, zero, "0", empty text, and undef remain distinct. Integer operands are
bounded to +/-9007199254740991; invalid numeric text never becomes zero.

| Grammar | Meaning |
| --- | --- |
| scalar or `-eq`, `-ne` | Schema-directed equality and complement. |
| `-in`, `-not_in` arrays | Explicit membership; empty arrays mean false/true. |
| `-lt`, `-lte`, `-gt`, `-gte` | Authorized numeric ordering. |
| `-contains`, `-starts_with`, `-ends_with` | Literal, case-sensitive text. |
| `-and`, `-or` arrays; `-not` node | Complete criteria nodes. |
| `-some`, `-every`, `-none` | To-many quantifiers over the complete captured domain. |
| `-is`, `-is_not` | To-one criteria or explicit nullable absence. |

Fields/operators in a hash are conjoined. Duplicate Perl hash keys overwrite;
use multiple operators or explicit `-and`. Empty criteria and empty AND are
true; empty OR is false. On a loaded empty relation, some is false and
every/none true. Conditions inside one some apply to the same child; separate
existentials may match different children. Unloaded relations never prove empty.

Full compilation precedes evaluation, even on empty selections. Hash keys
traverse lexically; logical arrays preserve their order. Short-circuiting may
avoid unavailable reads once a result is known. Known-null ordering/text is
false; negation reverses known results, never missing-data failures.

Evaluation order affects failures as well as matches. For an inactive record
with unloaded width, an AND array testing `active` before `width` can return
false; reversing those nodes reads width first and throws. Flattening them into
a hash instead selects lexical order. Wire serialization retains logical-array
order; optimizers must preserve availability and error behavior. The depth-64
and 10,000-node compilation limits do not cap membership operands or string bytes.

Native arrays remain mutable. Every library method validates all N occurrences
before returning even `first`, `count` or `exists`; that validation is O(N).
Predicates may then stop early. `where` evaluates and validates its output;
`iterator` also copies membership. Raw indexing and dereferencing retain normal
Perl behavior. A mutable selection cannot safely cache a prior validation.

`LibTmux::Filter` owns normalized criteria, supports plain records and explicit
registered readers, and exports JSON with schema `"libtmux.where/v1"`.
Wire names use camelCase and dash-free operators. Regex/coderefs/cycles/blessed
values are refused at that data boundary. Native Perl `qr//` remains available
in callbacks.

## Query installed objects and ordinary records

The [live workflow](../packages/core/examples/workflow.pl) creates two editor
panes before running these local queries:

<!-- example: packages/core/examples/workflow.pl#filter -->
```perl
my $snapshot = $server->snapshot;
my $panes =
    $snapshot->windows->one({name => 'editor'})
    ->panes->where({width => {-gte => 1}})
    ->grep(sub ($pane) { $pane->height > 0 });
my @ids    = map { $_->id } $panes->@*;
my $active = $panes->one({active => true});
say 'editor panes: ',          scalar @ids;
say 'active pane belongs to ', $active->window->name;

```

The [record-only program](../packages/core/examples/filters.pl) runs with the
installed core and no tmux server:

```console
$ perl packages/core/examples/filters.pl
```

<!-- example: packages/core/examples/filters.pl#records -->
```perl
use v5.44;
use LibTmux::Filter;

my $filter = LibTmux::Filter->new(
    entity => 'pane',
    where  => {
        active          => true,
        current_command => {-in  => [qw(perl vim)]},
        width           => {-gte => 80},
    },
);
my @records = (
    {id => '%1', active => true,  current_command => 'perl', width => 120},
    {id => '%2', active => false, current_command => 'perl', width => 120},
    {id => '%3', active => true,  current_command => 'vim',  width => 40},
);
my @matches = grep { $filter->matches($_) } @records;
say 'matching records: ', join ', ', map { $_->{id} } @matches;

```

It prints `matching records: %1`. Its complete source also checks a JSON
round trip. No author fixture, Python evaluator, or object framework is needed
by either consumer program.

## Save criteria for reuse

In the live workflow, the compiled filter can be stored as versioned JSON and
reused on a captured selection:

<!-- example: packages/core/examples/workflow.pl#wire -->
```perl
my $filter = LibTmux::Filter->new(
    entity => 'pane',
    where  => {active => true, width => {-gte => 1}},
);
my $restored = LibTmux::Filter->from_json($filter->to_json);
my $selected = $panes->where($restored);
say 'restored filter matches: ', $selected->count;

```

Changing the original criteria hash does not change a compiled filter. Schema
validation still applies after decoding; executable callbacks belong in `grep`,
not in the wire data.

## Distinguish one child from two children

One `-some` subtree applies every condition to the same child. Two existential
subtrees can match different children. The workflow limits the domain to its
own editor window and checks both cases:

<!-- example: packages/core/examples/workflow.pl#relations -->
```perl
my $windows    = $snapshot->windows->where({id => $editor->id});
my $same_child = $windows->where(
    {
        panes => {-some => {-and => [{index => 0}, {index => 1}]}},
    }
);
my $different_children = $windows->where(
    {
        -and => [
            {panes => {-some => {index => 0}}},
            {panes => {-some => {index => 1}}},
        ],
    }
);
say 'same child: ',         $same_child->count;
say 'different children: ', $different_children->count;

```

An individual pane cannot have both index 0 and index 1, so `same child` is 0.
The window has both panes, so `different children` is 1. Loaded empty relations
make `-some` false and `-every`/`-none` true. Unloaded relations remain errors
when evaluation needs them. See [graph identity](graph.md).

## Independent-port subset

The shared fixture vocabulary is proposed for this port. A source-pinned Python
QueryList evaluator agrees on the advertised subset: Boolean/integer/text
equality, literal contains/prefix/suffix, membership, and empty membership.
The adaptation maps wire field names to record keys and operators to native
QueryList lookup keywords. It does not claim that Python accepts this wire API.

Known-null equality initially disagreed: the pinned Python filter rejects None
fields before its equality lookup. That difference remains recorded. Numeric
ordering, availability errors, graph quantifiers, validation on empty data,
and canonical-name enforcement have no equivalent declared Python contract
and are marked unsupported, not passed. Perl fixtures cover those semantics.
See [the fixtures](../conformance/where-v1.json) and
[the independent source pin](../scripts/conformance-reference.json).
