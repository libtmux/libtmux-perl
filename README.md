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

Drive tmux from Perl: [create sessions][server-new-session],
[type into panes][server-send-text], and
[filter what tmux holds][selection-where] with ordinary arrays.

[![Perl checks](https://github.com/libtmux/libtmux-perl/actions/workflows/scaffold.yml/badge.svg)](https://github.com/libtmux/libtmux-perl/actions/workflows/scaffold.yml)
[![LibTmux](https://img.shields.io/cpan/v/LibTmux?label=LibTmux)](https://metacpan.org/dist/LibTmux)
[![libtmux.org](https://img.shields.io/badge/docs-libtmux.org-0b7285)](https://libtmux.org/en/perl/)
[![license](https://img.shields.io/badge/license-MIT-blue)](https://github.com/libtmux/libtmux-perl/blob/master/LICENSE)

</div>

The core needs only the Perl standard library at runtime. Async and workspace
ship as separate packages under [Choose a package](#choose-a-package).

Install the core with [cpm](https://github.com/skaji/cpm):

```console
$ cpm install \
    --global \
    LibTmux
```

It needs:

- **Perl 5.44 or newer.**
- **tmux 3.3a or newer.**
- **Linux on x86-64, including WSL.** See [compatibility](docs/compatibility.md).

The `0.x` API can change between releases. Each distribution's `Changes` file
marks the breaks; pin a version in applications.

**Contents** — [Quick start](#quick-start) ·
[Find things](#find-sessions-windows-and-panes) ·
[Send input](#send-input-and-run-commands) ·
[Plan a query](#plan-a-query) ·
[Packages](#choose-a-package) ·
[Examples](#run-the-examples-and-read-the-guides) ·
[Leaves out](#what-it-leaves-out) · [Support](#support-and-status)

[Documentation](https://libtmux.org/en/perl/) ·
[Guides](https://libtmux.org/en/perl/latest/guides/) ·
[API reference](https://libtmux.org/en/perl/latest/reference/) ·
[CPAN](https://metacpan.org/dist/LibTmux)

## Quick start

### [`Server->new_session`][server-new-session]: create a session and arrange its windows

Create a session, [split its window][server-split-pane],
[resize the new pane][server-resize-pane], add another window, and read the
result. The program runs its own tmux server and removes it on exit:

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
my ($session, $snapshot, $side, $failure);
try {
    $session = $server->new_session(
        name    => 'perl-quickstart',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    $side = $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $server->resize_pane(pane => $side, width => 20);
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
say 'side pane: ', $snapshot->pane_by_id($side->id)->width, ' columns';
```

It prints:

```text
editor: 2 panes
logs: 1 pane
side pane: 20 columns
```

To run it, save it as `quickstart.pl`:

```console
$ perl quickstart.pl
```

[`Server`][server] owns every command, and `new_session` starts tmux when none
is running. The captured [`Snapshot`][snapshot] stays readable after its
session is gone. [`kill_session`][server-kill-session],
[`kill_window`][server-kill-window], [`kill_pane`][server-kill-pane] and
[`kill_server`][server-kill-server] remove what you created.

Pass a socket path to join a server of your own: the program then removes only
the session it created, and an existing session with the same name is an error.

More: [orchestration guide](docs/orchestration.md).

## Find sessions, windows and panes

### [`Selection->where`][selection-where]: filter with criteria and Perl callbacks

A [`Selection`][selection] is a blessed array reference: `where`, `grep` and
`map` chain without another tmux call.

<!-- example: packages/core/examples/select.pl -->
```perl
use v5.44;
use File::Temp ();
use LibTmux::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => "$private/tmux.sock",
    config_file => '/dev/null',
);
my $failure;
try {
    my $session = $server->new_session(
        name    => 'perl-select',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $editor = $session->window_links->one->window;
    $server->rename_window(window => $editor, name => 'editor');
    $server->split_pane(
        pane       => $editor->panes->one,
        horizontal => true,
        command    => [$^X, '-e', 'while (<STDIN>) { print }'],
    );

    my $snapshot = $server->snapshot;
    my $panes =
        $snapshot->windows->one({name => 'editor'})
        ->panes->where({width => {-gte => 1}})
        ->grep(sub ($pane) { $pane->height > 0 });
    my $active = $panes->one({active => true});
    say 'editor panes: ',          $panes->count;
    say 'active pane belongs to ', $active->window->name;

    # example: begin nomatch
    try { $panes->one({width => {-gt => 10_000}}) }
    catch ($error) {
        die $error unless $error isa LibTmux::X::NoMatch;
        say 'no pane is that wide';
    }

    # example: end nomatch
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
```

It prints:

```text
editor panes: 2
active pane belongs to editor
no pane is that wide
```

`one` throws on none or several matches; `one_or_undef` returns undef for none.

More: [filtering guide](docs/filtering.md).

### [`LibTmux::Filter`][filter]: save a reusable filter

A [`Filter`][filter] compiles criteria once, matches plain hash records
without tmux, and round-trips through versioned JSON:

<!-- example: packages/core/examples/filters.pl#records -->
```perl
use v5.44;
use LibTmux::Filter;

my $filter = LibTmux::Filter->new(
    entity => 'pane',
    where  => {
        active          => true,
        current_command => {-in  => [qw(perl vim)]},
        width           => {-gte => 80},
    },
);
my @records = (
    {id => '%1', active => true,  current_command => 'perl', width => 120},
    {id => '%2', active => false, current_command => 'perl', width => 120},
    {id => '%3', active => true,  current_command => 'vim',  width => 40},
);
my @matches = grep { $filter->matches($_) } @records;
say 'matching records: ', join ', ', map { $_->{id} } @matches;

```

It prints `matching records: %1`. Save and restore it:

<!-- example: packages/core/examples/filters.pl#wire -->
```perl
my $restored = LibTmux::Filter->from_json($filter->to_json);
say 'restored filter matches: ',
    scalar grep { $restored->matches($_) } @records;

```

It prints `restored filter matches: 1`. Regular expressions work in callbacks,
not in the JSON.

More: [filtering guide](docs/filtering.md).

## Send input and run commands

### [`Server->send_text`][server-send-text]: send text, capture output, and set environment

[`send_text`][server-send-text] types literal text and
[`send_keys`][server-send-keys] takes tmux key names.
[`capture_pane`][server-capture-pane] reads the screen, and
[`set_option`][server-set-option] and [`get_option`][server-get-option] read
and write options:

<!-- example: packages/core/examples/input.pl -->
```perl
use v5.44;
use File::Temp ();
use LibTmux::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $server  = LibTmux::Server->new(
    socket_path => "$private/tmux.sock",
    config_file => '/dev/null',
);
my $failure;
try {
    my $session = $server->new_session(
        name    => 'perl-input',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    my $pane = $session->window_links->one->window->panes->one;

    $server->send_text(
        pane  => $pane,
        text  => 'hello from Perl',
        enter => true
    );
    print $server->capture_pane(pane => $pane, start => -100) =~ s/\n+\z/\n/r;
    $server->set_environment(
        session => $session,
        name    => 'PROJECT',
        value   => 'api',
    );
    say 'PROJECT=',
        $server->get_environment(session => $session, name => 'PROJECT');
    my %build = (scope => 'session', target => $session->id, name => '@build');
    $server->set_option(%build, value => 'ok');
    say '@build=', $server->get_option(%build);

    # example: begin batch
    my $batch = $server->batch(
        [
            ['display-message', '-p', '-t', $pane->id, '#{session_name}'],
            ['display-message', '-p', '-t', $pane->id, '#{pane_index}'],
        ]
    );
    for my $entry ($batch->@*) {
        die $entry->{error} if defined $entry->{error};
        print $entry->{result}->stdout;
    }

    # example: end batch
}
catch ($error) { $failure = $error }

# The server is private, so stopping it removes everything the program made.
try { $server->kill_server }
catch ($error) { $failure //= $error unless $error isa LibTmux::X::NoServer }
die $failure if defined $failure;
```

It prints:

```text
hello from Perl
hello from Perl
PROJECT=api
@build=ok
perl-input
0
```

Tmux accepting a command does not mean the pane finished. Capture again until
the screen shows what you expect. [`set_hook`][server-set-hook] and
[`show_hooks`][server-show-hooks] write and read hooks.

More: [orchestration guide](docs/orchestration.md).

### [`Server->batch`][server-batch]: run several commands, keep each result

[`batch`][server-batch] takes argv arrays and returns one `{result, error}`
record per command, in order. A failing command does not stop the rest.

<!-- example: packages/core/examples/input.pl#batch -->
```perl
my $batch = $server->batch(
    [
        ['display-message', '-p', '-t', $pane->id, '#{session_name}'],
        ['display-message', '-p', '-t', $pane->id, '#{pane_index}'],
    ]
);
for my $entry ($batch->@*) {
    die $entry->{error} if defined $entry->{error};
    print $entry->{result}->stdout;
}

```

It prints the session name and the pane index: `perl-input`, then `0`.

More: [orchestration guide](docs/orchestration.md).

## Plan a query

### [`Server->explain_panes`][server-explain-panes]: see what runs in tmux and what stays local

[`explain_panes`][server-explain-panes] builds a [`QueryPlan`][queryplan]
without any I/O. [`query_panes`][server-query-panes] runs the same criteria
against tmux. Its `pushdown` switch is `auto`, `never` or `require`.

<!-- example: packages/core/examples/explain.pl -->
```perl
use v5.44;
use LibTmux::Server;

# Planning does no I/O, so this program needs no tmux server.
my $server = LibTmux::Server->new;

my $criteria = {active => true, width => {-gte => 1}};
my $plan     = $server->explain_panes(where => $criteria);
say 'tmux filter: ', $plan->to_data->{native_filter};

my $relation = {window => {-is => {name => 'editor'}}};
my $residual = $server->explain_panes(where => $relation);
say 'stays local: ', $residual->to_data->{residual_reasons}[0];

my $never = $server->explain_panes(where => $criteria, pushdown => 'never');
say 'pushdown off: ', $never->summary;
```

It prints:

```text
tmux filter: #{&&:#{==:#{pane_active},1},#{e|>=:#{pane_width},1}}
stays local: window requires local relation, byte, null, or unavailable-field semantics
pushdown off: local evaluation; pushdown disabled
```

Perl always computes the result; tmux only double-checks what it can express.

More: [query planning guide](docs/query-planning.md).

## Choose a package

| Distribution | Use it for | Package and API |
| --- | --- | --- |
| [LibTmux](packages/core/README.md) | Commands, snapshots, graph navigation, filtering, options and environment. | [CPAN](https://metacpan.org/dist/LibTmux) · [API](https://libtmux.org/en/perl/latest/reference/) · [POD](https://metacpan.org/pod/LibTmux) |
| [LibTmux-Async](packages/async/README.md) | Concurrent Future-returning operations and explicit executor cleanup. | [CPAN](https://metacpan.org/dist/LibTmux-Async) · [API](https://libtmux.org/en/perl/latest/reference/libtmux-async-server/) · [POD](https://metacpan.org/pod/LibTmux::Async) |
| [LibTmux-Workspace](packages/workspace/README.md) | Validate, plan, and load JSON workspaces with a library or CLI. | [CPAN](https://metacpan.org/dist/LibTmux-Workspace) · [API](https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace/) · [POD](https://metacpan.org/pod/LibTmux::Workspace) |

Companions install by module name, and cpm adds the core for you:

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

### [`LibTmux`](https://github.com/libtmux/libtmux-perl/tree/master/packages/core): the library

[`Server`](https://libtmux.org/en/perl/latest/reference/libtmux-server/)
commands,
[`Snapshot`](https://libtmux.org/en/perl/latest/reference/libtmux-snapshot/)
graphs, and
[`Selection`](https://libtmux.org/en/perl/latest/reference/libtmux-selection/)
filters.

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

[The examples index](examples/README.md) lists every runnable program. Run them
all from a checkout:

```console
$ mise exec -- make examples
```

- [Installation](docs/installation.md): from CPAN or a checkout
- [Orchestration](docs/orchestration.md): create, arrange, type, capture
- [Filtering](docs/filtering.md): criteria, quantifiers, wire format
- [Graph identity](docs/graph.md): snapshots and linked windows
- [Query planning](docs/query-planning.md): what tmux runs and what stays local
- [Async execution](docs/async.md): Futures on your own loop
- [Workspace loading](docs/workspace.md): JSON workspaces and the CLI
- [Errors and recovery](docs/errors.md): typed exceptions
- [Compatibility](docs/compatibility.md): supported platforms

Installed API documentation uses POD:

```console
$ perldoc LibTmux::Server
```

## What it leaves out

- **Control mode.** No persistent connection or subscriptions.
- **Command chaining.** `batch` makes separate tmux calls, not one command list.
- **Serialized regexes.** Regular expressions work in callbacks only.
- **Relation pushdown.** Relation criteria are always checked in Perl.

## Support and status

- **The `0.x` API can change.** Read each `Changes` file before upgrading.
- **Standard library at runtime.** Async adds Future, IO::Async and IO::Ppoll.
- **Linux on x86-64, including WSL.** Other systems are untested.

[Contributing](.github/CONTRIBUTING.md) covers author setup and checks.
[Perl choices](.github/PERL.md) records dependency decisions,
[architecture decisions](docs/dev/adr/index.md) explain the contracts, and
[branding](docs/branding.md) describes the logos and social cards.

[server]: https://libtmux.org/en/perl/latest/reference/libtmux-server/
[server-new-session]: https://libtmux.org/en/perl/latest/reference/libtmux-server-new_session/
[server-split-pane]: https://libtmux.org/en/perl/latest/reference/libtmux-server-split_pane/
[server-resize-pane]: https://libtmux.org/en/perl/latest/reference/libtmux-server-resize_pane/
[server-kill-session]: https://libtmux.org/en/perl/latest/reference/libtmux-server-kill_session/
[server-kill-window]: https://libtmux.org/en/perl/latest/reference/libtmux-server-kill_window/
[server-kill-pane]: https://libtmux.org/en/perl/latest/reference/libtmux-server-kill_pane/
[server-kill-server]: https://libtmux.org/en/perl/latest/reference/libtmux-server-kill_server/
[server-set-hook]: https://libtmux.org/en/perl/latest/reference/libtmux-server-set_hook/
[server-show-hooks]: https://libtmux.org/en/perl/latest/reference/libtmux-server-show_hooks/
[server-send-text]: https://libtmux.org/en/perl/latest/reference/libtmux-server-send_text/
[server-send-keys]: https://libtmux.org/en/perl/latest/reference/libtmux-server-send_keys/
[server-capture-pane]: https://libtmux.org/en/perl/latest/reference/libtmux-server-capture_pane/
[server-set-option]: https://libtmux.org/en/perl/latest/reference/libtmux-server-set_option/
[server-get-option]: https://libtmux.org/en/perl/latest/reference/libtmux-server-get_option/
[server-batch]: https://libtmux.org/en/perl/latest/reference/libtmux-server-batch/
[server-explain-panes]: https://libtmux.org/en/perl/latest/reference/libtmux-server-explain_panes/
[server-query-panes]: https://libtmux.org/en/perl/latest/reference/libtmux-server-query_panes/
[queryplan]: https://libtmux.org/en/perl/latest/reference/libtmux-queryplan/
[snapshot]: https://libtmux.org/en/perl/latest/reference/libtmux-snapshot/
[selection]: https://libtmux.org/en/perl/latest/reference/libtmux-selection/
[selection-where]: https://libtmux.org/en/perl/latest/reference/libtmux-selection-where/
[filter]: https://libtmux.org/en/perl/latest/reference/libtmux-filter/
