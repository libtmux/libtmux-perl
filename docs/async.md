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
