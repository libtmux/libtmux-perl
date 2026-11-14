---
title: Recover from failures
description: Recover from failures with the Perl libtmux distributions.
---

## Catch typed errors

Errors are `LibTmux::X` objects with readable stringification and fields such
as path, expected and received types, IDs, dispatch state and process result.
Catch them with Perl `try`/`catch` and `isa`. The last step of
[select.pl](../packages/core/examples/select.pl) catches an empty selection:

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

- `one_or_undef` handles absence and still rejects ambiguity.
- Acquisition errors never become empty selections.
- `Unloaded` differs from known null.
- Criteria validation runs before matching, even on empty input and in
  branches that later short-circuit.

## Report an invalid filter without losing its type

The [record-only example](../packages/core/examples/filters.pl) needs no tmux
server and rejects a text operand for an integer field:

<!-- example: packages/core/examples/filters.pl#invalid -->
```perl
try {
    LibTmux::Filter->new(
        entity => 'pane',
        where  => {width => {-gte => 'wide'}}
    );
    die 'invalid numeric operand was accepted';
}
catch ($error) {
    die $error unless $error isa LibTmux::X::InvalidFilter;
    say 'invalid operand at ', $error->path;
    say 'expected: ',          $error->expected;
}

```

- The path is `pane.where.width.-gte`, and `expected` names the safe decimal
  integer type.
- Pick recovery from the typed
  [InvalidFilter](https://libtmux.org/en/perl/latest/reference/libtmux-x/)
  and its fields; stringify only for a readable diagnostic.
- Unknown fields and malformed filters fail before any selection member is
  examined, even on an empty selection.

## Process results

- A result separates stdout, stderr, exit status, signal, timeout, spawn
  failure, output limit, cancellation and dispatch uncertainty.
- Lifecycle errors keep bounded partial results. An unknown status stays undef.
- Cancellation implies neither rollback nor non-execution.
- The isolated Linux supervisor reaps its owned process group. Intentionally
  detached daemons have separate ownership.
- A transport `timeout` bounds one command's execution loop, not supervisor
  setup or async queue waiting. A snapshot runs several commands, each with
  its own timeout, so the setting is not a total deadline.
- Cleanup has a separate allowance and continues after useful work expires.
  Async callers must drive the borrowed loop until the close observer
  succeeds; stopping the loop does not prove the processes exited.

## Descriptors and threads

- Owned supervisor and command branches close unrelated inherited descriptors,
  including native ones without close-on-exec. Your handles stay open.
- Only standard streams and the job's own protocol and cancellation pipes
  survive, so a new tmux daemon cannot keep an unrelated file or socket.
- This needs the Linux `/proc/self/fd` interface. A failure to enumerate or
  close descriptors prevents dispatch and surfaces as a typed transport or
  spawn error.
- Forking a host with native threads is unqualified.

## Creation receipts

`Creation` keeps a minimal, generation-scoped handle when a command succeeded
but the capture after it failed.

- Inspect `created` and `cause` before you decide on cleanup.
- Other fields on that handle are unloaded.
- Workspace uses it for owned rollback and records cleanup failures
  separately.

The [core quick start](../packages/core/examples/quickstart.pl) shows creation
receipts and exception-safe cleanup. The
[async consumer](../packages/async/examples/concurrent.pl) awaits executor
cleanup even after an operation fails. In both, a cleanup failure never
replaces the original error.
