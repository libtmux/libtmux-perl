# Release to CPAN

The initial candidate is `0.002`, tagged `v0.002`. The three independent
distributions are `LibTmux`, `LibTmux-Workspace`, and `LibTmux-Async`.
This branch prepares their first ordinary indexed release; it does not publish
them. Perl 5.44 and Linux x86_64 LP64 remain the baseline, with tmux 3.3a–3.8
supported and only the two tmux endpoints in CI.

## One-time maintainer setup

1. Sign in to [PAUSE](https://pause.perl.org/), or
   [request an account](https://pause.perl.org/pause/query?ACTION=request_id).
   Account approval and the account's private credentials require the maintainer.
2. Check package permissions in PAUSE for `LibTmux` and all provided modules.
   The [operating model](https://pause.perl.org/pause/query?ACTION=pause_operating_model)
   describes first-come and co-maintainer indexing permissions.
3. In this repository's [cpan environment](https://github.com/libtmux/libtmux-perl/settings/environments),
   add environment secrets `PAUSE_USERNAME` and `PAUSE_PASSWORD`. Use the PAUSE
   ID, not a GitHub username. Do not put credentials in an issue, PR, tag,
   command argument, or tracked file.
4. Check that `cpan` permits `v*` tags and requires maintainer approval.
   The upload job requests these secrets only after every verification job
   passes and the environment is approved.

The supported [CPAN::Uploader](https://metacpan.org/pod/CPAN::Uploader)
authentication is a PAUSE username and password over HTTPS. No registry-side
OIDC trusted-publishing flow is selected. A GitHub token is not a PAUSE password.
`CPAN::Uploader` is a release tool, not a dependency of any distribution.

For an initial manual upload, leave the secrets unset and follow
[Manual publication](#manual-publication) instead. Do not approve an automated
upload of archives already submitted manually.

## Prepare a version

Use a decimal Perl version without an underscore for ordinary indexed releases.
The tag is `v` followed by that exact string: version `0.002` uses `v0.002`.
`v0.0.2` means a different Perl version and is not accepted by this workflow.
The current development version `0.001_001` sorts below `0.002`.
See [Perl version rules](https://perldoc.perl.org/5.44.0/version::Internals).

Keep these declarations consistent when preparing a later release:

- The main `$VERSION` in each distribution's module.
- Each `Makefile.PL` version and `provides` versions.
- Workspace and async's minimum core requirements in `cpanfile`, plus
  workspace's `use LibTmux VERSION` declaration.
- The package versions emitted by `scripts/export-api.pl`.
- Each distribution's `Changes` file.

An ordinary release has `release_status => 'stable'`. In CPAN metadata this
means an indexed release; it does not promise an unchanging `0.x` API.
Underscore and `-TRIAL` uploads are developer releases and are not the
tag-triggered publication path here. Do not remove trial markers without
checking all module and dependency versions.

## Verify before merging

Read [CONTRIBUTING.md](CONTRIBUTING.md) for provisioning outside test loops.
Run metadata, formatting, author release tests, units, generated checks, POD,
and the independent filter subset:

```console
$ mise exec -- make check
```

Provision the isolated consumer dependencies, then build and install the three
native archives. These are separate commands; metadata generation and archive
construction must not run concurrently.

```console
$ mise exec -- python3 scripts/provision-consumer.py
```

```console
$ mise exec -- make artifacts
```

Run the supported tmux endpoints:

```console
$ mise exec -- make compatibility
```

The artifact builder records source identity, clean-tree state, SHA-256
digests, and installed-consumer results in `.cache/artifacts/evidence.json`.
A release must use a clean committed tree; development builds can still be
tested, but the publication helper refuses their archives.

Inspect a clean candidate without uploading:

```console
$ mise exec -- perl scripts/release.pl \
    --tag v0.002 \
    --source "$(git rev-parse HEAD)" \
    --artifacts .cache/artifacts
```

The JSON plan lists exact files, digests, source, and upload order. The helper
checks metadata and every provided module's version, the sibling core
requirements, and each archive's digest against the installed evidence.
It never repacks a verified archive.

## Rehearse on GitHub without credentials

Opening the PR runs the full release rehearsal automatically, without entering
the upload job. After this workflow exists on the default branch, a manual
rehearsal can also select a proposed tag:

```console
$ gh workflow run release.yml \
    --repo libtmux/libtmux-perl \
    --ref initial-release \
    -f candidate-tag=v0.002
```

Every `workflow_dispatch` run is build-only. It cannot enter the PAUSE upload
job and needs no PAUSE credentials. Inspect its individual verification jobs
and the `cpan-release-plan` artifact. The inspection also installs the pinned
release-only uploader, proving tool provisioning before the first real upload.

The [release workflow](workflows/release.yml) handles PRs and tags and calls the same
[Perl checks](workflows/scaffold.yml) used for PRs: dependency profiles,
metadata/units/POD, both Linux/tmux endpoints, native archives, installed
consumers, and runnable examples. The publisher downloads the native-archive
artifact by the ID returned by that same run; an older green run cannot
substitute for the tagged commit's checks.

## Tag and publish

Merge the reviewed PR before tagging. The actual release commit must be
reachable from canonical `origin/master`, and the tag must resolve to that
same commit. Use the reviewed merge commit when creating an annotated tag:

```console
$ git fetch origin master
```

```console
$ git tag \
    --annotate v0.002 \
    --message 'LibTmux 0.002' \
    origin/master
```

Push only the selected tag to canonical origin:

```console
$ git push origin refs/tags/v0.002
```

The tag event runs full verification and archive inspection, then waits for
approval of the `cpan` environment. Review the source, tag and upload plan
before approving. The upload job verifies the files again and uploads core,
workspace, then async through the fixed PAUSE HTTPS endpoint. It receives no
GitHub write or OIDC permissions.

PAUSE accepting an upload is distinct from indexing it. Read the PAUSE indexing
reports, inspect the [CPAN index](https://www.cpan.org/modules/02packages.details.txt.gz)
and [MetaCPAN](https://metacpan.org/), and test installation from CPAN in a fresh
Perl 5.44 environment. The following installs must resolve published packages,
without source-directory arguments:

```console
$ cpm install --global LibTmux
```

```console
$ cpm install --global LibTmux::Workspace LibTmux::Async
```

Verify module origins, installed POD, the workspace CLI, and a real owned tmux
workflow. Only after those checks should availability labels and registry
installation instructions say the packages are published. Shared-site
deployment remains a separate operation.

## Manual publication

Download the `perl-native-archives` artifact from the successful tag run and
retain its `artifacts/` directory, including `evidence.json`. Use a checkout
of the same tagged source; `origin/master` and the tag must be available.
Install [CPAN::Uploader](https://metacpan.org/dist/CPAN-Uploader) locally and
keep credentials in its private `.pause` configuration or private environment.

First run `scripts/release.pl` without `--publish`, using the downloaded
`artifacts/` directory and its source commit. For interactive manual upload,
submit the exact files in dependency order:

```console
$ cpan-upload artifacts/LibTmux-0.002.tar.gz
```

```console
$ cpan-upload artifacts/LibTmux-Workspace-0.002.tar.gz
```

```console
$ cpan-upload artifacts/LibTmux-Async-0.002.tar.gz
```

Do not approve the automated upload job after uploading manually; cancel that
pending job. Perform the same indexing and fresh-install checks afterward.

## Recover a partial upload

An upload failure can occur after PAUSE accepted the file. The helper reports
previously confirmed uploads and treats the failing file's outcome as uncertain.
Inspect the PAUSE account before retrying. Do not retry accepted filenames or
rebuild a package under an already-used filename: PAUSE does not allow replacing
a distribution archive, even after deletion.

Retain the original GitHub artifacts. Manually submit only files PAUSE has not
accepted, using those original bytes. If an accepted archive needs correction,
prepare a new version and repeat qualification. Artifact retention is 30 days;
download a recovery copy promptly if publication is interrupted.

## Companion patterns

The native suite follows the same-run CI/artifact separation used by
[PowerShell publishing](https://github.com/libtmux/libtmux-powershell/blob/master/.github/workflows/release.yml)
and the full tag verification and protected publisher used by
[Ruby](https://github.com/libtmux/libtmux-ruby/blob/master/.github/workflows/release.yml)
and [Elixir](https://github.com/libtmux/libtmux-elixir/blob/master/.github/workflows/release.yml).
Perl uses PAUSE credentials and native MakeMaker distributions; another
registry's authentication or release result does not apply to CPAN.
