<!-- libtmux-logo -->
<div align="center">
  <picture>
    <source srcset="assets/logo.svg" type="image/svg+xml">
    <img src="assets/logo.png" width="128" height="128" alt="libtmux for Perl">
  </picture>
</div>
<!-- /libtmux-logo -->

<div align="center">

# LibTmux-Async

</div>

LibTmux-Async adds Future-based execution to
[LibTmux](https://github.com/libtmux/libtmux-perl/tree/master/packages/core).
Requires Perl 5.44,
Future 0.54, IO::Async 0.805, IO::Async::Loop::Ppoll 0.10, IO::Ppoll 0.14,
and Linux x86_64 LP64. The Perl and module versions are minimum requirements.
Supported tmux versions span 3.3a–3.8, including intermediate releases; CI
tests the endpoints.
IO::Ppoll includes an XS extension. This development
distribution is not published on CPAN.

[Install from source](https://github.com/libtmux/libtmux-perl/blob/master/docs/installation.md) ·
[API reference](https://libtmux.org/en/perl/latest/reference/libtmux-async-server/) ·
[Examples](https://github.com/libtmux/libtmux-perl/blob/master/examples/README.md)

To capture an existing tmux server named `example`:

```perl
use v5.44;
use IO::Async::Loop::Ppoll;
use LibTmux::Async::Server;

my $loop = IO::Async::Loop::Ppoll->new;
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

The [complete lifecycle example](https://github.com/libtmux/libtmux-perl/blob/master/examples/async-lifecycle.pl)
uses installed packages, preserves operation failures, reports cleanup failures
separately, and demonstrates cancellation. Always drive `close` to successful
completion before leaving the loop.

Install the core archive first, then configure this directory and install its
explicit runtime dependencies. Read the
[async guide](https://libtmux.org/en/perl/latest/guides/async/) and installed
POD for `LibTmux::Async::Server` and `LibTmux::Async::Transport`.
`Future::AsyncAwait` is optional caller syntax, not a package requirement.
