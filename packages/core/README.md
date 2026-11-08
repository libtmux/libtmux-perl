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

</div>

Explicit tmux commands and captured graph filtering for stable Perl 5.44.0.
The runtime uses only the Perl standard library. Linux x86_64 LP64, including
WSL, is the qualified execution ABI; other platforms/ABIs are unsupported.
The development distribution is not published on CPAN.

```perl
use v5.44;
use LibTmux::Server;
my $server = LibTmux::Server->new(socket_name => 'example');
my $snapshot = $server->snapshot;
my $active = $snapshot->panes->where({ active => true });
my @ids = map { $_->id } $active->@*;
```

A snapshot captures an interval of observations, with one physical Window/Pane
per identity and a separate WindowLink for every session/index association.
Relationships and Selection queries stay local. Use `where` for validated
data and `grep` for one-argument Perl callbacks. `one` and `one_or_undef`
distinguish absence from ambiguity. Errors are typed objects with causes and
process diagnostics; operational failures do not become empty results.

The optional LibTmux-Async distribution adds Future-returning operations;
LibTmux-Workspace uses these synchronous public core APIs for JSON loading.
Neither dependency is loaded by core. MCP is excluded.

Read installed POD for `LibTmux::Server`, `LibTmux::Snapshot`,
`LibTmux::Selection`, and `LibTmux::Filter`, or the repository's
[installation and reader guides](https://github.com/libtmux/libtmux-perl/tree/master/docs).
Each native archive owns its metadata, test requirements, README, and license.
