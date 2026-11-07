#!/usr/bin/env python3
"""Own one interactive tmux client and observe its exit through a PTY."""
import errno
import os
import pty
import subprocess
import sys

master, slave = pty.openpty()
env = dict(os.environ, TERM='xterm-256color')
env.pop('TMUX', None)
env.pop('TMUX_PANE', None)
client = subprocess.Popen(sys.argv[1:], stdin=slave, stdout=slave, stderr=slave, env=env)
os.close(slave)
try:
    while True:
        try:
            if not os.read(master, 65536):
                break
        except OSError as error:
            if error.errno == errno.EIO:
                break
            raise
finally:
    os.close(master)
code = client.wait()
print(f'client_exit={code}')
sys.exit(code)
