<!-- libtmux-logo -->
<div align="center">
  <picture>
    <source srcset="docs/assets/logo.svg" type="image/svg+xml">
    <img src="docs/assets/logo-512.png" width="128" height="128" alt="libtmux for Perl">
  </picture>
</div>
<!-- /libtmux-logo -->

<div align="center">

# libtmux for Perl

</div>

A Perl port of libtmux, currently at the package scaffold stage. Core and
workspace distribution metadata, formatting, and bootstrap CI target Perl 5.44.
The client API, workspace implementation, and runtime tests are not implemented.

| Distribution | Location | Role |
| --- | --- | --- |
| `LibTmux` | [packages/core](packages/core) | Core tmux library; standard-library-first runtime. |
| `LibTmux-Workspace` | [packages/workspace](packages/workspace) | Workspace configuration and orchestration using core APIs. |

MCP is excluded from this port. Runtime code should use Perl's standard
library where possible; build and author tools have separate dependencies.

See [contributing](.github/CONTRIBUTING.md) for the development environment
and [Perl tooling choices](.github/PERL.md) for the source-backed packaging
decisions. [Branding assets](docs/branding.md) covers logos and social cards.

Both distributions use unpublished development version `0.001_001`.
Installation and usage instructions will accompany working APIs.
