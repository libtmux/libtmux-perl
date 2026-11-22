# pty-client

Runs one program, normally an interactive tmux client, on a pseudo-terminal
and reports how it exits. Core Perl cannot allocate a PTY, so the script uses
`IO::Pty`, a develop-phase dependency in the `cpanfile`.

`packages/core/t/integration/input-client.t` runs it to own the attached
client. The program sees `TERM=xterm-256color` and no `TMUX`, `TMUX_PANE`,
`LIBTMUX_SOCKET`, or `LIBTMUX_SOCKET_PATH`.
The script drains the terminal until the program closes it, prints
`client_exit=CODE` and exits with the same code:

```console
$ perl scripts/pty-client/pty-client.pl tmux -V
```

Test it:

```console
$ prove -Iscripts/lib scripts/pty-client/tests
```
