---
title: Optional Future execution
description: Optional Future execution with the Perl libtmux distributions.
---

Install the separate LibTmux-Async distribution to use an injected
[`IO::Async::Loop::Ppoll`](https://metacpan.org/pod/IO::Async::Loop::Ppoll) and a Future-returning
Server facade. Core and workspace do not load this dependency. Caller-side
Future::AsyncAwait syntax is optional.

Construct `IO::Async::Loop::Ppoll->new` explicitly. Installing it does not
force `IO::Async::Loop->new` to select it. Other backends are rejected before
dispatch. The async distribution requires Ppoll 0.10 and IO::Ppoll 0.14 or
newer; IO::Ppoll supplies the native atomic-wait extension. Core and workspace
remain standard-library runtime distributions.

The caller owns and drives the loop. Each operation resolves to one value;
void methods yield one undef. Command preparation, framing, identity, and
parsing are shared with core. Captured selections stay synchronous and local.

Transport bounds concurrent jobs and pending requests. Queue overflow fails
before dispatch. Cancellation suppresses subsequent continuations and requests
cleanup; it cannot undo accepted effects. Close cancels queued/running work,
rejects new admissions, and returns a fresh cleanup observer. Only successful
`is_done` proves cleanup. Cancelling that observer cannot cancel private cleanup.
Keep driving the borrowed loop through shutdown; closing preserves the server.

Ppoll owns the host's signal-watching policy. It blocks watched signals outside
its atomic wait and can retain its shared `SIGCHLD` watch after facade close.
Do not change its backend or wait mask while requests or cleanup remain active.
Async children unblock only `SIGCHLD`, so a newly started tmux daemon can reap
its panes; other mask bits remain unchanged in the child. Synchronous core
execution retains the caller's mask. Starting a daemon through synchronous
core while the host blocks `SIGCHLD` also passes that blocked mask to the daemon.
See [ADR 0004](dev/adr/0004-atomic-async-child-exit.md) for the failure evidence
and the alternatives considered.

The default bounds are four active jobs and 64 queued requests. A command's
timeout starts in its execution loop, after queue waiting and supervisor setup.
It does not bound the total time of a multi-command operation. Cleanup has a
separate allowance; see [failure recovery](errors.md).

Persistent control, streaming subscriptions, and tmux command lists are deferred.
Ordered batch requests are independent submissions with individual attribution.

## Run concurrent operations

After installing core and async, run the standalone packaged program:

```console
$ perl packages/async/examples/concurrent.pl "${TMPDIR:-/tmp}/libtmux-perl-async-$$.sock"
```

It creates and removes its own session and preserves any other sessions on that
socket. During its live scope it starts independent operations before awaiting
both results:

<!-- example: packages/async/examples/concurrent.pl#concurrent -->
```perl
my $capture = $server->snapshot;
my $version = $server->cmd('display-message', '-p', '#{version}');
$loop->await(Future->needs_all($capture, $version));
my $snapshot = $capture->get;
my $panes    = $snapshot->sessions->one({name => 'perl-async'})
    ->window_links->one->window->panes->where({active => true});
say 'async active panes: ', $panes->count;
say 'tmux version: ',       $version->get->stdout;

```

Selections returned by the capture are ordinary synchronous core objects.
The same program also checks ordered independent requests:

<!-- example: packages/async/examples/concurrent.pl#batch -->
```perl
my $batch = $server->batch(
    [
        ['display-message', '-p', 'first'],
        ['display-message', '-p', 'second'],
    ]
);
$loop->await($batch);
my $results = $batch->get;
for my $entry ($results->@*) {
    die $entry->{error} if defined $entry->{error};
    print $entry->{result}->stdout;
}

```

The [complete source](../packages/async/examples/concurrent.pl) owns session
cleanup, preserves primary errors, and awaits executor close. It uses installed
packages without Python or a repository fixture.

## Failure and cancellation

[async-lifecycle.pl](../examples/async-lifecycle.pl) is a standalone downstream
program. It imports only installed distributions and Perl core modules; it
does not use the repository fixture. Supply the socket path of an existing
tmux server. The program observes that server and closes only its executor.
`--fail` exercises a rejected native command; `--cancel` cancels the capture.

The program always drives cleanup to completion. An operation failure remains
the primary exception, while a secondary cleanup failure is reported
separately. Cancellation is checked before `get`; it is readiness without a
result and does not prove cleanup. A successful close observer supplies that
proof. The repository example runner exercises all three paths against an
owned server, including with an isolated installed package prefix.

<!-- example: async-lifecycle.pl -->
```perl
use v5.44;
use Getopt::Long qw(GetOptions);
use IO::Async::Loop::Ppoll;
use LibTmux::Async::Server;

my ($socket, $executable, $fail, $cancel, $help);
GetOptions(
    'socket=s' => \$socket,
    'tmux=s'   => \$executable,
    'fail'     => \$fail,
    'cancel'   => \$cancel,
    'help'     => \$help,
) or die "Use --help for arguments\n";
if ($help) {
    say
'Usage: perl async-lifecycle.pl --socket PATH [--tmux EXE] [--fail | --cancel]';
    say
'Observe an existing server and close the executor without destroying that server.';
    exit 0;
}
die "Supply --socket PATH; --fail and --cancel are mutually exclusive\n"
    if !defined($socket) || @ARGV || ($fail && $cancel);

my $loop   = IO::Async::Loop::Ppoll->new;
my $server = LibTmux::Async::Server->new(
    loop        => $loop,
    socket_path => $socket,
    defined($executable) ? (executable => $executable) : (),
);
my ($operation_error, $cleanup_error);
try {
    my $operation =
          $fail
        ? $server->cmd('libtmux-example-invalid-command')
        : $server->snapshot;
    $operation->cancel if $cancel;
    $loop->await($operation);
    if ($operation->is_cancelled) { say 'capture cancelled' }
    else {
        my $snapshot = $operation->get;
        say 'captured panes: ' . $snapshot->panes->count;
    }
}
catch ($error) { $operation_error = $error }

try {
    my $cleanup = $server->close;
    $loop->await($cleanup);
    $cleanup->get;
    say 'executor cleanup: complete';
}
catch ($error) { $cleanup_error = $error }

if (defined $operation_error) {
    warn "executor cleanup also failed: $cleanup_error\n"
        if defined $cleanup_error;
    die $operation_error;
}
die $cleanup_error if defined $cleanup_error;
```
