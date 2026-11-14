---
title: Optional Future execution
description: Optional Future execution with the Perl libtmux distributions.
---

## Run concurrent operations

Install the separate LibTmux-Async distribution for an injected
[`IO::Async::Loop::Ppoll`](https://metacpan.org/pod/IO::Async::Loop::Ppoll) and
a Future-returning Server facade. Core and workspace never load it.

After installing core and async, run the packaged program. It runs its own
tmux server and removes it on exit:

```console
$ perl packages/async/examples/concurrent.pl
```

<!-- example: packages/async/examples/concurrent.pl -->
```perl
# example: begin connect
use v5.44;
use File::Temp ();
use IO::Async::Loop::Ppoll;
use Future;
use LibTmux::Async::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $socket  = shift @ARGV // "$private/tmux.sock";
my $tmux    = shift @ARGV // 'tmux';

my $loop   = IO::Async::Loop::Ppoll->new;
my $server = LibTmux::Async::Server->new(
    loop           => $loop,
    socket_path    => $socket,
    executable     => $tmux,
    config_file    => '/dev/null',
    max_concurrent => 2,
    max_queue      => 8,
);

# example: end connect
my ($session, $failure);
try {
    my $created = $server->new_session(
        name    => 'perl-async',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $loop->await($created);
    $session = $created->get;

    # example: begin concurrent
    my $capture = $server->snapshot;
    my $version = $server->cmd('display-message', '-p', '#{version}');
    $loop->await(Future->needs_all($capture, $version));
    my $snapshot = $capture->get;
    my $panes    = $snapshot->sessions->one({name => 'perl-async'})
        ->window_links->one->window->panes->where({active => true});
    say 'async active panes: ', $panes->count;
    say 'tmux version: ',       $version->get->stdout;

    # example: end concurrent
    die 'async session missing pane' unless $panes->count == 1;

    # example: begin batch
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

    # example: end batch
    die 'batch order changed'
        unless $results->[0]{result}->stdout eq "first\n"
        && $results->[1]{result}->stdout eq "second\n";
}
catch ($error) {
    $failure = $error;
    $session //= $error->created if $error isa LibTmux::X::Creation;
}
if ($session) {
    try {
        my $removed = $server->kill_session(session => $session);
        $loop->await($removed);
        $removed->get;
    }
    catch ($cleanup) {
        warn "session cleanup failed: $cleanup\n";
        $failure //= $cleanup;
    }
}

# example: begin close
my $closed = $server->close;
$loop->await($closed);
try { $closed->get }
catch ($cleanup) {
    warn "executor cleanup failed: $cleanup\n";
    $failure //= $cleanup;
}
die $failure if defined $failure;
say 'async operations and cleanup: ok';

# example: end close
```

It prints the active pane count, the tmux version, `first` then `second`, and
`async operations and cleanup: ok`.

- It starts independent operations and awaits both results together.
- Captured selections are ordinary synchronous core objects.
- `batch` keeps request order and returns one `{result, error}` entry per
  independent command.
- It owns session cleanup, keeps the primary error, and awaits executor close.

## The loop and its limits

- Construct `IO::Async::Loop::Ppoll->new` yourself. Installing it does not make
  `IO::Async::Loop->new` pick it, and other backends are rejected before
  dispatch.
- Async needs IO::Async::Loop::Ppoll 0.10 or newer and IO::Ppoll 0.14 or newer.
  IO::Ppoll supplies the native atomic wait.
- `Future::AsyncAwait` is optional caller syntax.
- The caller owns and drives the loop. Each operation resolves to one value, and
  a void method yields one undef.
- Preparation, framing, identity and parsing are shared with core.
- The default bounds are four active jobs and 64 queued requests. Queue overflow
  fails before dispatch.
- A command's timeout starts after queue waiting and supervisor setup. It does
  not bound a multi-command operation. Cleanup has its own allowance; see
  [failure recovery](errors.md).

## Cancel and close

- Cancelling suppresses later continuations and requests cleanup. It cannot
  undo accepted effects.
- `close` cancels queued and running work, rejects new requests, and returns a
  fresh cleanup observer.
- Only a successful `is_done` on that observer proves cleanup. Cancelling the
  observer cannot cancel the private cleanup.
- Keep driving the borrowed loop through shutdown. Closing preserves the tmux
  server.

## Signals

- Ppoll owns the host's signal-watching policy. It blocks watched signals
  outside its atomic wait and may keep its shared `SIGCHLD` watch after close.
- Do not change its backend or wait mask while requests or cleanup are active.
- Async children unblock only `SIGCHLD`, so a new tmux daemon can reap its
  panes. Other mask bits stay as they were.
- Synchronous core keeps the caller's mask. A daemon started through it while
  the host blocks `SIGCHLD` inherits that block.

See [ADR 0004](dev/adr/0004-atomic-async-child-exit.md) for the failure and the
alternatives.

Persistent control, streaming subscriptions and tmux command lists are
deferred. Ordered batch requests are independent submissions with their own
results.

## Failure and cancellation

[async-lifecycle.pl](../examples/async-lifecycle.pl) is a standalone downstream
program that imports only installed distributions and core Perl modules.
Supply the socket path of an existing tmux server: it observes that server and
closes only its executor.

- `--fail` sends a command tmux rejects; `--cancel` cancels the capture.
- An operation failure stays the primary exception; a cleanup failure is
  reported separately.
- A cancelled operation is ready without a result and does not prove cleanup.
  A successful close observer does.
- The repository example runner exercises all three paths against an owned
  server, including with an isolated installed package prefix.

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
