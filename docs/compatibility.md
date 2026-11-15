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

The oldest supported tmux crashes on an invalid layout name. The `select_layout`
wrapper rejects an unknown or ambiguous name that lacks a custom-layout
checksum prefix before dispatch; the raw `cmd` escape hatch keeps tmux's own
behavior.
