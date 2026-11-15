# with-subreaper

Runs a program as a child subreaper, so tmux daemons that the program leaks
reparent to the wrapper instead of to init. It calls the library's
`LibTmux::Platform::Linux::_subreaper` and then replaces itself with the
program, which keeps the PID and exit status. It follows the library's
x86_64 Linux restriction.

`make integration`, `make benchmark` and `compatibility.pl` run each owned
integration program through it:

```console
$ perl scripts/with-subreaper/with-subreaper.pl perl script.pl
```

Test it:

```console
$ prove -Iscripts/lib scripts/with-subreaper/tests
```
