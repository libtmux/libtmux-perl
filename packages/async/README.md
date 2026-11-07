# LibTmux-Async

Optional Future-based execution for [LibTmux](../core). Requires Perl 5.44,
Future 0.54, IO::Async 0.805, Linux, and tmux 3.3a or newer. This development
distribution is not published on CPAN.

```perl
use v5.44;
use IO::Async::Loop;
use LibTmux::Async::Server;

my $loop = IO::Async::Loop->new;
my $server = LibTmux::Async::Server->new(
    loop => $loop, socket_name => 'example',
);
my $capture = $server->snapshot;
$loop->await($capture);
my $active = $capture->get->panes->where({ active => true });
$loop->await($server->close);
```

The caller owns and drives the loop. Each operation yields one Future value.
Core owns command preparation, framing, graph identity, and parsing. Filtering
captured selections remains synchronous and local. Cancellation requests process
cleanup; only successful `close` completion proves cleanup finished. Closing a
facade preserves the tmux server and borrowed loop.

Install the core archive first, then configure this directory and install its
explicit runtime dependencies. See the repository installation guide and
installed POD for `LibTmux::Async::Server` and `LibTmux::Async::Transport`.
`Future::AsyncAwait` is optional caller syntax, not a package requirement.
