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

The complete example below is copied from an executed program. The fixture
helper uses an owned socket, observes process exit, and cleans up on failures.

<!-- example: selection.pl -->
```perl
use v5.44;
use FindBin;
use lib "$FindBin::Bin/../scripts/lib";
use LibTmuxFixture;
use LibTmux::Filter;
use List::Util qw(any first);
LibTmuxFixture->run(
    sub ($server, $root) {
        my $session = $server->new_session(
            name    => 'example',
            command => ['/bin/sleep', '120']
        );
        my $initial = $session->window_links->one->window->panes->one;
        $server->split_pane(
            pane       => $initial,
            horizontal => true,
            command    => ['/bin/sleep', '120']
        );
        my $snapshot = $server->snapshot;
        my $panes    = $snapshot->panes->where({current_command => 'sleep'})
            ->grep(sub ($pane) { $pane->width >= 1 });
        die 'expected two panes' unless $panes->count == 2;
        for my $pane ($panes->@*) {
            say $pane->id . ' ' . $pane->current_command;
        }
        my $only_active = $panes->one({active => true});
        die 'active pane unavailable' unless defined $only_active;
        my $has_active   = any { $_->active } $panes->@*;
        my $first_active = first { $_->active } $panes->@*;
        die 'List::Util alternatives differ'
            unless $has_active && $first_active->id eq $only_active->id;
        my @ids      = map  { $_->id } $panes->@*;
        my @positive = grep { $_->width > 0 } $panes->@*;
        die 'ordinary Perl arrays differ' unless @ids == 2 && @positive == 2;
        my $filter =
            LibTmux::Filter->new(entity => 'pane', where => {active => true});
        my $decoded = LibTmux::Filter->from_json($filter->to_json);
        die 'wire filter changed meaning'
            unless $panes->where($decoded)->one->id eq $only_active->id;
        my $retained = do {
            my $observed = $server->snapshot;
            $observed->pane_by_id($only_active->id);
        };
        die 'retained graph lost a relationship'
            unless $retained->window->panes->count == 2;
        my $same_child = $snapshot->windows->where(
            {panes => {-some => {-and => [{index => 0}, {index => 1}]}}});
        my $different_children = $snapshot->windows->where(
            {
                -and => [
                    {panes => {-some => {index => 0}}},
                    {panes => {-some => {index => 1}}}
                ]
            }
        );
        die 'quantifiers conflated children'
            unless $same_child->count == 0 && $different_children->count == 1;
        my $where = {active => true, width => {-gte => 1}};
        my $local = $server->query_panes(where => $where, pushdown => 'never');
        my $native =
            $server->query_panes(where => $where, pushdown => 'require');
        die 'native/local disagreement'
            unless join(',', map { $_->id } @$local) eq
            join(',', map { $_->id } @$native);
        say 'selection, wire, graph lifetime, quantifiers, and query: ok';
    }
);
```

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
