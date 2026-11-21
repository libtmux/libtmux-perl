---
title: Linux compatibility and qualification
description: Linux compatibility and qualification with the Perl libtmux distributions.
---

What is supported:

- **Perl 5.44 or newer.**
- **tmux 3.3a or newer**, including every release after it. Plain tmux 3.3 is
  below the floor.
- **Linux on x86-64, including WSL.** Other systems and ABIs are unqualified;
  the supervisor refuses an unsupported ABI before dispatch.

What CI runs:

- The latest stable Perl, against the oldest and newest supported tmux.
- Releases in between are supported without cells of their own.
- A missing or skipped cell counts as unverified.

CI builds each tmux release with the shared
[build-tmux action](https://github.com/libtmux/.github/tree/30f81842b1e639ea4e25f93f1f2543504178e228/actions/build-tmux),
which checks the official release archive against a pinned SHA-256 before it
builds. The check compares each binary's reported version with its release.

Run the compatibility check:

```console
$ mise exec -- make compatibility
```

## Check feature support

[`Server->capabilities`](../packages/core/lib/LibTmux/Server.pm) returns a
[`LibTmux::Capabilities`](../packages/core/lib/LibTmux/Capabilities.pm) report
from the selected running daemon. The
[complete core example](../packages/core/examples/capabilities.pl) creates
and removes its own session. The
[Async example](../packages/async/examples/concurrent.pl) obtains the same
report through a Future and awaits executor cleanup.

- The daemon's version decides support. An executable's `tmux -V` banner does
  not identify a running daemon selected through its socket.
- `cursor-shape` requires tmux 3.6 and describes the existing captured
  `Pane->cursor_shape` field. On an older supported daemon, that reader throws
  `LibTmux::X::Unsupported`; it does not return an empty supported value.
- `status('cursor-shape')` includes `since`, `supported`, handling/error,
  affected APIs and native command metadata. `supports` returns its Boolean.
  Unknown IDs throw `LibTmux::X::InvalidArgument`.
- Every metadata/identity container returned by the report is a detached
  recursive copy. A saved report performs no later I/O and remains historical.
  A later call may observe a replacement daemon through the same settings.
- Discovery cannot start a daemon, fire user hooks or create tmux resources.
  Keep its native `run-shel` bootstrap spelling unaliased throughout the call.
  Redefining that spelling can execute arbitrary server code; ordinary
  `run-shell` aliases do not replace it.
  It uses the smaller of configured limits and 750 milliseconds/16 KiB.
  Cold/dead endpoints fail with `NoServer`; unknown or below-floor releases
  fail with `Unsupported`; malformed receipts fail with `Codec`.

The registry covers implemented optional gates, with the 3.3a support floor
recorded separately. [capabilities.json](../capabilities.json) is generated
from that registry. It registers no workaround or managed Program support.
Core listing, retained readers, query lowering and field documentation use
the same cursor-shape threshold.

Release comparisons now require a complete `X.Y`, lowercase patch letter,
`next-X.Y` or `X.Y-rc[N]` spelling. Development and candidate releases precede
their final release; patch letters follow it. Banners, trailing whitespace,
unrelated strings and mixed suffixes are rejected. When calling `at_least`
with command output, remove its line ending first.

The oldest supported tmux crashes on an invalid layout name. The `select_layout`
wrapper rejects an unknown or ambiguous name that lacks a custom-layout
checksum prefix before dispatch; the raw `cmd` escape hatch keeps tmux's own
behavior.
