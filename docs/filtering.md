---
title: Filter captured selections
description: Native Perl arrays, strict criteria, graph quantifiers, and wire filters.
---

## Query installed objects and ordinary records

Use `where({...})` for query data and `grep(sub ($pane) {...})` for arbitrary
Perl. Native `->@*`, indexing, `grep`, `map`, `sort` and List::Util keep
working; `to_array` returns a fresh unblessed array reference.

[select.pl](../packages/core/examples/select.pl) starts a private server,
splits a window, and filters its panes:

<!-- example: packages/core/examples/select.pl -->
```perl
use v5.44;
use File::Temp ();
use LibTmux::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => "$private/tmux.sock",
    config_file => '/dev/null',
);
my $failure;
try {
    my $session = $server->new_session(
        name    => 'perl-select',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => [$^X, '-e', 'while (<STDIN>) { print }'],
    );

    my $snapshot = $server->snapshot;
    my $panes =
        $snapshot->windows->one({name => 'editor'})
        ->panes->where({width => {-gte => 1}})
        ->grep(sub ($pane) { $pane->height > 0 });
    my $active = $panes->one({active => true});
    say 'editor panes: ',          $panes->count;
    say 'active pane belongs to ', $active->window->name;

    # example: begin nomatch
    try { $panes->one({width => {-gt => 10_000}}) }
    catch ($error) {
        die $error unless $error isa LibTmux::X::NoMatch;
        say 'no pane is that wide';
    }

    # example: end nomatch
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
```

The [record-only program](../packages/core/examples/filters.pl) needs no tmux
server:

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

It prints `matching records: %1`. The complete source also checks a JSON round
trip.

## Criteria

Fields select the comparison: text, safe decimal integers, booleans,
nullability, operators and relation cardinality all come from one catalog.

- False, zero, `"0"`, empty text and undef stay distinct.
- Integer operands are bounded to +/-9007199254740991. Invalid numeric text
  never becomes zero.

| Grammar | Meaning |
| --- | --- |
| scalar or `-eq`, `-ne` | Schema-directed equality and complement. |
| `-in`, `-not_in` arrays | Explicit membership; empty arrays mean false/true. |
| `-lt`, `-lte`, `-gt`, `-gte` | Authorized numeric ordering. |
| `-contains`, `-starts_with`, `-ends_with` | Literal, case-sensitive text. |
| `-and`, `-or` arrays; `-not` node | Complete criteria nodes. |
| `-some`, `-every`, `-none` | To-many quantifiers over the complete captured domain. |
| `-is`, `-is_not` | To-one criteria or explicit nullable absence. |

- Fields and operators in one hash are conjoined. A duplicate Perl hash key
  overwrites; use several operators or an explicit `-and`.
- Empty criteria and an empty AND are true; an empty OR is false.
- On a loaded empty relation, `-some` is false and `-every` and `-none` are
  true.
- Conditions inside one `-some` apply to the same child; separate existentials
  may match different children.
- An unloaded relation never proves empty.
- Known-null ordering and text are false. Negation reverses known results,
  never a missing-data failure.

## Evaluation order

- Compilation of the whole filter comes before evaluation, even on an empty
  selection. Hash keys traverse in lexical order; logical arrays keep theirs.
- A short circuit may skip an unavailable read once the result is known. For
  an inactive record with unloaded width, an AND testing `active` before
  `width` can return false, and the reverse order throws.
- Flattening those nodes into a hash selects lexical order. Wire serialization
  keeps logical-array order.
- Compilation caps depth at 64 and nodes at 10,000. Membership operands and
  string bytes are uncapped.

## Selections stay mutable

- Native arrays stay mutable, so every library method validates all N members
  before returning, even `first`, `count` or `exists`. That is O(N).
- Predicates may then stop early. `where` validates its output; `iterator`
  also copies membership.
- Raw indexing and dereferencing keep normal Perl behavior.

## Save criteria for reuse

`LibTmux::Filter` owns normalized criteria, matches plain records or
registered readers, and exports JSON with schema `"libtmux.where/v1"`. Wire
names use camelCase and dash-free operators.

<!-- example: packages/core/examples/filters.pl#wire -->
```perl
my $restored = LibTmux::Filter->from_json($filter->to_json);
say 'restored filter matches: ',
    scalar grep { $restored->matches($_) } @records;

```

It prints `restored filter matches: 1`.

- Changing the original criteria hash does not change a compiled filter.
- Schema validation still runs after decoding.
- Regexes, coderefs, cycles and blessed values are refused at the data
  boundary. Native `qr//` works in `grep` callbacks.

## Distinguish one child from two children

One `-some` subtree applies every condition to the same child. Two existential
subtrees can match different children. The workflow limits the domain to its
own editor window and checks both cases. It continues from the workflow's
`$snapshot` and `$editor`:

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

- A pane cannot have index 0 and index 1, so `same child` is 0.
- The window has both panes, so `different children` is 1.
- Loaded empty relations make `-some` false and `-every` and `-none` true.
  Unloaded relations stay errors when evaluation needs them.

See [graph identity](graph.md).

## Conformance fixtures

- A source-pinned Python QueryList evaluator agrees on the shared subset:
  Boolean, integer and text equality, literal contains, prefix and suffix, and
  membership, including empty membership. It does not claim Python accepts
  this wire API.
- Known-null equality differs: the pinned Python filter rejects None fields
  before its equality lookup.
- Numeric ordering, availability errors, graph quantifiers, validation on
  empty data and canonical names have no Python contract. They are marked
  unsupported there, and Perl fixtures cover them.

See [the fixtures](../conformance/where-v1.json) and
[the pin](../scripts/conformance-reference.json).
