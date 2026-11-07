---
title: Optional Future execution
description: Optional Future execution with the Perl libtmux distributions.
---

Install the separate LibTmux-Async distribution to use an injected
`IO::Async::Loop` and Future-returning Server facade. Core and workspace do not
load this dependency. Caller-side Future::AsyncAwait syntax is optional.

The caller owns and drives the loop. Each operation resolves to one value;
void methods yield one undef. Command preparation, framing, identity, and
parsing are shared with core. Captured selections stay synchronous and local.

Transport bounds concurrent jobs and pending requests. Queue overflow fails
before dispatch. Cancellation suppresses subsequent continuations and requests
cleanup; it cannot undo accepted effects. Close cancels queued/running work,
rejects new admissions, and returns a fresh cleanup observer. Only successful
`is_done` proves cleanup. Cancelling that observer cannot cancel private cleanup.
Keep driving the borrowed loop through shutdown; closing preserves the server.

Persistent control, streaming subscriptions, and tmux command lists are deferred.
Ordered batch requests are independent submissions with individual attribution.
