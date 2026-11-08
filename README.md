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

</div>

Control tmux with explicit commands, captured graphs, and ordinary Perl arrays.
Targets stable Perl 5.44.0 and Linux x86_64, including WSL. These development
distributions are not published on CPAN.

```perl
use v5.44;
use LibTmux::Server;

my $server = LibTmux::Server->new(socket_name => 'example');
my $snapshot = $server->snapshot;  # Explicit I/O; server must already exist.
my $active = $snapshot->panes
    ->where({ active => true, width => { -gte => 80 } })
    ->grep(sub ($pane) { $pane->current_command eq 'sleep' });

for my $pane ($active->@*) {
    say $pane->id, ' ', $pane->window->name;
}
```

| Distribution | Location | Runtime dependencies |
| --- | --- | --- |
| [`LibTmux`](packages/core/README.md) | [packages/core](packages/core) | Perl standard library. |
| [`LibTmux-Async`](packages/async/README.md) | [packages/async](packages/async) | Versioned core, Future, IO::Async; caller-owned loop. |
| [`LibTmux-Workspace`](packages/workspace/README.md) | [packages/workspace](packages/workspace) | Versioned core; packaged JSON loader CLI. |

Start with [installation](docs/installation.md),
[basic orchestration](docs/orchestration.md), and
[filtering](docs/filtering.md). Read [graph identity](docs/graph.md) before
working with linked windows, [query planning](docs/query-planning.md) for
explicit native filters, [errors and recovery](docs/errors.md),
[async execution](docs/async.md), and [workspace loading](docs/workspace.md).
Installed API documentation uses native POD; for example `perldoc
LibTmux::Server` and `perldoc LibTmux::Selection`.

[Complete examples](examples) run against uniquely owned tmux sockets and
assert results and cleanup. [Compatibility](docs/compatibility.md) records the
required release cells and qualification limits. Captured selections perform
no tmux I/O; their methods preserve order and duplicates and return one fixed
type in every calling context. Native array access remains available.

MCP is excluded. Persistent control mode, streaming APIs, tmux command lists,
serialized regexes, and relation pushdown are deferred. Package publication
and shared-site deployment require separate authority.

See [contributing](.github/CONTRIBUTING.md) for exact checks and tool setup,
[Perl choices](.github/PERL.md) for source-backed decisions, and
[branding assets](docs/branding.md) for logos and social cards.
