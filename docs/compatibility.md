---
title: Linux compatibility and qualification
description: Linux compatibility and qualification with the Perl libtmux distributions.
---

The baseline is stable Perl 5.44.0 on Linux x86_64 LP64, including WSL. Plain
tmux 3.3 is below the 3.3a support floor.
Other operating systems and Linux ABIs have not been qualified. The supervisor
refuses unsupported ABIs before dispatch instead of assuming syscall numbers.

CI and the local compatibility command use only the latest stable Perl and
two tmux releases: the oldest supported release and the newest stable release.
The current pins are [Perl 5.44.0](https://dev.perl.org/perl5/), tmux 3.3a,
and [tmux 3.8](https://github.com/tmux/tmux/releases/tag/3.8), verified on
2026-11-08. Intermediate tmux releases and older Perl releases have no matrix
cells. Update the pins when the latest stable release changes.

[The source lock](../scripts/tmux-lock.json) pins official assets,
archive hashes, source commits, and configure flags. Per-build provenance adds
compiler and executable hashes. Exact per-cell results are recorded by the
compatibility command; a missing or skipped cell remains unverified.
Earlier wider matrix runs remain historical evidence for their recorded
revisions; they do not add current completion gates.

```console
$ mise exec -- make compatibility
```

The original 3.3a run exposed tmux's invalid-layout error-pointer defect.
The public select_layout wrapper now rejects unknown/ambiguous names lacking
a custom-layout checksum prefix before dispatch. The raw command escape hatch
retains native behavior. See the contributor guide for archive consumers,
examples, units, and the network-free check/provision split.

A local test or build is not hosted CI, a CPAN publication, or a deployed site.
No unrun final-revision gate is implied by these requirements.
