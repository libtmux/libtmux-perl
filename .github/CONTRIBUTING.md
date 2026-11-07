# Contributing

This is the package scaffold for a Perl port of libtmux. Core and workspace
distribution metadata, formatting, and bootstrap CI are configured. Library
implementation and runtime tests await separate work. MCP is excluded.

[AGENTS.md](../AGENTS.md) governs scope and change discipline.
[WRITING.md](WRITING.md) governs prose and commit messages.

## Environment

[.tool-versions](../.tool-versions) pins Perl 5.44.0. The package declares Perl
5.44 as its initial minimum; runtime compatibility still requires library
tests. Check the [upstream release page](https://www.perl.org/get.html) when
updating it. [PERL.md](PERL.md) records the packaging and CI choices.

Install the pinned interpreter with mise, outside the test loops:

```console
$ mise install
```

Check the selected interpreter:

```console
$ mise exec -- perl -v
```

The root `cpanfile` owns the shared author environment. Each distribution in
`packages/core` and `packages/workspace` owns a separate `cpanfile` and
`Makefile.PL`. MakeMaker consumes each package's dependencies and generates
ignored Makefile and metadata outputs. Edit the declarations instead of the
generated files. The handwritten root `Makefile` runs shared checks.

Download the pinned, standalone cpm installer into the local cache:

```console
$ mkdir -p .cache
```

```console
$ curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --output .cache/cpm \
    https://github.com/skaji/cpm/releases/download/v1.1.6/cpm
```

Verify the release asset's digest:

```console
$ printf '%s  %s\n' \
    2f85dea9272722d518297a3baa13a85ac7a9bbb18c0b529bd29eb7ccbf23c734 \
    .cache/cpm | sha256sum --check
```

Install the shared configure and author dependencies into ignored `local/`,
outside the test loops:

```console
$ mise exec -- perl .cache/cpm install \
    --top-level-phase configure,runtime,test,develop \
    --show-build-log-on-failure
```

## Validation

For scaffold changes, review the complete diff, check relative Markdown links,
and confirm that `CLAUDE.md` remains a relative symlink to `AGENTS.md`. Check
that ignore rules exclude local artifacts and keep shared configuration and
source files visible to Git.

Check both package declarations, generate and validate their native CPAN
metadata, compare their license copies, and check formatting:

```console
$ mise exec -- make check
```

Run only the metadata checks:

```console
$ mise exec -- make check-metadata
```

Run only the formatting checks:

```console
$ mise exec -- make check-format
```

Apply the shared formatter profile:

```console
$ mise exec -- make format
```

The [Scaffold workflow](workflows/scaffold.yml) runs the same root check on
Linux. It checks package configuration; runtime tests, installed consumers,
and releases need their own checks when implementation begins. Workspace's
declared `LibTmux` dependency has no implemented API yet. Configuration alone
does not establish that the workspace can load or execute the core.

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

[repository.json](repository.json) records repository identities and the
canonical repository's description, topics, and issue labels. Its publishing
policy permits only `origin`. Apply authorized settings changes through the
GitHub CLI or API; GitHub does not apply this file automatically.

- `origin`: public
  [libtmux/libtmux-perl](https://github.com/libtmux/libtmux-perl).
- `tony`: an existing private remote, excluded from publishing and syncing.

Push only to `origin`. Leave every `tony` remote and its repository untouched;
its workflows incur costs. [AGENTS.md](../AGENTS.md#publishing) owns this rule.
