"""Run one owned Linux integration program as a child subreaper."""
import ctypes
import os
import sys

if len(sys.argv) < 2:
    raise SystemExit("usage: with-subreaper.py PROGRAM [ARGS...]")
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
    raise OSError(ctypes.get_errno(), "set child subreaper")
os.execvp(sys.argv[1], sys.argv[1:])
