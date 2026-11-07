# LibTmux::Workspace

Workspace distribution for libtmux, currently a package scaffold targeting
Perl 5.44. Its runtime dependencies are Perl and `LibTmux`. Workspace loading
and orchestration are not implemented yet.

The unpublished development version is `0.001_001`. This directory owns its
native distribution metadata. Workspace functionality uses public APIs from
the core and may consume other libtmux core distributions. The cores own tmux
protocol, targeting, transport, and resource lifetimes. MCP is excluded.

See the [repository contribution guide](https://github.com/libtmux/libtmux-perl/blob/master/.github/CONTRIBUTING.md)
for the shared development environment and configuration checks.
