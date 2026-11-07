# Contributing

This is the repository scaffold for a Perl port of libtmux. Library
implementation, package metadata, tests, and CI await separate work.

[AGENTS.md](../AGENTS.md) governs scope and change discipline.
[WRITING.md](WRITING.md) governs prose and commit messages.

## Environment

[.tool-versions](../.tool-versions) pins the development interpreter. The pin
does not establish a supported Perl version range. Check the
[upstream release page](https://www.perl.org/get.html) when updating it.

Install the pinned interpreter with mise, outside the test loops:

```console
$ mise install
```

Check the selected interpreter:

```console
$ mise exec -- perl -v
```

Document dependency, build, and package commands here when that tooling exists.

## Validation

For scaffold changes, review the complete diff, check relative Markdown links,
and confirm that `CLAUDE.md` remains a relative symlink to `AGENTS.md`. Check
that ignore rules exclude local artifacts and keep shared configuration and
source files visible to Git.

Check whitespace in unstaged changes:

```console
$ git diff --check
```

Check whitespace in staged changes:

```console
$ git diff --cached --check
```

Report the checks actually run. An absent or skipped test suite is not a
passing suite. Add runnable checks here as they become available.

### Test loops

Time the whole command, including startup and setup. Libraries should aim for
the stretch budgets.

| Loop | Budget | Stretch | Scope |
| --- | --- | --- | --- |
| Inner | Under 5 seconds | Under 2 seconds | Tests for changed code |
| Mid | Under 30 seconds | Under 10 seconds | Unit, lint, generated files |
| Outer | Under 5 minutes | Under 60 seconds | Builds, integration, matrices |

Run the inner loop after every edit, the mid loop after each change and before
handoff, and the outer loop before a commit or pull request.

- Keep network access, installs, production builds, browser launches, sleeps,
  and broad corpus scans out of the inner and mid loops.
- Treat a timeout or wait over one second as a structural bug. Fix the cause
  and use events or subscriptions instead of sleeps.
- Tag slow tests with a one-line reason and run them in the outer loop.
- Fix an over-budget loop before adding tests. Remove redundant setup and
  slow paths; do not raise the budget.
- Keep benchmarks separate: under ten minutes per run and one hour per sweep.
  Reduce the workload if needed.

## tmux isolation

Verify future tmux behavior against a real server. Each test or probe must
own a unique socket and temporary directory with a `libtmux-perl-` prefix.
Address the socket explicitly with `-S` or `-L`. Clear inherited `TMUX` and
`TMUX_PANE` in child environments.

Clean up only the server, processes, and files owned by that run, including on
failure and cancellation. Verify that owned processes exit. Never use or stop
the default server or touch another port's temporary resources.

Record the actual tmux version when behavior depends on it. A passing subset
does not establish support for an entire version range.

## Pull requests

Keep one subject per pull request and one logical change per commit. Review
the complete diff, preserve unrelated work, and stage explicit paths.

Describe the concrete problem and resulting behavior. Report commands,
whole-command elapsed times, and what passed, failed, or remains unverified.
Support performance claims with measurements and document migrations for
incompatible behavior. Follow [WRITING.md](WRITING.md) for commit messages.

Publish packages, releases, or Git tags only when requested. Bootstrap work
does not establish a release process or qualify a supported platform.

## Repository metadata

[repository.json](repository.json) records repository identities, visibility,
default branch, description, topics, and issue labels. Apply changes through
the GitHub CLI or API and verify both repositories; GitHub does not apply
this file automatically.

- `origin`: public
  [libtmux/libtmux-perl](https://github.com/libtmux/libtmux-perl).
- `tony`: private [tony/libtmux-perl](https://github.com/tony/libtmux-perl).

Both repositories are independent, with `master` as the default branch.
The personal repository is not a GitHub fork.
