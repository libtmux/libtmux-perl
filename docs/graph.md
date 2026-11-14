---
title: Snapshots and linked-window identity
description: Snapshots and linked-window identity with the Perl libtmux distributions.
---

## Observe a rename without rewriting history

[graph.pl](../packages/core/examples/graph.pl) runs its own server. It keeps
the `logs` window from one capture, renames the live window, and compares both:

<!-- example: packages/core/examples/graph.pl -->
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
        name    => 'perl-graph',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $window = $session->window_links->one->window;
    $server->rename_window(window => $window, name => 'logs');
    my $before = $server->snapshot->window_by_id($window->id);
    $server->rename_window(window => $window, name => 'build');
    say 'captured name: ', $before->name;
    say 'live name: ',     $server->snapshot->window_by_id($window->id)->name;
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
```

It prints `captured name: logs` and `live name: build`. The old handle still
says `logs`; a new capture says `build`.

## Identity and links

- A physical window can appear at several indexes and in several sessions.
- `WindowLink` owns the session-relative index and active state.
- A pane's `window` always returns the physical window.
- Snapshot `windows` and `panes` hold each physical identity once. Raw
  `listings` keep contextual rows and repeats.
- Selections keep their input order and duplicates; two occurrences of one
  identity make `one` ambiguous.
- IDs stay strings. Write session IDs as `'$1'` so Perl does not interpolate.
- Identity is server, daemon generation, kind and ID. `socket_path` names the
  server; `pid` and start time name the generation.
- A captured handle refuses to retarget after a restart. A raw ID string
  addresses the current resource and carries no history.

## Combine captures

- Selections may combine captures from one server generation. Each handle
  keeps its own graph, and combining does not reconcile capture times.
- Mixing servers or daemon generations is an `InvalidSelection` error.
- Use one snapshot when a query needs one capture interval.
- Capture start and end describe an observation. Resource identity alone does
  not.

## Memory and loading

- The store owns scalar records and ID adjacency; handles hold the store, and
  the store does not hold handles. One retained handle can retain the graph.
- `to_record` exports detached scalar data.
- To-many accessors scan related records, so repeated traversal repeats work.
- Acquisition records its start, end and completeness. A strict live capture
  rejects missing topology.
- An unloaded field or relation throws when needed; null and a loaded-empty
  relation stay distinct.
- Accessors return independent membership arrays. Queries do not mutate, but
  native arrays stay mutable and every library query validates their members.
