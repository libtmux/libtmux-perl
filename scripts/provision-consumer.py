#!/usr/bin/env python3
"""Provision optional consumer runtime dependencies outside verification loops."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cpm',default=str(ROOT/'.cache/cpm'))
args=parser.parse_args()
record=ROOT/'.cache/consumer-prefix'
if record.exists() and Path(record.read_text().strip()).is_dir():
    prefix=record.read_text().strip()
else:
    prefix=tempfile.mkdtemp(prefix='libtmux-perl-consumer-')
    record.parent.mkdir(exist_ok=True)
    record.write_text(prefix+'\n')
subprocess.run(['perl',args.cpm,'install','--local-lib-contained',prefix,'--final-install','runtime','Future@0.54','IO::Async@0.805','Future::AsyncAwait@0.71'],cwd=ROOT,check=True)
