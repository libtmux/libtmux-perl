#!/usr/bin/env python3
"""Outer regression: inject exit at the private supervisor wait boundary."""
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
args = parser.parse_args()
if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
    raise OSError(ctypes.get_errno(), 'author probe subreaper')


def terminate_owned(pid):
    """Kill only this probe's descendants, including separate process groups."""
    try:
        descriptor = os.pidfd_open(pid)
    except ProcessLookupError:
        return
    try:
        children = Path(f'/proc/{pid}/task/{pid}/children')
        for child in children.read_text().split():
            terminate_owned(int(child))
        try:
            signal.pidfd_send_signal(descriptor, signal.SIGKILL)
        except ProcessLookupError:
            pass
    finally:
        os.close(descriptor)


with tempfile.TemporaryDirectory(prefix='libtmux-perl-supervisor-wakeup-') as directory:
    injected = Path(directory) / 'inject.so'
    compiler = shlex.split(os.environ.get('CC', 'cc'))
    subprocess.run([*compiler, '-shared', '-fPIC', '-Wall', '-Wextra', '-Werror',
                    '-o', str(injected), str(ROOT / 'scripts/supervisor-wakeup/inject.c'),
                    '-ldl'], check=True)
    print(subprocess.check_output([*compiler, '--version'], text=True).splitlines()[0])
    print('injection sha256:', hashlib.sha256(injected.read_bytes()).hexdigest())
    env = dict(os.environ, LD_PRELOAD=str(injected))
    process = subprocess.Popen(
        ['perl', '-Ipackages/core/lib',
         'scripts/supervisor-wakeup/observe.pl'], cwd=ROOT, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True,
    )
    try:
        output, _ = process.communicate(timeout=2)
    except subprocess.TimeoutExpired:
        terminate_owned(process.pid)
        process.communicate()
        raise
    finally:
        while True:
            try:
                os.waitpid(-1, 0)
            except ChildProcessError:
                break
    print(output.decode(), end='')
    if process.returncode or b'LOST_WAKEUP' in output or b'INJECTED_EXIT' not in output or b'completed=0' not in output:
        raise SystemExit('FAIL: supervisor completion was not proved')
    print('PASS: injected exit wakes the supervisor without a fallback timer')
