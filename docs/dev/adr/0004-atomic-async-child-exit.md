# ADR 0004: Atomic async child-exit notification

- Status: Accepted
- Date: 2026-11-08
- Supersedes: ADR 0001's acceptance of an arbitrary IO::Async loop
- Scope: Optional `LibTmux-Async`; synchronous core signal behavior is unchanged

## Decision

Use a caller-owned `IO::Async::Loop::Ppoll` backed by `IO::Ppoll`. Require
Ppoll 0.10 and IO::Ppoll 0.14 as minimum runtime versions in the async
distribution. Construct the loop explicitly:

```perl
use IO::Async::Loop::Ppoll;
use LibTmux::Async::Server;

my $loop = IO::Async::Loop::Ppoll->new;
my $server = LibTmux::Async::Server->new(
    loop => $loop, socket_name => 'work',
);
```

The supplied loop and poll object must have those exact classes, and the
poll object's wait mask must permit `SIGCHLD`. Other configurations fail with
`LibTmux::X::Unsupported` before dispatch. Check construction, admission, and
launch; do not replace the caller's loop or change `IO_ASYNC_LOOP`.

The isolated async child unblocks only `SIGCHLD`, before ProcessJob creates
the command. Other mask bits remain unchanged in the child. Preparation runs
inside ProcessJob's typed-error boundary: failure means no command was
dispatched and no command needs cleanup. Completion still requires the
supervisor's result EOF and the loop's matching exit callback. The preparation
callback is a private adapter seam, not a caller-configurable hook.

## Observed failure

The original async transport could receive the complete result and EOF, then
wait indefinitely for an already-exited supervisor. A captured run showed
that supervisor as a zombie; an unrelated signal let the loop finish.

Perl's deferred signal handler can remain pending when a signal arrives after
the interpreter's final safe point but before the underlying blocking
[`poll` call](https://github.com/Perl/perl5/blob/v5.44.0/dist/IO/IO.xs#L220).
IO::Async 0.805's Poll backend uses that call and a Perl signal handler writing
to a self-pipe. The pending handler has not yet written the wakeup byte.

An author-only interposer reproduces this ordering with a real gated child:
release it, observe its exit with `waitid(WNOWAIT)`, then enter the native wait
without returning to Perl. Poll needs the probe's 200ms fallback and fails;
Ppoll returns on the pending signal and leaves reaping to IO::Async. The probe
does not add a timer to the product or claim that the child-exit signal alone
proves program cleanup.

Simply substituting Ppoll exposes another failure. Ppoll blocks watched
signals outside its atomic wait, and IO::Async's fork helper resets handlers
without resetting that mask. A newly started tmux daemon inherits blocked
`SIGCHLD` and cannot observe its final pane exiting. The async-only child
preparation above corrects that inheritance.

## Dependency and ownership contracts

[`Ppoll::loop_once`](https://metacpan.org/release/PEVANS/IO-Async-Loop-Ppoll-0.10/view/lib/IO/Async/Loop/Ppoll.pm#loop_once)
uses an atomic wait-mask switch, then dispatches pending signals and I/O.
[`IO::Ppoll::sigmask`](https://metacpan.org/release/PEVANS/IO-Ppoll-0.14/view/lib/IO/Ppoll.pm#sigmask)
documents the mask applied during that wait. IO::Ppoll includes an XS
extension. These are two additional non-core runtime distributions, confined
to async; root author tooling also installs them for qualification.

Ppoll's public constructor accepts a supplied poll object. It has no public
accessor for that object, so validation reads its `poll` member as a narrow
compatibility seam tied to the reviewed 0.10 implementation. The check must
fail safely if a later release changes that layout. Altering the loop, its
methods, or its wait mask while jobs or cleanup remain active is unsupported.

The caller owns Ppoll's signal policy. IO::Async retains its shared child
watch after individual jobs finish; `SIGCHLD` may remain blocked outside the
wait after LibTmux closes. Facade close must not restore a host mask or detach
another component's watchers. The backend's eventual destruction controls its
signal restoration. Applications that deliberately start synchronous commands
while blocking `SIGCHLD` still pass that mask to those commands.

`IO::Async::Loop->new` is insufficient: it can reuse a cached loop, honor an
environment preference, or choose Epoll ahead of Ppoll. No implicit backend
selection is part of this contract. The loop continues to own supervisor
reaping; LibTmux does not compete with its waitpid calls.

## Alternatives

- **Generic Poll plus a timeout:** a retry or periodic wakeup conceals the
  missing notification and adds latency. Rejected.
- **Ppoll without child preparation:** fixes the wait race but fails the real
  daemon-exit probe. Rejected.
- **Epoll 0.23:** also uses atomic signal waiting, but adds Linux::Epoll and
  Struct::Dumb alongside its loop distribution. Its post-fork repair rebuilds
  descriptor registrations, not inherited signal masks. No measured workload
  requires this additional backend; deferred.
- **Poll plus pidfd wakeup:** the normal injected case passes without stealing
  reaping. However, pidfd acquisition or watcher setup can fail after fork.
  Preflight and descriptor reservation do not prove nonblocking cleanup in
  that path. This adds kernel capability and ownership contracts; deferred.
- **Replacing the process supervisor:** atomic loop waiting and process-group
  ownership solve different problems. This defect does not justify replacing
  the shared ProcessJob protocol.

## Verification and reconsideration

[`check-async-wakeup.py`](../../../scripts/check-async-wakeup.py) is an outer
check with a C compiler; its helper is excluded from native distributions.
[`signals.t`](../../../packages/async/t/unit/signals.t) checks backend refusal,
child masks, unchanged host masks, typed preparation failure and cleanup.
[`daemon-exit.t`](../../../packages/async/t/integration/daemon-exit.t) creates a
daemon asynchronously, closes the executor, releases its final pane, and
verifies daemon exit. Existing cancellation, parent-loss, installed-consumer,
and synchronous mask tests remain required.

Reconsider the backend when IO::Async supplies equivalent atomic exit
notification without this dependency, when its private layout changes, or
when an external caller requires another loop. Qualify failure paths and
daemon behavior before expanding the accepted classes.
