---
title: Linux compatibility and qualification
description: Linux compatibility and qualification with the Perl libtmux distributions.
---

The baseline is stable Perl 5.44.0 on Linux x86_64 LP64, including WSL. Plain
tmux 3.3 is below the support floor; its separate rejection gate must pass.
Other operating systems and Linux ABIs have not been qualified. The supervisor
refuses unsupported ABIs before dispatch instead of assuming syscall numbers.

Required tmux cells: 3.3a, 3.4, 3.5, 3.5a, 3.6, 3.6a, 3.6b, 3.7, 3.7a, 3.7b,
3.7c, and 3.8. [The source lock](../scripts/tmux-lock.json) pins official assets,
archive hashes, source commits, and configure flags. Per-build provenance adds
compiler and executable hashes. Exact per-cell results are recorded by the
compatibility command; a missing or skipped cell remains unverified.

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
