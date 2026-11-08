# Perl packaging and CI

Use MakeMaker, a `cpanfile` per distribution, cpm, and Perl::Tidy for the
three native distributions. Runtime code targets stable Perl 5.44.0. The choices below come from
inspected upstream source and release metadata, checked on 2026-11-07.

## Product scope

The selected products are core, optional async, and workspace distributions. MCP is explicitly excluded from this port. This is a scope
decision, independent of future SDK availability.

Runtime code should use Perl's standard library where possible and stable
Perl 5.44 features. Keep any justified non-core runtime dependencies explicit.
MakeMaker, the cpanfile adapter, cpm, and Perl::Tidy are configure or author
tools; they do not belong to the library's runtime dependency set.

Workspace functionality uses public core APIs and may consume other libtmux
core distributions. The cores own tmux protocol, targeting, transport, and
resource lifetimes. The workspace layer owns its configuration and
orchestration.

## Distribution boundaries

| Directory | CPAN distribution | Runtime requirements |
| --- | --- | --- |
| `packages/core` | `LibTmux` | Perl 5.44; prefer its standard library. |
| `packages/async` | `LibTmux-Async` | Versioned core, Future 0.54, IO::Async 0.805, IO::Async::Loop::Ppoll 0.10 and IO::Ppoll 0.14; no effect on core requirements. |
| `packages/workspace` | `LibTmux-Workspace` | Perl 5.44 and the versioned `LibTmux` core. |

Each directory is a native CPAN distribution root with its own `Makefile.PL`,
`cpanfile`, README, and license. Package configuration reads only its own
declarations. Generated metadata stays in that directory. The root `cpanfile`,
formatter profile, and `Makefile` own the shared development environment.

The [OpenTelemetry SDK declarations][otel-sdk] show a maintained 2026 example
of a consumer distribution requiring a versioned core API. Its distributions
live in separate repositories. This project's choice is to keep the native
distribution boundaries as peer directories in one repository.

The workspace declares its core dependency through ordinary CPAN metadata.
It does not own tmux protocol or transport. Additional libtmux core
distributions can be selected when implementation needs their public APIs.
Native archives and installed consumers are separate gates from metadata.
Only verified artifact and runtime evidence establishes consumer behavior.

## Selected tools

| Responsibility | Selection | Reason |
| --- | --- | --- |
| Development interpreter | Perl 5.44.0 | Current stable Perl; pinned with mise. |
| Distribution configuration | ExtUtils::MakeMaker 7.78 or newer | Native CPAN metadata and configure support. |
| Dependency declarations | One `cpanfile` per distribution | Each artifact owns its requirements. |
| MakeMaker adapter | ExtUtils::MakeMaker::CPANfile 0.11 or newer | Reads the declarations during configuration. |
| Dependency installation | cpm 1.1.6 | Local dependencies, explicit phases, and reusable builds. |
| Formatting | Perl::Tidy 20260826 | A fixed formatter version keeps results consistent. |
| GitHub interpreter setup | actions-setup-perl v1.44.5 | Node 24, interpreter setup, and dependency caching. |

The stable [MakeMaker release][makemaker] and [cpanfile adapter][adapter]
were published in March and July 2026. `Makefile.PL` explicitly parses the
declarations before calling the adapter: the adapter's loader catches errors
and can exit successfully when a dependency file is invalid. Configuration
here must fail on that error. Both native metadata and MakeMaker's
prerequisites come from the same dependency declarations.

[Perl::Tidy][tidy] supplies formatting without selecting an object system or
adding runtime dependencies. The profile uses four-space indentation and an
80-column target, following the small [libwww-perl profile][lwp-tidy].
The exact formatter version is an author dependency, outside the runtime
requirements.

## Dependency version policy

Keep recent, tested minimum versions in each distribution's runtime,
configure, and test requirements. A bare cpanfile version such as `0.54`
means `>= 0.54`; only `== 0.54` requires that exact version. This lets new
projects adopt newer compatible releases without waiting for a libtmux
metadata change. Raise a minimum for a required API, bug fix, or a deliberate
support decision. Add exclusions or upper bounds only for demonstrated
incompatibility, with its reason and regression evidence.

The root author environment deliberately pins Perl::Tidy and PPI. Formatter
output and extracted declarations must be reproducible; those tools are not
installed runtime requirements. Update their pins in focused changes that
review the formatting or extraction diff. The development Perl pin selects
the interpreter used for qualification; the package's Perl requirement is a
minimum, not an exact interpreter lock.

Qualify both direct minimum dependencies and freshly resolved compatible
releases, preserving the two author pins in both environments. Record actual
loaded versions and module origins. A minimum-version declaration alone is
not evidence that it works, and an existing dependency cache is not evidence
of testing the latest release. Minimum checks cover direct declarations;
they do not imply a minimal version of every transitive dependency.

An application may separately lock its resolved dependency graph in a
`cpanfile.snapshot`. Do not copy that application's exact runtime versions
into these libraries' published requirements. See the
[cpanfile version rules](https://metacpan.org/pod/cpanfile#SYNTAX),
[CPAN dependency phases](https://perldoc.perl.org/5.44.0/CPAN::Meta::Spec#Phases),
and [cpm snapshot support](https://metacpan.org/pod/App::cpm::Tutorial#cpanfile-and-dist/url/mirror/git-syntax).

## Maintained examples

The sample covers library, framework, test-toolchain, and package-installer
repositories. GitHub reported a successful primary build or test workflow at
each inspected revision. These observations describe the sampled upstream
revisions; they do not qualify this port.

| Project and inspected revision | Observed pattern |
| --- | --- |
| [Mojolicious, November 2026][mojo] | Direct MakeMaker metadata, explicit resources, separate formatting workflow. |
| [Plack, October 2026][plack] | `cpanfile` declarations with generated distribution files. |
| [libwww-perl, September 2026][lwp] | Dependencies come from `cpanfile`; build and test the distribution artifact. |
| [cpm, October 2026][cpm-build] | Small Module::Build::Tiny entrypoint; separate CI and release work. |
| [Test::Simple, October 2026][test-simple] | Dist::Zilla generates release metadata; author and runtime dependencies differ. |

## Alternatives

[Minilla v3.3.2][minilla] is maintained and provides a compact authoring and
release workflow. Its conventions assume a library under `lib/`, and its
commands include preparing and publishing distributions. It becomes useful
when release automation has work to do.

[Module::Build::Tiny 0.053][build-tiny] supports a small `Build.PL`, but its
authoring guidance delegates metadata production to another tool. The cpm
distribution's metadata is generated by Dist::Zilla. A short build entrypoint
alone does not establish a smaller author toolchain.

Dist::Zilla suits the generated metadata and release rules seen in
libwww-perl and Test::Simple. This scaffold uses direct MakeMaker configuration
to keep its author dependencies small. Revisit that choice when repeated
release work justifies a generator.

## CI conventions

The [Scaffold workflow](workflows/scaffold.yml) uses read-only repository
permissions, cancellation for superseded runs, an explicit Linux runner, and
full commit pins for checkout and Perl setup. Dependabot groups monthly action
updates. The setup action uses Node 24 and includes cpm 1.1.6.

CI reads the interpreter version from `.tool-versions`. The action's
`perl-version-file` input reads plain version text, so it cannot consume the
mise file's `perl VERSION` line directly. Its [dependency cache][setup-readme]
includes the interpreter identity and hashes of the dependency declarations.

The inspected projects contain both recent action majors and older checkout
versions. Reuse their workflow structure after checking current action
releases. The selected [checkout v7.0.1][checkout] and [Perl setup action][setup]
are pinned to their verified release commits.

The checks workflow preserves syntax, native metadata, formatting, instruction
symlink, and whitespace checks, and adds units, native POD, conformance, pinned
Linux/tmux cells, and installed native archives. Publication remains separately
authorized. Actions and installer assets use verified commit or digest pins.

## Language and package status

The [Perl 5.44 class reference][perlclass] still marks `class` experimental.
The implementation uses ordinary packages and stable positional signatures.
No object framework or experimental class/named signatures are required.
`0.001_001` identifies unpublished development distributions; working source
and installed archive checks do not imply a CPAN release.

PPI 1.291 is an author-only documentation dependency. A native B::Deparse probe
lowered signatures to argument checks and lost authored defaults; PPI retains
the declared syntax while Pod::Simple parses native documentation. Runtime
consumers do not load either author parser or formatter. The optional async
runtime dependencies meet demonstrated concurrency and loop/reaping needs;
Future::AsyncAwait remains optional caller syntax.

[makemaker]: https://metacpan.org/release/BINGOS/ExtUtils-MakeMaker-7.78
[adapter]: https://github.com/charsbar/ExtUtils-MakeMaker-CPANfile/blob/0b2e68289810e4eb220be0956eed6023dea33605/lib/ExtUtils/MakeMaker/CPANfile.pm
[tidy]: https://metacpan.org/release/SHANCOCK/Perl-Tidy-20260826
[lwp-tidy]: https://github.com/libwww-perl/libwww-perl/blob/57af6da5207e80b0ffad2087021e4a9fa1e08fa6/.perltidyrc
[mojo]: https://github.com/mojolicious/mojo/blob/33648dc25bad1594461180d0793cd1b21753b0bd/Makefile.PL
[plack]: https://github.com/plack/Plack/tree/9599edbbdcdb4aa913ba00bc4db71cb027fa9c25
[lwp]: https://github.com/libwww-perl/libwww-perl/blob/57af6da5207e80b0ffad2087021e4a9fa1e08fa6/dist.ini
[cpm-build]: https://github.com/skaji/cpm/blob/ea08d4b1f050b4defe889068526cf997d5e77964/Build.PL
[test-simple]: https://github.com/Test-More/test-more/blob/38b0e20ff712d39e01e443a4d736ef73bf0a2c06/dist.ini
[minilla]: https://github.com/tokuhirom/Minilla/blob/f57573a53cf271515e133b797bd1662ffff28249/README.md
[build-tiny]: https://github.com/Perl-Toolchain-Gang/module-build-tiny/blob/ff312b6e1475cc0a7bd920669fcb22d016a5bb55/lib/Module/Build/Tiny.pm
[setup-readme]: https://github.com/shogo82148/actions-setup-perl/blob/eebc5c886de14ebbfcd2493d49a12007d2c30477/README.md
[checkout]: https://github.com/actions/checkout/releases/tag/v7.0.1
[setup]: https://github.com/shogo82148/actions-setup-perl/blob/eebc5c886de14ebbfcd2493d49a12007d2c30477/action.yml
[perlclass]: https://perldoc.perl.org/5.44.0/perlclass
[otel-sdk]: https://github.com/jjatria/perl-opentelemetry-sdk/blob/237daafb60d25e76aa5a2dc588837550fee512d3/cpanfile
