# check-wakeup

Checks that a child exit wakes a blocked wait. It compiles a C interposer
that injects the exit at the wait, preloads it into a probe, and fails when
the probe reports `LOST_WAKEUP`, never reports the injected exit or runs past
2 seconds. A timeout kills the probe and every descendant through pidfds.

`make check-async-wakeup` and `make check-supervisor-wakeup` run it, and the
`scaffold` job runs both. It needs a C compiler; set `CC` to choose one.

`async` injects the exit at the IO::Async wait, and `supervisor` injects it at
the private supervisor's wait. The probes and interposers live in `async/` and
`supervisor/`:

```console
$ perl scripts/check-wakeup/check-wakeup.pl async
```

`--loop Poll` is the negative control. It must fail with `LOST_WAKEUP`,
because the rejected backend loses the wakeup:

```console
$ perl scripts/check-wakeup/check-wakeup.pl async --loop Poll
```

Test it:

```console
$ prove -Iscripts/lib scripts/check-wakeup/tests
```
