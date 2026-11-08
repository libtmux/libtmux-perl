# ADR 0005: Supervisor signal readiness

- Status: Accepted
- Date: 2026-11-08
- Supersedes: ADR 0001's deferred Perl signal handlers inside the supervisor
- Scope: Shared ProcessJob supervisor, used by synchronous and async executors

## Decision

Receive `SIGCHLD`, `SIGINT` and `SIGTERM` through Linux `signalfd` in the
private supervisor. Block them and create the nonblocking, close-on-exec
descriptor before forking the command. Keep them blocked during supervision.
The kernel makes the descriptor readable when a signal is pending; readiness
does not depend on a Perl callback reaching an interpreter safe point.

The command closes that descriptor and restores its exact inherited mask
before execution. Check restoration and report failure before release. The
caller keeps its handlers and mask. Async retains its separate
[Ppoll contract](0004-atomic-async-child-exit.md) for observing supervisor exit.

`SIGCHLD` prompts the existing child and process-group reaping checks; signals
can coalesce, so one notification never means one child. INT and TERM request
cancellation. Signal-descriptor read failures enter the existing termination
and cleanup path. Cancellation, output bounds, command timeout and cleanup
allowances keep their existing meanings.

## Reproduced failure

At native revision `25b113e`, a real child exit injected after Perl's final
safe point and before `select` produces a false Timeout. The child has exited
with status zero and cleanup completes. Its deferred Perl handler cannot
write the self-pipe until the blocking wait returns. A longer timeout delays
the same failure.

The same revision's hosted tmux 3.6a graph test reports Timeout with successful
process status and captured output. The injected case reproduces that failure
signature; the hosted run has no syscall trace proving an identical cause.
Earlier successful runs do not resolve the demonstrated boundary defect.

Perl documents [deferred signal execution](https://perldoc.perl.org/5.44.0/perlipc#Deferred-Signals-(Safe-Signals)).
The Linux [`signalfd_read_iter` implementation](https://github.com/torvalds/linux/blob/v6.18/fs/signalfd.c#L201)
consumes pending signals through an ordinary descriptor. The qualified ABI
remains Linux x86_64 LP64:

- [`signalfd4`, syscall 289](https://github.com/torvalds/linux/blob/v6.18/arch/x86/entry/syscalls/syscall_64.tbl#L301).
- [64-signal kernel mask](https://github.com/torvalds/linux/blob/v6.18/arch/x86/include/asm/signal.h#L11), packed as one eight-byte word.
- [`signalfd_siginfo`](https://github.com/torvalds/linux/blob/v6.18/include/uapi/linux/signalfd.h#L20), a 128-byte record with a leading signal number.
- [`O_NONBLOCK` and `O_CLOEXEC`](https://github.com/torvalds/linux/blob/v6.18/include/uapi/asm-generic/fcntl.h#L37), used during descriptor creation.

No new runtime distribution or platform is selected. A kernel policy denying
descriptor creation fails before command dispatch. Supporting another ABI
requires qualifying its constants, record layout and lifecycle behavior.

## Alternatives

**Deferred handler and self-pipe.** Useful when the handler itself writes
before a wait. Perl defers that write, leaving the reproduced race. Rejected.

**Periodic polling or longer timeouts.** Adds latency and obscures a missing
notification. Neither establishes correct completion. Rejected.

**Unsafe Perl signal callbacks.** Running Perl operations inside a native
signal handler introduces interpreter reentrancy risks. Rejected.

**Raw atomic `pselect` or `ppoll`.** Can make mask changes and waiting atomic,
but requires additional descriptor-set and timeout ABI handling. `signalfd`
fits the existing IO::Select loop and handles descendant notifications.

**A pidfd for the direct command.** Reports that process's exit, but does not
cover adopted descendants. Acquiring it also follows program creation,
adding setup-failure cleanup. No advantage for this isolated supervisor.

## Verification and reconsideration

The author-only [boundary probe](../../../scripts/check-supervisor-wakeup.py)
releases a stopped child inside the native wait, observes exit with
`waitid(WNOWAIT)`, and leaves reaping to the supervisor. It requires the
injection marker, successful completion and verified cleanup. Its helper does
not ship in the distributions.

Retain [mask and transport tests](../../../packages/core/t/unit/transport.t),
[signal/descendant cancellation](../../../packages/core/t/integration/lifecycle.t),
[async parent-loss cleanup](../../../packages/async/t/integration/parent-loss.t),
descriptor isolation, installed consumers and the required tmux matrix.
Reconsider this adapter if the platform scope changes or the Perl wait
boundary gains equivalent guaranteed signal delivery.
