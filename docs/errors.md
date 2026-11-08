---
title: Recover from failures
description: Recover from failures with the Perl libtmux distributions.
---

Errors are typed `LibTmux::X` objects with readable stringification and
applicable fields such as path, expected/received types, IDs, dispatch state,
and process result. Catch objects with stable Perl try/catch and isa:

```perl
try {
    my $only = $snapshot->panes->one({ active => true });
}
catch ($error) {
    if ($error isa LibTmux::X::NoMatch) {
        say 'No active pane in this captured selection';
    }
    else {
        die $error;
    }
}
```

`one_or_undef` handles absence and still rejects ambiguity. Acquisition errors
never become empty selections. `Unloaded` differs from known null. Complete
criteria validation runs before matching, including on empty input and in
branches that later short-circuit.

Process results distinguish stdout, stderr, exit status, signal, timeout,
spawn failure, output limit, cancellation, and dispatch uncertainty. Lifecycle
errors retain bounded partial results; unknown status remains undef.
Cancellation does not imply rollback or nonexecution. The isolated Linux
supervisor reaps its owned process group; intentionally detached daemons have
separate ownership. The current verified ABI is x86_64 LP64.

Owned supervisor and command branches close unrelated inherited descriptors,
including native descriptors without close-on-exec. The caller's handles stay
open. Only standard streams and the job's explicit protocol/cancellation pipes
survive where needed; a newly started tmux daemon cannot retain an unrelated
caller file or socket. This requires the Linux `/proc/self/fd` interface.
Descriptor enumeration/closure failure prevents dispatch and remains a typed
transport or spawn failure. Forking a host with native threads is unqualified.

Transport `timeout` bounds one command's execution loop, excluding supervisor
setup and async queue waiting. A snapshot runs several commands, each with its
own timeout; this setting is not a total snapshot deadline. Cleanup has a
separate allowance and continues after useful work expires. Async callers must
drive the borrowed loop until successful close-observer completion. Cancelling
the observer or stopping the loop does not prove that processes have exited.

`Creation` preserves a generation-scoped minimal created handle when the
command succeeded but subsequent capture failed. Inspect `created` and `cause`
before deciding cleanup. Other fields on that handle are unloaded. Workspace
uses this evidence for owned rollback and records cleanup failures separately.
