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

Run tmux operations as Futures on an event loop you own, and await their
cleanup.

[![LibTmux-Async](https://img.shields.io/cpan/v/LibTmux-Async?label=LibTmux-Async)](https://metacpan.org/dist/LibTmux-Async)
[![libtmux.org](https://img.shields.io/badge/docs-libtmux.org-0b7285)](https://libtmux.org/en/perl/latest/guides/async/)

</div>

It builds on the public
[LibTmux core](https://github.com/libtmux/libtmux-perl/tree/master/packages/core),
and captured results stay ordinary synchronous core objects.

[Run the example](#libtmuxasyncserver-create-a-session-and-run-concurrent-operations) ·
[Cancellation](#server-close-cancel-work-and-finish-cleanup) ·
[Documentation](https://libtmux.org/en/perl/) ·
[Guide](https://libtmux.org/en/perl/latest/guides/async/) ·
[API reference](https://libtmux.org/en/perl/latest/reference/libtmux-async-server/) ·
[CPAN](https://metacpan.org/dist/LibTmux-Async) ·
[POD](https://metacpan.org/pod/LibTmux::Async)

## Install

Install with [cpm](https://github.com/skaji/cpm); it installs the core too:

```console
$ cpm install \
    --global \
    LibTmux::Async
```

It needs:

- **Perl 5.44 or newer.**
- **tmux 3.3a or newer.**
- **Linux on x86-64, including WSL.**
- **Future, IO::Async and IO::Ppoll.** IO::Ppoll needs a C compiler.

The `0.x` API can change between releases; read `Changes` before upgrading.
More: [installation guide](https://github.com/libtmux/libtmux-perl/blob/master/docs/installation.md).

## Run concurrent operations

### [`LibTmux::Async::Server`][async-server]: create a session and run concurrent operations

Create a session, start independent operations, and await them together. The
program runs its own tmux server and removes it on exit. Run
[examples/concurrent.pl](examples/concurrent.pl) from this directory after
installation:

```console
$ perl examples/concurrent.pl
```

<!-- example: packages/async/examples/concurrent.pl -->
```perl
# example: begin connect
use v5.44;
use File::Temp ();
use IO::Async::Loop::Ppoll;
use Future;
use LibTmux::Async::Server;

my $private = File::Temp->newdir('libtmux-perl-XXXXXX', TMPDIR => 1);
my $socket  = shift @ARGV // "$private/tmux.sock";
my $tmux    = shift @ARGV // 'tmux';

my $loop   = IO::Async::Loop::Ppoll->new;
my $server = LibTmux::Async::Server->new(
    loop           => $loop,
    socket_path    => $socket,
    executable     => $tmux,
    config_file    => '/dev/null',
    max_concurrent => 2,
    max_queue      => 8,
);

# example: end connect
my ($session, $failure);
try {
    my $created = $server->new_session(
        name    => 'perl-async',
        command => [$^X, '-e', 'while (<STDIN>) { print }'],
    );
    $loop->await($created);
    $session = $created->get;

    # example: begin concurrent
    my $capture = $server->snapshot;
    my $version = $server->cmd('display-message', '-p', '#{version}');
    $loop->await(Future->needs_all($capture, $version));
    my $snapshot = $capture->get;
    my $panes    = $snapshot->sessions->one({name => 'perl-async'})
        ->window_links->one->window->panes->where({active => true});
    say 'async active panes: ', $panes->count;
    say 'tmux version: ',       $version->get->stdout;

    # example: end concurrent
    die 'async session missing pane' unless $panes->count == 1;

    # example: begin batch
    my $batch = $server->batch(
        [
            ['display-message', '-p', 'first'],
            ['display-message', '-p', 'second'],
        ]
    );
    $loop->await($batch);
    my $results = $batch->get;
    for my $entry ($results->@*) {
        die $entry->{error} if defined $entry->{error};
        print $entry->{result}->stdout;
    }

    # example: end batch
    die 'batch order changed'
        unless $results->[0]{result}->stdout eq "first\n"
        && $results->[1]{result}->stdout eq "second\n";
}
catch ($error) {
    $failure = $error;
    $session //= $error->created if $error isa LibTmux::X::Creation;
}
if ($session) {
    try {
        my $removed = $server->kill_session(session => $session);
        $loop->await($removed);
        $removed->get;
    }
    catch ($cleanup) {
        warn "session cleanup failed: $cleanup\n";
        $failure //= $cleanup;
    }
}

# example: begin close
my $closed = $server->close;
$loop->await($closed);
try { $closed->get }
catch ($cleanup) {
    warn "executor cleanup failed: $cleanup\n";
    $failure //= $cleanup;
}
die $failure if defined $failure;
say 'async operations and cleanup: ok';

# example: end close
```

It prints the active pane count, your tmux version, `first` and `second`, and
`async operations and cleanup: ok`.

- [`Future->needs_all`](https://metacpan.org/pod/Future#needs_all) lets
  independent requests overlap.
- `batch` keeps request order and returns a `{result, error}` entry for each
  command.

More: [async guide](https://libtmux.org/en/perl/latest/guides/async/).

## Cancel and clean up

### [`Server->close`][server-close]: cancel work and finish cleanup

- Cancelling a Future requests cleanup; it does not undo accepted effects.
- Only the Future from [`close`][server-close] proves cleanup finished. Keep
  driving the loop until it completes.
- Closing leaves a borrowed tmux server alone.

The
[lifecycle program](https://github.com/libtmux/libtmux-perl/blob/master/examples/async-lifecycle.pl)
adds failure and cancellation against an existing socket.

More: [async guide](https://libtmux.org/en/perl/latest/guides/async/).

## Tune the loop

### [`Server->new`][server-new]: choose bounds and caller syntax

- Pass an `IO::Async::Loop::Ppoll` you build; other loop backends are rejected.
- `max_concurrent` bounds running subprocesses; `max_queue` bounds waiting
  requests.
- `Future::AsyncAwait` is optional caller syntax.

Installed POD:

```console
$ perldoc LibTmux::Async::Server
```

## What it leaves out

- **Control mode.** No persistent connection or subscriptions.
- **Other loops.** Only `IO::Async::Loop::Ppoll` is supported.

[async-server]: https://libtmux.org/en/perl/latest/reference/libtmux-async-server/
[server-close]: https://libtmux.org/en/perl/latest/reference/libtmux-async-server-close/
[server-new]: https://libtmux.org/en/perl/latest/reference/libtmux-async-server-new/
