---
title: Install Perl packages
description: Install the independent Perl core, async, and workspace distributions.
---

Needs Perl 5.44 or newer, tmux 3.3a or newer, and Linux on x86-64, including
WSL. Install the packages you need from CPAN, or use a source checkout for
development. The [documentation homepage](https://libtmux.org/en/perl/) links
the guides and [API reference](https://libtmux.org/en/perl/latest/reference/).

## Install from CPAN

Install [Perl](https://www.perl.org/get.html) and
[cpm](https://github.com/skaji/cpm#installation), then use one interpreter and
installation prefix for every package.

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

- Companions declare their core dependency; the installer adds it.
- Core and workspace use only the Perl standard library at runtime.
- Async adds Future, IO::Async, IO::Async::Loop::Ppoll and IO::Ppoll. IO::Ppoll
  needs a C compiler.
- Programs that use the packages need no author tools or Python.

The `0.x` API can change between releases. Read each distribution's `Changes`
file before upgrading, and pin versions in applications.

## Prepare a source checkout

Install [Perl](https://www.perl.org/get.html) and
[cpm](https://github.com/skaji/cpm#installation). With mise installed, the
checkout's `.tool-versions` selects its Perl. Clone the repository:

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

The [contributor setup](../.github/CONTRIBUTING.md#environment) adds a
hash-verified standalone cpm installer and an isolated author environment.

## Install from the source checkout

With Perl and cpm on `PATH`, install core from the repository root:

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
session, splits and resizes a pane, adds a window, captures the graph, and
removes the session. It runs its own tmux server:

```console
$ perl packages/core/examples/quickstart.pl
```

```text
editor: 2 panes
logs: 1 pane
side pane: 20 columns
```

The [examples index](../examples/README.md) lists filtering, concurrent
operations, workspace loading and the author programs.

Installed API documentation uses POD:

```console
$ perldoc LibTmux::Server
```

If something fails:

- **tmux is missing.** Install it, or pass a socket path and the tmux path as
  the example's two arguments.
- **`NoServer` from `snapshot`.** The socket has no daemon; create a session
  with `new_session` first.
- **A session name conflicts.** That is an error; an example never deletes an
  existing session.
