#!/usr/bin/env python3
"""Record whole-command results against a precise tracked and untracked tree."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parent.parent
if len(sys.argv)<4 or sys.argv[2]!='--':raise SystemExit('usage: evidence.py NAME -- COMMAND [ARGS...]')
name=sys.argv[1]
if not name.replace('-','').isalnum():raise SystemExit('invalid evidence key')
paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=ROOT).decode().split('\0')
manifest={}
for name_path in sorted(set(filter(None,paths))):
    path=ROOT/name_path
    if path.is_symlink():manifest[name_path]=hashlib.sha256(os.readlink(path).encode()).hexdigest()
    elif path.is_file():manifest[name_path]=hashlib.sha256(path.read_bytes()).hexdigest()
source_manifest=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()
output=ROOT/'.cache/evidence';output.mkdir(parents=True,exist_ok=True)
command=sys.argv[3:]
start=time.monotonic()
with (output/(name+'.log')).open('wb') as log:result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
elapsed=time.monotonic()-start
record={'schema':1,'key':name,'status':'PASS' if result.returncode==0 else 'FAIL','argv':command,
    'elapsed_seconds':round(elapsed,4),'exit_status':result.returncode,'os':platform.platform(),
    'perl':subprocess.check_output(['perl','-e','print "$^V $Config{archname}"','-MConfig'],text=True),
    'source_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    'source_manifest_sha256':source_manifest,'files':manifest,'recorded_at':datetime.datetime.now(datetime.UTC).isoformat(),
    'measurement':'whole child command including startup/setup; recorder hashing excluded'}
(output/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n')
print(f"{record['status']} {name}: {elapsed:.3f}s; exit={result.returncode}; evidence=.cache/evidence/{name}.json")
if result.returncode:print((output/(name+'.log')).read_text(errors='replace')[-12000:])
raise SystemExit(result.returncode)
