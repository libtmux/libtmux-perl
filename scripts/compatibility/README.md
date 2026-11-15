# compatibility

Runs every integration suite and the runnable examples against one or more
tmux binaries and records the result as evidence. It rejects a binary whose
`-V` output does not match the version you name for it.

CI runs it in the `linux-tmux` and `native-artifacts` jobs of `scaffold.yml`.
Maintainers run it through `make compatibility`.

Pass each release as `VERSION=BINARY`. Each tmux runs in its own cell, in
parallel, and a command that runs longer than 25 seconds is killed with its
process group and recorded as status 124:

```console
$ perl scripts/compatibility/compatibility.pl 3.8=/path/to/tmux-3.8
```

The script writes one log per command and `evidence-VERSION.json`
(`evidence-all.json` for several versions) under `.cache/compatibility`.
`--installed PREFIX` runs the suites against a consumer prefix instead of the
checkout. It exits non-zero when any cell fails.

Test it against a fake checkout and a fake tmux:

```console
$ prove -Iscripts/lib scripts/compatibility/tests
```
