<!-- libtmux-logo -->
<div align="center">
  <picture>
    <source srcset="assets/logo.svg" type="image/svg+xml">
    <img src="assets/logo.png" width="128" height="128" alt="libtmux for Perl workspace">
  </picture>
</div>
<!-- /libtmux-logo -->

<div align="center">

# LibTmux-Workspace

Describe sessions, windows and panes in JSON, check the plan, then load it
into tmux from Perl or the command line.

[![LibTmux-Workspace](https://img.shields.io/cpan/v/LibTmux-Workspace?label=LibTmux-Workspace)](https://metacpan.org/dist/LibTmux-Workspace)
[![libtmux.org](https://img.shields.io/badge/docs-libtmux.org-0b7285)](https://libtmux.org/en/perl/latest/workspace/)

</div>

It uses the public
[LibTmux core APIs](https://libtmux.org/en/perl/latest/reference/libtmux-server/)
and adds no runtime dependency beyond the Perl standard library.

[CLI example](#workspace-plan-validate-plan-and-load-a-workspace) ·
[Perl example](#workspace-load-load-and-inspect-from-perl) ·
[Documentation](https://libtmux.org/en/perl/) ·
[Guide](https://libtmux.org/en/perl/latest/workspace/source-guide/) ·
[API reference](https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace/) ·
[CPAN](https://metacpan.org/dist/LibTmux-Workspace) ·
[POD](https://metacpan.org/pod/LibTmux::Workspace)

## Install

Install the library and the `libtmux-workspace` command with
[cpm](https://github.com/skaji/cpm); it installs the core too:

```console
$ cpm install \
    --global \
    LibTmux::Workspace
```

It needs:

- **Perl 5.44 or newer.**
- **tmux 3.3a or newer.**
- **Linux on x86-64, including WSL.**

The `0.x` API and workspace format can change between releases; read `Changes`
before upgrading.
More: [installation guide](https://github.com/libtmux/libtmux-perl/blob/master/docs/installation.md).

## Validate, plan and load from the command line

### [`Workspace->plan`][workspace-plan]: validate, plan, and load a workspace

The packaged [examples/workspace.json](examples/workspace.json) describes two
windows and three panes:

<!-- example: packages/workspace/examples/workspace.json -->
```json
{
  "schema": "libtmux.workspace/v1",
  "environment": {"PROJECT": "api"},
  "sessions": [{
    "name": "perl-workspace",
    "windows": [{
      "name": "editor",
      "layout": "even-horizontal",
      "panes": [
        {"command": ["perl", "-e", "while (<STDIN>) { print }"]},
        {"command": ["perl", "-e", "while (<STDIN>) { print }"], "horizontal": true}
      ]
    }, {
      "name": "logs",
      "panes": [{"command": ["perl", "-e", "while (<STDIN>) { print }" ]}]
    }]
  }]
}
```

From this directory, validate the file and inspect its plan. Neither touches
tmux:

```console
$ libtmux-workspace validate examples/workspace.json
```

```console
$ libtmux-workspace plan examples/workspace.json
```

Load it on an explicit socket. An unused path starts a new server, and the
session keeps running afterwards:

```console
$ libtmux-workspace load examples/workspace.json \
    --socket-path "${TMPDIR:-/tmp}/libtmux-perl-workspace-$$.sock" \
    --existing skip
```

The command line has no stop verb. The next program loads and cleans up in
one run.

More: [workspace guide](https://libtmux.org/en/perl/latest/workspace/source-guide/).

## Load and inspect from Perl

### [`Workspace->load`][workspace-load]: load and inspect from Perl

Plan, load, inspect the graph, repeat with `skip`, and remove the session. The
program runs its own tmux server. Run [examples/load.pl](examples/load.pl) from
this directory:

```console
$ perl examples/load.pl
```

<!-- example: packages/workspace/examples/load.pl -->
```perl
# example: begin plan
use v5.44;
use FindBin;
use LibTmux::Workspace;

open my $in, '<:raw', "$FindBin::Bin/workspace.json" or die $!;
my $json = do { local $/; <$in> };
close $in or die $!;
my $workspace = LibTmux::Workspace->from_json($json);
my $plan      = $workspace->plan;
say 'planned sessions: ', scalar $plan->{sessions}->@*;
die 'plan must not mutate' if $plan->{mutates};

# example: end plan
use File::Temp ();
use LibTmux::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $socket  = shift @ARGV // "$private/tmux.sock";
my $tmux    = shift @ARGV // 'tmux';
my $server  = LibTmux::Server->new(
    socket_path => $socket,
    executable  => $tmux,
    config_file => '/dev/null',
);
my ($session, $failure);
try {
    # example: begin load
    my $report   = $workspace->load(server => $server);
    my $snapshot = $server->snapshot;
    $session = $snapshot->sessions->one({name => 'perl-workspace'});
    my $windows = $session->window_links;
    say 'loaded windows: ', $windows->count;
    my $editor = $windows->one({window => {-is => {name => 'editor'}}})->window;
    say 'editor panes: ', $editor->panes->count;

    # example: end load
    die 'workspace structure differs'
        unless $windows->count == 2 && $editor->panes->count == 2;

    # example: begin repeat
    my $again = $workspace->load(server => $server, existing => 'skip');
    say 'skipped existing sessions: ', scalar $again->{skipped}->@*;

    # example: end repeat
    die 'repeat did not skip' unless $again->{skipped}->@* == 1;
    die 'environment was not inherited'
        unless $server->get_environment(session => $session, name => 'PROJECT')
        eq 'api';
}
catch ($error) { $failure = $error }
if ($session) {
    try { $server->kill_session(session => $session) }
    catch ($cleanup) {
        warn "session cleanup failed: $cleanup\n";
        $failure //= $cleanup;
    }
}
die $failure if defined $failure;
say 'workspace plan, load, repeat: ok';
```

It prints:

```text
planned sessions: 1
loaded windows: 2
editor panes: 2
skipped existing sessions: 1
workspace plan, load, repeat: ok
```

## Handle conflicts and partial loads

### [`Workspace::X::Load`][workspace-load-error]: handle conflicts and partial effects

- All session-name conflicts are checked before anything is created.
- `skip` keeps whole existing sessions; it does not reconcile panes or layout.
- A failed load reports its completed steps, the failed step and the cause.
- Rollback removes only sessions that load created.
- Environment and working directory inherit down the levels; layout applies
  after splitting.

Exit status of the command line: 0 success, 2 usage or configuration, 3 load
failure, 4 conflict.

More: [workspace guide](https://libtmux.org/en/perl/latest/workspace/source-guide/).
Installed POD:

```console
$ perldoc LibTmux::Workspace
```

## What it leaves out

- **tmuxp files.** The `libtmux.workspace/v1` format is JSON, not tmuxp's.
- **Reconciling.** `skip` never changes an existing session.

[workspace-plan]: https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace-plan/
[workspace-load]: https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace-load/
[workspace-load-error]: https://libtmux.org/en/perl/latest/workspace/reference/libtmux-workspace-x-load/
