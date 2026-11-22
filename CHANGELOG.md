# Changelog

Each CPAN distribution records its caller-visible changes in its native
`Changes` file:

- [`LibTmux`](packages/core/Changes): core `Server` commands, `Snapshot`
  graphs, and `Selection` and `Filter` queries.
- [`LibTmux-Async`](packages/async/Changes): optional Future execution on a
  caller-owned `IO::Async::Loop::Ppoll`.
- [`LibTmux-Workspace`](packages/workspace/Changes): `libtmux.workspace/v1`
  JSON planning, loading, and the `libtmux-workspace` CLI.

Releases use decimal Perl versions (`0.002`, `0.003`, ...) tagged `v<version>`
across all three distributions. The `0.x` API can change between releases; pin
a version in applications and read the distribution `Changes` files before
upgrading.

## Unreleased

- [`LibTmux`](packages/core/Changes): add "What is on here" capability
  directories to the `LibTmux::Server`, `LibTmux::Session`, `LibTmux::Window`,
  and `LibTmux::Pane` POD.

## 0.003 - 2026-11-13

`LibTmux`, `LibTmux-Async`, and `LibTmux-Workspace` 0.003 link CPAN
installation, native POD, and the shared `libtmux.org` API reference, and set
the documentation homepage in distribution metadata. See
[`packages/core/Changes`](packages/core/Changes),
[`packages/async/Changes`](packages/async/Changes), and
[`packages/workspace/Changes`](packages/workspace/Changes).

## 0.002

Initial CPAN release of [`LibTmux`](packages/core/Changes),
[`LibTmux-Async`](packages/async/Changes), and
[`LibTmux-Workspace`](packages/workspace/Changes) for Perl 5.44 on Linux
x86-64 with tmux 3.3a–3.8.
