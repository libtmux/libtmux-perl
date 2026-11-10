# Writing

This guide governs documentation, user-facing text, comments, Markdown, and
commit messages. [CONTRIBUTING.md](CONTRIBUTING.md) governs the development
workflow.

## Voice

Lead with the conclusion or observable behavior, then give the evidence the
reader needs. Use active voice, present tense, concrete verbs, and short
sentences. Assume no conversation history; explain what a ticket, codename,
or referenced commit means.

State capabilities and limits precisely. Distinguish a scaffold, implemented
behavior, verified compatibility, and a published release. A sibling port's
features or passing checks do not establish this port's capabilities.

Cut promotional claims, conversational filler, AI signatures, and tool
metadata. Use no emoji in commits, issues, pull requests, comments, or code.
Keep personal information and machine-specific paths out of published text.

## Documentation and examples

Describe the caller's task before implementation details. Explain inputs,
defaults, empty values, errors, side effects, ownership, ordering, concurrency,
and cleanup when they affect the contract. Use native Perl conventions.
Write installed API documentation in POD, with `L<>` links to real qualified
classes, methods, return types, errors, and sections. Validate those targets
through native POD checks and the shared-site exporter. Avoid repeating
signatures or language basics.

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

## READMEs

Give each distribution its own README, with its package name, purpose,
requirements, one supported installation route, a working example, and links
to its API and guides. Preserve the logo block at the top and the existing
`libtmux-logo` markers. Keep package-local assets usable in the native archive.

Organize sections around reader tasks. Link the API at its first prose mention
in a section and keep links out of code fences. Put detailed contracts in the
owning guide. Keep paragraphs short enough to scan; use a table when readers
need to compare packages or examples. Describe supported versions separately
from the versions CI actually runs.

Use relative source links in the repository README. Distribution READMEs also
need to work outside the checkout, so use hosted documentation or canonical
repository URLs for material outside that distribution. The merged
[Rust README structure](https://github.com/libtmux/libtmux-rs/pull/89) and
[TypeScript package/API links](https://github.com/libtmux/libtmux-ts/pull/82)
show the shared conventions; adapt their commands and contracts to Perl.

## Comments and errors

Keep comments that explain a non-obvious invariant, protocol constraint,
compatibility workaround, ordering requirement, or failure mode. Aim for one
or two direct lines. Preserve tool directives and explanations of code that
appears wrong but is required.

Remove narration of the next lines, repeated defaults, speculative TODOs,
and history already recorded by Git. Put design rationale and rejected
alternatives in commit messages. Avoid brittle line references, bare commit
hashes, and counts that duplicate source state.

Error messages name the failed operation and its concrete cause. Add a useful
next action when one exists; omit empty phrases such as "an error occurred".

## Markdown and code blocks

Use plain CommonMark with sentence-case headings. Put blank lines before
lists and code blocks and after headings. Wrap repository prose at 80 columns
where practical, except URLs, identifiers, and tables. Do not hard-wrap GitHub
issue or pull request body paragraphs.

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

## Commit messages

Use this scoped format; the detail qualifier is optional:

```text
scope(type[detail]) Concise description

why: Explain the reason or effect.
what:
- State the concrete change
```

Use a lowercase scope unless it names a class or product. Name the affected
component and use an imperative verb. Keep the subject within 50 characters
and body lines within 72, except indivisible URLs or identifiers. Common types
are `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, and `ci`.

Explain why the change matters under `why:` and list concrete changes under
`what:`. Preserve real newlines with a message file or heredoc. Keep each
commit focused on one topic. Leave temporary validation results in the review
discussion; retain context that remains useful over time in the commit.

Avoid vague subjects such as "wip", "misc fixes", or "address review". Do not
add emojis, attribution trailers, or PR numbers to ordinary commit subjects.
A merge subject's PR number must identify the PR that produced the merge.

## Reviews, changelogs, and releases

Describe the final change for someone who has not read the conversation. Lead
with the concrete problem and resulting behavior, then give relevant checks
and limits. Distinguish passing, failing, skipped, and unverified work.

When a changelog exists, record caller-visible changes under `Unreleased`.
State changed defaults and incompatibilities with migration guidance. Omit
invisible refactors and descriptions of effort.

Release notes explain what an upgrader needs to know and any required action.
Do not invent versions, release dates, compatibility, or publication claims.
