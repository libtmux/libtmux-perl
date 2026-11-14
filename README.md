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

[![Perl checks](https://github.com/libtmux/libtmux-perl/actions/workflows/scaffold.yml/badge.svg)](https://github.com/libtmux/libtmux-perl/actions/workflows/scaffold.yml)
[![LibTmux](https://img.shields.io/cpan/v/LibTmux?label=LibTmux)](https://metacpan.org/dist/LibTmux)
[![libtmux.org](https://img.shields.io/badge/docs-libtmux.org-0b7285)](https://libtmux.org/en/perl/)
[![license](https://img.shields.io/badge/license-MIT-blue)](https://github.com/libtmux/libtmux-perl/blob/master/LICENSE)

</div>

libtmux for Perl is a tmux client library for creating sessions, arranging
windows, sending input, and querying captured state with ordinary Perl arrays.
Core and workspace use the Perl standard library at runtime; the optional
async distribution adds Futures and a caller-owned event loop.

[Quick start](#server-new_session-create-a-session-and-arrange-its-windows) ·
[Filter panes](#selection-where-filter-with-criteria-and-perl-callbacks) ·
[Packages](#choose-a-package) ·
[Documentation](https://libtmux.org/en/perl/) ·
[Guides](https://libtmux.org/en/perl/latest/guides/) ·
[API reference](https://libtmux.org/en/perl/latest/reference/) ·
[CPAN](https://metacpan.org/dist/LibTmux)

## [`Server->new_session`][server-new-session]: create a session and arrange its windows

Use Perl 5.44 and tmux 3.3a–3.8 on Linux x86_64 LP64, including WSL. With
Perl and cpm on `PATH`, install the published core distribution from CPAN:

```console
$ cpm install \
    --global \
    LibTmux
```

Run the [complete program](packages/core/examples/quickstart.pl) with an explicit
socket path. It creates a session, splits its editor window, adds a logs
window, and retains a snapshot. It removes only the session it created,
including on failure; it preserves any other sessions on the selected server.
Save the program below as `quickstart.pl`, or run the linked file from a checkout:

```console
$ perl quickstart.pl "${TMPDIR:-/tmp}/libtmux-perl-$$.sock"
```

<!-- example: packages/core/examples/quickstart.pl -->
```perl
use v5.44;
use File::Temp ();
use LibTmux::Server;

# Without a socket argument, a private temporary directory holds the server.
my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $socket  = shift @ARGV // "$private/tmux.sock";
my $server  = LibTmux::Server->new(
    socket_path => $socket,
    executable  => shift(@ARGV) // 'tmux',
    config_file => '/dev/null',
);
my ($session, $snapshot, $failure);
try {
    $session = $server->new_session(
        name    => 'perl-quickstart',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $server->new_window(
        session => $session,
        name    => 'logs',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $snapshot = $server->snapshot;
}
catch ($error) {
    $failure = $error;
    $session //= $error->created if $error isa LibTmux::X::Creation;
}
if ($session) {
    try { $server->kill_session(session => $session) }
    catch ($cleanup) {
        warn "session cleanup failed: $cleanup\n";
        $failure //= $cleanup;
    }
}
die $failure if defined $failure;

# The captured graph remains readable after its live session has gone.
for my $link ($snapshot->session_by_id($session->id)->window_links->@*) {
    my $count = $link->window->panes->count;
    say $link->window->name, ': ', $count, $count == 1 ? ' pane' : ' panes';
}
```

The captured graph remains readable after the live session is removed:

```text
editor: 2 panes
logs: 1 pane
```

[`Server`](https://libtmux.org/en/perl/latest/reference/libtmux-server/) owns
explicit commands. Its
[`new_session`](https://libtmux.org/en/perl/latest/reference/libtmux-server-new_session/)
starts tmux when the selected socket has no server. Construction alone does no
I/O. The example uses an empty tmux configuration and literal Perl command
arrays; it needs no editor, shell wrapper, Python, or repository fixture.
An existing session with the example's name is a conflict, not a cleanup target.

## [`Selection->where`][selection-where]: filter with criteria and Perl callbacks

Continue with the retained `$snapshot` above. A
[`Selection`](https://libtmux.org/en/perl/latest/reference/libtmux-selection/)
is a blessed array reference: declarative `where`, one-argument `grep`, and
ordinary `map` work together without another tmux call.

<!-- example: packages/core/examples/workflow.pl#filter -->
```perl
my $snapshot = $server->snapshot;
my $panes =
    $snapshot->windows->one({name => 'editor'})
    ->panes->where({width => {-gte => 1}})
    ->grep(sub ($pane) { $pane->height > 0 });
my @ids    = map { $_->id } $panes->@*;
my $active = $panes->one({active => true});
say 'editor panes: ',          scalar @ids;
say 'active pane belongs to ', $active->window->name;

```

`one` throws on zero or multiple occurrences. `one_or_undef` represents absence
and still rejects ambiguity. `to_array` makes a fresh unblessed arrayref.
Native array access stays mutable; library methods validate all members.
The [filtering guide](docs/filtering.md) covers nulls, numeric comparisons,
same-child quantifiers, and invalid-filter diagnostics.

## [`Server->send_text`][server-send-text]: send text, capture output, and set environment

The [live workflow](packages/core/examples/workflow.pl) performs this section
while its session is still open:

<!-- example: packages/core/examples/workflow.pl#input -->
```perl
$server->send_text(
    pane  => $right,
    text  => 'hello from Perl',
    enter => true
);
my $screen = $server->capture_pane(pane => $right, start => -100);
say 'captured bytes: ', length $screen;
$server->set_environment(
    session => $session,
    name    => 'PROJECT',
    value   => 'api',
);
say 'PROJECT=',
    $server->get_environment(session => $session, name => 'PROJECT');

```

[`send_text`](https://libtmux.org/en/perl/latest/reference/libtmux-server-send_text/)
sends literal text; `send_keys` accepts tmux key names.
[`capture_pane`](https://libtmux.org/en/perl/latest/reference/libtmux-server-capture_pane/)
returns current screen/history bytes. Command acceptance does not prove that a
pane application finished its work. Use an application-specific observable
completion condition when that matters. See [orchestration](docs/orchestration.md).

## [`LibTmux::Filter`][filter]: save a reusable filter

[`Filter`](https://libtmux.org/en/perl/latest/reference/libtmux-filter/) compiles
criteria once and owns its normalized data. In the same workflow:

<!-- example: packages/core/examples/workflow.pl#wire -->
```perl
my $filter = LibTmux::Filter->new(
    entity => 'pane',
    where  => {active => true, width => {-gte => 1}},
);
my $restored = LibTmux::Filter->from_json($filter->to_json);
my $selected = $panes->where($restored);
say 'restored filter matches: ', $selected->count;

```

The `libtmux.where/v1` wire format preserves schema-selected text, numbers,
booleans, and nulls. Native `qr//` remains available in callbacks; serialized
regex dialects are deferred. [Query plans](docs/query-planning.md) explain
which scalar predicates can be verified by tmux.

## Choose a package

| Distribution | Use it for | Package and API |
| --- | --- | --- |
| [LibTmux](packages/core/README.md) | Commands, snapshots, graph navigation, filtering, options and environment. Perl standard library at runtime. | [CPAN](https://metacpan.org/dist/LibTmux) · [API](https://libtmux.org/en/perl/latest/reference/) · [POD](https://metacpan.org/pod/LibTmux) |
| [LibTmux-Async](packages/async/README.md) | Concurrent Future-returning operations and explicit executor cleanup. Adds Future, IO::Async, IO::Async::Loop::Ppoll and IO::Ppoll. | [CPAN](https://metacpan.org/dist/LibTmux-Async) · [API](https://libtmux.org/en/perl/latest/reference/libtmux-async-server/) · [POD](https://metacpan.org/pod/LibTmux::Async) |
| [LibTmux-Workspace](packages/workspace/README.md) | Validate, plan, and load JSON workspaces with a library or CLI. Uses core and the Perl standard library. | [CPAN](https://metacpan.org/dist/LibTmux-Workspace) · [API](https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace/) · [POD](https://metacpan.org/pod/LibTmux::Workspace) |

Each package has its own README, license, metadata, and runnable consumer
examples. Async closes its executor without destroying a borrowed tmux server.
Workspace uses public synchronous core APIs and does not require async.
Install either companion by module name; its declared core dependency is
installed automatically:

```console
$ cpm install \
    --global \
    LibTmux::Async
```

```console
$ cpm install \
    --global \
    LibTmux::Workspace
```

The `0.x` API can change between releases. Read each distribution's `Changes`
file before upgrading and pin versions in applications that need a fixed API.

Each heading below links to the distribution's directory on GitHub, where its
README lives.

### [`LibTmux`](https://github.com/libtmux/libtmux-perl/tree/master/packages/core): the library

[`Server`](https://libtmux.org/en/perl/latest/reference/libtmux-server/)
commands,
[`Snapshot`](https://libtmux.org/en/perl/latest/reference/libtmux-snapshot/)
graphs, and
[`Selection`](https://libtmux.org/en/perl/latest/reference/libtmux-selection/)
filters, on the Perl standard library at runtime.

[![LibTmux](https://img.shields.io/cpan/v/LibTmux?label=LibTmux)](https://metacpan.org/dist/LibTmux)
[API reference](https://libtmux.org/en/perl/latest/reference/) ·
[Guides](https://libtmux.org/en/perl/latest/guides/) ·
[CPAN](https://metacpan.org/dist/LibTmux) ·
[POD](https://metacpan.org/pod/LibTmux) ·
[Changes](packages/core/Changes)

### [`LibTmux-Async`](https://github.com/libtmux/libtmux-perl/tree/master/packages/async): Futures on a caller-owned loop

[`LibTmux::Async::Server`](https://libtmux.org/en/perl/latest/reference/libtmux-async-server/)
runs the core operations as Futures and awaits its executor's cleanup.

[![LibTmux-Async](https://img.shields.io/cpan/v/LibTmux-Async?label=LibTmux-Async)](https://metacpan.org/dist/LibTmux-Async)
[Guide](https://libtmux.org/en/perl/latest/guides/async/) ·
[API reference](https://libtmux.org/en/perl/latest/reference/libtmux-async-server/) ·
[CPAN](https://metacpan.org/dist/LibTmux-Async) ·
[POD](https://metacpan.org/pod/LibTmux::Async) ·
[Changes](packages/async/Changes)

### [`LibTmux-Workspace`](https://github.com/libtmux/libtmux-perl/tree/master/packages/workspace): JSON workspaces, with a CLI

[`LibTmux::Workspace`](https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace/)
and the `libtmux-workspace` command validate, plan, and load a workspace file.

[![LibTmux-Workspace](https://img.shields.io/cpan/v/LibTmux-Workspace?label=LibTmux-Workspace)](https://metacpan.org/dist/LibTmux-Workspace)
[Guide](https://libtmux.org/en/perl/latest/workspace/source-guide/) ·
[API reference](https://libtmux.org/en/perl/latest/workspace/reference/) ·
[CPAN](https://metacpan.org/dist/LibTmux-Workspace) ·
[POD](https://metacpan.org/pod/LibTmux::Workspace) ·
[Changes](packages/workspace/Changes)

## Run the examples and read the guides

[The examples index](examples/README.md) separates standalone installed-package
programs from repository qualification demos. The runner checks output,
cleanup, and preservation of borrowed sessions:

```console
$ mise exec -- make examples
```

Read [installation](docs/installation.md), [orchestration](docs/orchestration.md),
[filtering](docs/filtering.md), [graph identity](docs/graph.md),
[query planning](docs/query-planning.md), [async execution](docs/async.md),
[workspace loading](docs/workspace.md), and [errors and recovery](docs/errors.md).
Installed API documentation uses POD: `perldoc LibTmux::Server`.

[Compatibility](docs/compatibility.md) covers tmux 3.3a–3.8 inclusive; CI tests
only Perl 5.44 and the two tmux endpoints. Persistent control,
streaming subscriptions, tmux command chaining, serialized regexes, and relation
pushdown are deferred. [Architecture decisions](docs/dev/adr/index.md) explain
the contracts and costs.

[Contributing](.github/CONTRIBUTING.md) covers author setup and checks.
[Perl choices](.github/PERL.md) records dependency decisions;
[branding](docs/branding.md) describes the logos and social cards.

[server-new-session]: https://libtmux.org/en/perl/latest/reference/libtmux-server-new_session/
[selection-where]: https://libtmux.org/en/perl/latest/reference/libtmux-selection-where/
[server-send-text]: https://libtmux.org/en/perl/latest/reference/libtmux-server-send_text/
[filter]: https://libtmux.org/en/perl/latest/reference/libtmux-filter/
