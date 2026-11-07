---
title: Install from source
description: Install from source with the Perl libtmux distributions.
---

These distributions are unpublished. Use Perl 5.44.0 and install core before
workspace or optional async. Use the repository's pinned cpm author setup,
or an existing cpm installation. From the repository root:

```console
$ cpm install \
    --global \
    ./packages/core
```

```console
$ cpm install \
    --global \
    ./packages/workspace
```

```console
$ cpm install \
    --global \
    ./packages/async
```

Core and workspace need only the Perl standard library at runtime. Async
adds Future and IO::Async. Configure/test/develop requirements remain separate.
To inspect installed documentation:

```console
$ perldoc LibTmux::Server
```

The [contributor guide](../.github/CONTRIBUTING.md) documents pinned local
provisioning, archive builds, and isolated installed-consumer verification.
No PAUSE upload, tag, or release is implied by source installation.
