<!-- libtmux-logo -->
<div align="center">
  <picture>
    <source srcset="assets/logo.svg" type="image/svg+xml">
    <img src="assets/logo.png" width="128" height="128" alt="libtmux for Perl">
  </picture>
</div>
<!-- /libtmux-logo -->

<div align="center">

# LibTmux

Drive tmux from Perl: [create sessions][server-new-session],
[type into panes][server-send-text], and
[filter what tmux holds][selection-where] with ordinary arrays.

[![LibTmux](https://img.shields.io/cpan/v/LibTmux?label=LibTmux)](https://metacpan.org/dist/LibTmux)
[![libtmux.org](https://img.shields.io/badge/docs-libtmux.org-0b7285)](https://libtmux.org/en/perl/)

</div>

It needs only the Perl standard library at runtime.

[Quick start](#quick-start) ·
[Find things](#find-sessions-windows-and-panes) ·
[Send input](#send-input-and-run-commands) ·
[Plan a query](#plan-a-query) ·
[Documentation](https://libtmux.org/en/perl/) ·
[Guide](https://libtmux.org/en/perl/latest/guides/) ·
[API reference](https://libtmux.org/en/perl/latest/reference/) ·
[CPAN](https://metacpan.org/dist/LibTmux) ·
[POD](https://metacpan.org/pod/LibTmux)

## Install

Install with [cpm](https://github.com/skaji/cpm):

```console
$ cpm install \
    --global \
    LibTmux
```

It needs:

- **Perl 5.44 or newer.**
- **tmux 3.3a or newer.**
- **Linux on x86-64, including WSL.**

The `0.x` API can change between releases; read `Changes` before upgrading.
More: [installation guide](https://github.com/libtmux/libtmux-perl/blob/master/docs/installation.md).

## Quick start

### [`Server->new_session`][server-new-session]: create and inspect a session

Create a session, split its window, add another, and read the result. The
program runs its own tmux server and removes it on exit. Run
[examples/quickstart.pl](examples/quickstart.pl) from this directory after
installation:

```console
$ perl examples/quickstart.pl
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

It prints:

```text
editor: 2 panes
logs: 1 pane
```

[`Server`][server] owns every command. The captured [`Snapshot`][snapshot]
stays readable after its session is gone.

## Find sessions, windows and panes

### [`Selection->where`][selection-where]: filter panes with ordinary Perl

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

### [`Filter->matches`][filter-matches]: reuse a filter with ordinary hash records

A [`Filter`][filter] works without a tmux server. Run
[examples/filters.pl](examples/filters.pl):

```console
$ perl examples/filters.pl
```

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

It selects `%1`. Save and restore it as versioned JSON:

<!-- example: packages/core/examples/filters.pl#wire -->
```perl
my $restored = LibTmux::Filter->from_json($filter->to_json);
say 'restored filter matches: ',
    scalar grep { $restored->matches($_) } @records;

```

It prints `restored filter matches: 1`.

## Send input and run commands

### [`Server->send_text`][server-send-text]: send text, capture output, and set environment

[`send_text`][server-send-text] types literal text and
[`send_keys`][server-send-keys] takes tmux key names.
[`capture_pane`][server-capture-pane] reads the screen, and
[`set_option`][server-set-option] and [`get_option`][server-get-option] read
and write options. Run [examples/input.pl](examples/input.pl):

```console
$ perl examples/input.pl
```

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

## Plan a query

### [`Server->explain_panes`][server-explain-panes]: see what runs in tmux and what stays local

[`explain_panes`][server-explain-panes] builds a [`QueryPlan`][queryplan]
without any I/O, and [`query_panes`][server-query-panes] runs the same
criteria. Run [examples/explain.pl](examples/explain.pl):

```console
$ perl examples/explain.pl
```

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

## Navigate links and handle failures

### [`LibTmux::WindowLink`][window-link]: one window, several sessions

- A physical window can belong to several sessions; `WindowLink` holds its
  index and active state in each.
- `Pane->window` is always the captured physical window.
- A new snapshot sees later state; a held handle keeps the graph it captured.

### [`LibTmux::X`][x]: typed exceptions

- Failures are typed exceptions with causes and bounded process output.
- A failed command never becomes an empty selection.
- Raw IDs address current resources; captured targets detect a restart.

More: [filtering](https://libtmux.org/en/perl/latest/guides/filtering/),
[graph](https://libtmux.org/en/perl/latest/guides/graph/) and
[error](https://libtmux.org/en/perl/latest/guides/errors/) guides.
Installed POD:

```console
$ perldoc LibTmux::Server
```

## Add async execution or workspace loading

- [LibTmux-Async](https://github.com/libtmux/libtmux-perl/tree/master/packages/async):
  Future-returning operations on your own event loop.
- [LibTmux-Workspace](https://github.com/libtmux/libtmux-perl/tree/master/packages/workspace):
  JSON workspaces loaded through these public APIs.

Core loads neither. Every runnable program is listed in the
[examples index](https://github.com/libtmux/libtmux-perl/blob/master/examples/README.md).

## What it leaves out

- **Control mode.** No persistent connection or subscriptions.
- **Command chaining.** `batch` makes separate tmux calls, not one command list.

[server]: https://libtmux.org/en/perl/latest/reference/libtmux-server/
[server-new-session]: https://libtmux.org/en/perl/latest/reference/libtmux-server-new_session/
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
[filter-matches]: https://libtmux.org/en/perl/latest/reference/libtmux-filter-matches/
[window-link]: https://libtmux.org/en/perl/latest/reference/libtmux-windowlink/
[x]: https://libtmux.org/en/perl/latest/reference/libtmux-x/
