# count-tmux-process

Stands in for the tmux executable in `scripts/benchmark.pl`. It appends the
mode, the command's process id and its supervisor's process id as one JSON
line to `LIBTMUX_BENCH_LOG`, then replaces itself with `LIBTMUX_BENCH_TMUX` and
the same arguments. The log therefore counts the processes each mode starts.

`benchmark.pl` sets `LIBTMUX_BENCH_MODE`, `LIBTMUX_BENCH_TMUX` and
`LIBTMUX_BENCH_LOG` and runs the script. The script creates the
log with mode 0600.

Test it:

```console
$ prove -Iscripts/lib scripts/count-tmux-process/tests
```
