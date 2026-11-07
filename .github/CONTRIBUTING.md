# Contributing

The core, optional async, and workspace distributions share author tooling.
Runtime behavior is checked with pure units, owned tmux fixtures, extracted
archives, installed consumers, and runnable examples. MCP is excluded.

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
`packages/core`, `packages/async`, and `packages/workspace` owns a separate `cpanfile` and
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

The [Perl checks workflow](workflows/scaffold.yml) runs metadata, units, POD,
formatting, generated checks, pinned Linux/tmux cells, and native artifact
consumers on canonical public CI. Individual conclusions at the current source
revision are required; local success alone is not hosted evidence.

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

Verify tmux behavior against a real server. Each test or probe must
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

## Implementation verification commands

Provision pinned tmux source builds outside all test loops. The lock records
release URLs, archive digests, and upstream tag commits. Build provenance
records compiler, configure flags, and executable digests.

```console
$ mise exec -- python3 scripts/compatibility.py --provision
```

Focused critical tests (inner loop):

```console
$ mise exec -- prove \
    -Ilocal/lib/perl5 \
    -Ipackages/core/lib \
    packages/core/t/unit/selection.t
```

All units, generated readers, native POD targets, metadata, and formatting
(mid loop):

```console
$ mise exec -- make check
```

Owned real-tmux integration (outer loop):

```console
$ mise exec -- make integration
```

Complete examples (outer loop; source libraries by default):

```console
$ mise exec -- make examples
```

Archive checks configure and test extracted native distributions, install
core then workspace then async into the separately provisioned consumer
prefix, and verify module/POD origins without checkout runtime fallbacks:

```console
$ mise exec -- make artifacts
```

Provision the external consumer runtime outside test loops:

```console
$ mise exec -- python3 scripts/provision-consumer.py
```

The consumer prefix is an author-created temporary directory outside the
checkout, recorded in ignored `.cache/consumer-prefix`. Provision Future,
IO::Async, and optional caller-side Future::AsyncAwait there with cpm's
`--local-lib-contained` and `--final-install runtime` before this outer gate;
configuration/test tools stay in the root author environment. No check
silently downloads dependencies.

Run the exact Linux release cells plus a separate 3.3 rejection check:

```console
$ mise exec -- make compatibility
```

The matrix includes core graph/query, async, workspace, and runnable examples.
Inspect every cell in `.cache/compatibility/evidence-all.json`; missing builds are
UNVERIFIED. CI runs the same cell command with an explicit version.

Native API export uses PPI 1.291 for declared signatures and Pod::Simple for
POD. This author-only parser preserves signatures that B::Deparse lowers into
argument checks. Exporting without --allow-dirty verifies every public input
against the selected committed library revision and independently verifies the
executing exporter revision:

```console
$ mise exec -- perl scripts/export-api.pl
```

Provision the independent filter evaluator before the mid loop, from its
source-pinned sibling checkout (or the canonical checkout in CI):

```console
$ mise exec -- python3 scripts/conformance.py --provision
```

Regenerate the pinned Python behavior inventory only after reviewing mapping
changes:

```console
$ mise exec -- python3 scripts/inventory.py
```

The benchmark is a separate tier. It compares stable results and query identity
before reporting timings; process counts use a separate exec-wrapper probe so
that its overhead does not contaminate native timings:

```console
$ mise exec -- make benchmark
```

Native archives contain the portable unit suites. Repository-only live suites
use the shared owned fixture and explicit subreaper wrapper; installed artifact
qualification executes those suites and examples against an external prefix.
Record exact tree/command evidence without changing the check command:

```console
$ mise exec -- python3 scripts/evidence.py mid -- make check
```

A method call does not apply a function prototype to its arguments. Keep
`T2->ok` predicates in scalar context: use `T2->like($text, qr/pattern/,
$description)` for regex checks, or wrap a combined predicate in `scalar(...)`.
A failing list-context match can otherwise remove the predicate argument and
turn the description into a false passing assertion.
