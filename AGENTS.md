# Agent instructions

This repository contains the package scaffold for a Perl port of libtmux.
Keep bootstrap work limited to package metadata, tool configuration, CI, and
contributor instructions. Start architecture or implementation only when
requested.

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
