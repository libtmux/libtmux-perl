#!/usr/bin/env python3
"""Outer regression: inject child exit at the Perl/native wait boundary."""
import argparse
import ctypes
import hashlib
import os
from pathlib import Path
import shlex
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--loop', choices=['Ppoll', 'Poll'], default='Ppoll',
                    help='Poll reproduces the rejected backend failure')
args = parser.parse_args()
if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
    raise OSError(ctypes.get_errno(), 'author probe subreaper')

with tempfile.TemporaryDirectory(prefix='libtmux-perl-wakeup-') as directory:
    injected = Path(directory) / 'inject.so'
    compiler = shlex.split(os.environ.get('CC', 'cc'))
    subprocess.run([*compiler, '-shared', '-fPIC', '-Wall', '-Wextra', '-Werror',
                    '-o', str(injected), str(ROOT / 'scripts/async-wakeup/inject.c'),
                    '-ldl'], check=True)
    print(subprocess.check_output([*compiler, '--version'], text=True).splitlines()[0])
    print('injection sha256:', hashlib.sha256(injected.read_bytes()).hexdigest())
    env = dict(os.environ, LD_PRELOAD=str(injected), IO_ASYNC_LOOP=args.loop)
    process = subprocess.Popen(
        ['perl', '-Ilocal/lib/perl5', '-Ipackages/core/lib', '-Ipackages/async/lib',
         'scripts/async-wakeup/observe.pl'], cwd=ROOT, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True,
    )
    try:
        output, _ = process.communicate(timeout=2)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        raise
    finally:
        while True:
            try:
                os.waitpid(-process.pid, 0)
            except ChildProcessError:
                break
    print(output.decode(), end='')
    if process.returncode or b'LOST_WAKEUP' in output or b'INJECTED_EXIT' not in output:
        raise SystemExit('FAIL: child-exit wakeup was not proved')
    print('PASS: injected exit wakes the loop without a fallback timer')
