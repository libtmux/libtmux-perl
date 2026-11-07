# Agent instructions

This repository contains the Perl core, optional async transport, and workspace
distributions for libtmux. Preserve their independent native package boundaries.

## Product and dependency policy

- The products are core in `packages/core`, optional async in `packages/async`,
  and workspace in `packages/workspace`. Async owns its Future/IO::Async runtime
  dependencies; core and workspace remain usable without them. MCP is excluded.
  Preserve this scope in architecture plans and goal epics.
- Prefer the Perl standard library and stable Perl 5.44 features at runtime.
  Add a non-core dependency only for a verified need and document the reason.
  Keep configure and author tools separate from runtime dependencies.
- The workspace distribution uses public APIs from the core distribution and
  may consume other libtmux core distributions. Keep tmux protocol, targeting,
  transport, and resource ownership in the cores.
- Each distribution owns its MakeMaker declaration, dependencies, README, and
  license. Keep author tooling at the repository root. Configure a package
  from its own directory and run shared checks with `mise exec -- make check`.

## Native documentation

Use POD L<> cross-references for public classes, methods, return types, and
errors. Link real qualified symbols/sections and preserve them through the
shared-site exporter. Validate native POD and unresolved public API links.

## Publishing

Use only `origin`, the canonical `libtmux/libtmux-perl` repository, for pushes
and GitHub settings changes. Leave every `tony` remote and its repository
untouched. Do not mirror pushes there; its workflows incur costs.

## Change discipline

- Check the branch and working tree. Preserve unrelated work and symlinks.
- Make the smallest coherent change that solves the verified problem.
- Reuse existing files, helpers, APIs, and tests before adding new ones.
- Keep new APIs private until an external caller needs them. Add files for
  distinct responsibilities or independent reuse, not one-line re-exports.
- Add tests only for critical behavior. Show that a regression test fails
  for the intended reason before relying on its passing result.
- Prefer `rg`, `ag`, and `fd` for discovery; use `jq` for JSON.
- Follow native Perl conventions. Sibling ports provide behavioral
  references; their test results do not establish support in this port.
- Verify claims against the current source and commands actually run.
  Distinguish `PASS`, `FAIL`, `PARTIAL`, and `UNVERIFIED` results, and report
  whole-command elapsed times.
- Answer questions before editing. When responding to feedback, state
  agreement or disagreement before explaining changes.
- Commit, change remotes, push, or publish only within the user's current
  authorization. Honor authorization already supplied in the session.

## Guides

- Setup, validation, tmux isolation, and pull requests:
  [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).
- Documentation, comments, and commit messages:
  [.github/WRITING.md](.github/WRITING.md).
- Perl package and CI choices, with pinned upstream examples:
  [.github/PERL.md](.github/PERL.md).

Each guide owns its subject. `CLAUDE.md` is a relative symlink to this file;
keep shared instructions here.

## Merging pull requests

Use a descriptive subject ending in the actual PR number: `Title (#PRNUM)`.
Follow it with `what:` and `why:` sections describing the change and reason.
Pass both explicitly to the merge command and read back the resulting commit
message. Do not use the default `Merge pull request ... from ...` subject.
