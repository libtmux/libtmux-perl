---
title: Install Perl packages
description: Install the independent Perl core, async, and workspace distributions.
---

Use Perl 5.44 and tmux 3.3a–3.8 on Linux x86_64 LP64, including WSL. Install
the packages you need from CPAN, or use a source checkout for development.
The [documentation homepage](https://libtmux.org/en/perl/) links the guides
and [API reference](https://libtmux.org/en/perl/latest/reference/).

## Install from CPAN

Install [Perl](https://www.perl.org/get.html) and
[cpm](https://github.com/skaji/cpm#installation), then keep the same interpreter
and installation prefix for all selected packages.

Install [LibTmux](https://metacpan.org/dist/LibTmux) for commands, snapshots,
and filtering:

```console
$ cpm install \
    --global \
    LibTmux
```

Add [LibTmux-Workspace](https://metacpan.org/dist/LibTmux-Workspace) for the
JSON library and packaged `libtmux-workspace` CLI:

```console
$ cpm install \
    --global \
    LibTmux::Workspace
```

Add [LibTmux-Async](https://metacpan.org/dist/LibTmux-Async) for Future-returning
operations:

```console
$ cpm install \
    --global \
    LibTmux::Async
```

The companions declare their core dependency; the installer resolves it
automatically. Core and workspace use the Perl standard library at runtime.
Async adds Future, IO::Async, IO::Async::Loop::Ppoll, and IO::Ppoll; the latter
includes an XS extension and requires a C compiler. Configure and test
dependencies are declared separately and resolved by the installer. Consumer
programs do not require the repository's author tools or Python. Other loop
backends and Linux ABIs are unsupported.

The `0.x` API can change between releases. Consult each distribution's
`Changes` file before upgrading and pin versions in applications that need a
fixed API.

## Prepare a source checkout

Install [Perl](https://www.perl.org/get.html) and
[cpm](https://github.com/skaji/cpm#installation). With mise installed, this
checkout's `.tool-versions` selects Perl 5.44.0. Clone the repository:

```console
$ git clone https://github.com/libtmux/libtmux-perl.git
```

```console
$ cd libtmux-perl
```

If the pinned interpreter is not installed:

```console
$ mise install
```

Check the interpreter selected for installation and execution:

```console
$ mise exec -- perl -v
```

The [contributor setup](../.github/CONTRIBUTING.md#environment) supplies a
hash-verified standalone cpm installer and an isolated author environment.
Consumer programs do not require those author tools or Python. Keep the same
Perl interpreter and installation prefix for all selected distributions.

## Install from the source checkout

With Perl 5.44 and cpm on `PATH`, install core from the repository root:

```console
$ cpm install \
    --global \
    ./packages/core
```

Add workspace for the JSON library and packaged `libtmux-workspace` command:

```console
$ cpm install \
    --global \
    ./packages/workspace
```

Add async for Future-returning operations:

```console
$ cpm install \
    --global \
    ./packages/async
```

## Run a first program

The [core quick start](../packages/core/examples/quickstart.pl) creates its own
session, splits a pane, adds a window, captures the graph, and removes that
session. It starts tmux if the explicit socket is unused:

```console
$ perl packages/core/examples/quickstart.pl "${TMPDIR:-/tmp}/libtmux-perl-$$.sock"
```

```text
editor: 2 panes
logs: 1 pane
```

All package examples import installed public modules. No source-tree
`PERL5LIB`, repository fixture, Python, or syscall boilerplate is required.
Use [the examples index](../examples/README.md) to choose filtering, concurrent
operations, workspace loading, or the author qualification programs.

Installed API documentation uses POD:

```console
$ perldoc LibTmux::Server
```

For a missing executable, install tmux or pass its path as the example's second
argument. `NoServer` on `snapshot` means the selected socket has no daemon;
create a session with `new_session` first. A conflicting example session name
is an error and never grants permission to delete that existing session.
