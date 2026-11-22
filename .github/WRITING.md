# Writing

This file adds Perl, POD, and multi-distribution rules to
[`libtmux/.github/WRITING.md`][org-writing], which governs voice, plain
CommonMark, 80-column prose wrapping, unwrapped issue and pull-request bodies,
slop removal, and commit and pull-request format.
[CONTRIBUTING.md](CONTRIBUTING.md) governs the development workflow.

State capabilities and limits precisely. Distinguish a scaffold, implemented
behavior, verified compatibility, and a published release. A sibling port's
features or passing checks do not establish this port's capabilities.

## Documentation and POD

Describe the caller's task before implementation details. Explain inputs,
defaults, empty values, errors, side effects, ownership, ordering, concurrency,
and cleanup when they affect the contract. Use native Perl conventions.
Write installed API documentation in POD, with `L<>` links to real qualified
classes, methods, return types, errors, and sections. Validate those targets
through native POD checks (`make check-pod`) and the shared-site exporter
(`scripts/export-api.pl`). Avoid repeating signatures or language basics.

Examples must match available APIs and include required setup and cleanup.
Keep complete programs in [examples](../examples/README.md), check their exit
status and expected output, and derive marked guide blocks from those files.
Distinguish checkout fixtures from installed public APIs. Name prerequisites
for excerpts and borrowed-server examples; do not leave setup implicit.
Each example that starts tmux owns an explicit socket and verifies cleanup.
Never rely on inherited `TMUX` or `TMUX_PANE` to select its server.

The [shared capability showcase](https://github.com/libtmux/docs/issues/243)
offers only executed examples with recorded CI evidence and the actual tmux
floor. Keep unsupported capabilities out of its advertised examples. A
performance claim needs a measurement and a reproduction command.

Link to the source of a rule instead of copying it across documents. Keep
relative links valid when moving files or renaming headings.

## Code blocks

Code blocks are paste-and-run units:

- Put one command in each block. An explicit `&&`, `;`, or `\` continuation
  counts as one command.
- Put explanations outside the fence.
- Mark shell commands as `console` and prefix them with `$ `.
- Split long commands with `\`, one flag per continuation line.
- Use the actual language tag for source examples.

Show recent commits as a graph:

```console
$ git log \
    --max-count=10 \
    --graph \
    --oneline
```

## Examples

<!-- shared:examples -->

An example is code written for a reader: a program under `examples/`, code in
a doc comment or docstring, and every fenced block in a README or docs page.
Shell blocks also follow [Code blocks](#code-blocks).

The text between the shared markers is the same in every libtmux port.
Change it in all of them together.

### Width

- **Examples stay within 80 columns.** They render in fixed-width boxes that
  scroll sideways, and 80 columns fits a libtmux.org code block in a
  laptop-width window. Comments inside examples wrap at 80 too.
- **The width check enforces it.** It reads the tracked files that
  `.github/example-width.toml` names and fails on a wider line. It measures
  the whole source line, so code in a doc comment counts its indent and
  comment marker. It skips output (a fence tagged `text`, and what a
  `console` block prints), hidden setup lines, and a line that is only a URL;
  an untagged fence counts as code.
- **A line that must stay wider is listed there with its reason.** An entry
  that no longer matches a line fails the check, so no stale entry stays.
- **The formatter's width is the hard limit for all other source.** Example
  directories set their formatter to 80 where the formatter takes a width.

### Reaching 80

- **Change the code, not the line breaks.** A formatter rejoins any line that
  fits its width. Name a sub-expression, use a short example name, hide setup
  the reader does not need, or print less.
- **Break at the outermost level when a break is still needed:** after an
  opening parenthesis with one argument per line, one call per line in a
  chain, one field per line in a literal.
- **Put a comment on its own line above the code it explains.** Never trail
  one after code in an example, unless the repository's example runner reads
  it there, as with an assertion marker.
- **Break a long string at a word boundary,** never inside a tmux format
  (`#{...}`) or an escape sequence; the joined text stays the same.
- **Continue a long command in a `console` block the way its shell does:**
  `\` after a `$ ` prompt, a backtick after `PS> `, one flag per continuation
  line.

### What never breaks

- **Output a test compares.** Wrapping it changes what the test expects.
- **A block copied from a source file.** Fix the width in the source and run
  the sync command; never edit the copy.
- **Marker lines and URLs,** which tools and readers take whole.

<!-- /shared:examples -->

### In this repository

- **Hard limit:** `.perltidyrc` sets `-l=80`, and `make check-format`
  (`scripts/format.pl --check`) checks `cpanfile`,
  `packages/*/{Makefile.PL,cpanfile,lib,t,bin,examples}`, `scripts/`, and
  `examples/*.pl`. `check-example-width` and `.github/example-width.toml`
  enforce the hard 80-column limit across Markdown code blocks,
  `examples/*.pl`, and `packages/*/examples/*.{pl,json}`.
- **Not formatted:** Markdown code fences,
  `packages/workspace/examples/workspace.json`, and POD verbatim blocks are
  not wrapped by `perltidy`; hold them to 80 columns by hand.
- **Runs, compiles, exempt:** `make examples` (`scripts/run-examples.pl`)
  executes `examples/*.pl` and `packages/*/examples/*.pl` against isolated
  tmux servers and checks exit status, stdout, and cleanup; `make artifacts`
  repeats packaged examples from an external prefix. Fences tagged `text` and
  unprompted output lines in `console` blocks are exempt.
- **Compared output and copied blocks:** never wrap output lines asserted by
  `scripts/run-examples.pl` or test suites. Edit `examples/*.pl` or
  `packages/*/examples/*.{pl,json}`, then run
  `perl scripts/check-snippets.pl --write`; `make check-snippets` fails on
  drift.

Bad, over 80:

```perl
my $panes = $snapshot->panes->where({active => true, current_command => {-in => [qw(perl vim)]}});
```

Good, name the criteria first:

```perl
my $where = {active => true, current_command => {-in => [qw(perl vim)]}};
my $panes = $snapshot->panes->where($where);
```

## READMEs

Give each distribution its own README, with its package name, purpose,
requirements, one supported installation route, a working example, and links
to its API and guides. Preserve the logo block at the top and the existing
`libtmux-logo` markers. Keep package-local assets usable in the native archive.

Link the API at its first prose mention in a section and keep links out of
code fences. Put detailed contracts in the owning guide. Use a table when
readers need to compare packages or examples.

Use relative source links in the repository README. Distribution READMEs also
need to work outside the checkout, so use hosted documentation or canonical
repository URLs for material outside that distribution. The merged
[Rust README structure](https://github.com/libtmux/libtmux-rs/pull/89) and
[TypeScript package/API links](https://github.com/libtmux/libtmux-ts/pull/82)
show the shared conventions; adapt their commands and contracts to Perl.

## README shape

A README is scanned, not read: a reader finds a task, runs one example, and
follows a link for the rest. It follows the
[Go README](https://github.com/libtmux/libtmux-go#find-sessions-windows-and-panes):
task sections made of linked API headings, each with a tested example.

- **Header.** The logo block, a centred title, a one-line tagline, and a badge
  row: CI, the CPAN version, libtmux.org and the license. Add a badge or link
  only for a page that returns 200.
- **Task sections.** Each `##` heading names a task in the reader's words, such
  as "Find sessions, windows and panes".
- **API headings.** Each `###` heading under a task starts with the API symbol
  in backticks, linked to its libtmux.org reference page. A colon and the job
  in plain words follow the link.
- **Under a heading.** Link the sibling APIs in a line or two, show the tested
  example and what it prints, add at most one short note, and end with a
  `More:` link to the guide.
- **Short text.** No paragraph runs past three lines, and a list of facts is a
  bullet list. Leave out feature inventories, marketing, and boilerplate about
  tests, checks, evidence or contracts.
- **Requirements.** State floors a reader can act on, such as "tmux 3.3a or
  newer". Leave out toolchain patch versions, CI matrix narration, and kernel
  or libc detail; link the compatibility guide.
- **Packages.** Keep the package table. Give each package a heading that links
  its GitHub directory, a one-line description, and a link line for the API
  reference, CPAN and the changelog.
- **Support and leaves out.** "Support and status" and "What it leaves out" are
  short bullets, each with a bold lead.
- **Imports first.** Every example starts with its imports, so a reader can
  paste it into a file and run it. A displayed excerpt of a larger file starts
  at its imports, or the README shows the whole program.
- **Its own server.** An example starts and cleans up its own private tmux
  server through the library, never with shell setup or `tmux kill-server`.
- **Run in CI.** Every displayed example comes from a file that CI runs.
  `make check-snippets` keeps the README and guides in step with those files.
- **Headline features.** The root README shows the query and filter, planner,
  chaining and control-mode features the port has, each under a linked API
  heading with a tested example. A feature the port lacks goes under "What it
  leaves out", not in a section.

## Comments and errors

Keep comments that explain a non-obvious invariant, protocol constraint,
compatibility workaround, ordering requirement, or failure mode. Aim for one
or two direct lines. Preserve tool directives and explanations of code that
appears wrong but is required.

Remove narration of the next lines, repeated defaults, speculative TODOs, and
history already recorded by Git. Put design rationale and rejected
alternatives in commit messages. Avoid brittle line references, bare commit
hashes, and counts that duplicate source state.

Error messages name the failed operation and its concrete cause. Add a useful
next action when one exists; omit empty phrases such as "an error occurred".

## Changelogs, releases, and commits

Follow `scope(type[detail]): concise description` (50-character subject,
72-character body lines, `why:` and `what:` separated by a blank line) and the
pull-request rules in [`libtmux/.github/WRITING.md`][org-commits]. Use a
lowercase scope unless it names a class or product, and keep temporary
validation results in the review discussion.

Each distribution records caller-visible changes under `Unreleased` in its
CPAN `Changes` file (`packages/core/Changes`, `packages/async/Changes`,
`packages/workspace/Changes`), while root [`CHANGELOG.md`](../CHANGELOG.md)
indexes releases across all three distributions. State changed defaults and
incompatibilities with migration guidance, and do not invent versions, release
dates, compatibility, or publication claims.

[org-writing]: https://github.com/libtmux/.github/blob/main/WRITING.md
[org-commits]: https://github.com/libtmux/.github/blob/main/WRITING.md#commits-and-pull-requests
