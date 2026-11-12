---
title: Install from source
description: Install the independent Perl core, async, and workspace distributions.
---

Use Perl 5.44 and tmux 3.3a–3.8 on Linux x86_64 LP64, including WSL. The
packages are not published on CPAN. Start from a source checkout and install
core before workspace or optional async.

## Prepare Perl and get the source

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

## Install the packages you use

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

Core and workspace use the Perl standard library at runtime. Async adds
Future, IO::Async, IO::Async::Loop::Ppoll, and IO::Ppoll; the latter includes
an XS extension and requires a C compiler. Configure, test, and author tools
are separate dependencies. Other loop backends and Linux ABIs are unsupported.

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
