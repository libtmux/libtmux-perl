#!/usr/bin/env python3
"""Record actual command/supervisor identities, then exec the benchmark tmux."""
import json
import os
import sys

record={'mode':os.environ['LIBTMUX_BENCH_MODE'],'command_pid':os.getpid(),'supervisor_pid':os.getppid()}
fd=os.open(os.environ['LIBTMUX_BENCH_LOG'],os.O_WRONLY|os.O_APPEND|os.O_CREAT,0o600)
os.write(fd,(json.dumps(record)+'\n').encode())
os.close(fd)
program=os.environ['LIBTMUX_BENCH_TMUX']
os.execvp(program,[program,*sys.argv[1:]])
