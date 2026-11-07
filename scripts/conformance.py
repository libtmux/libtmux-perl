#!/usr/bin/env python3
"""Compare the advertised shared subset with a source-pinned independent port."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import time

ROOT=Path(__file__).resolve().parent.parent
CACHE=ROOT/'.cache/reference-python'
PIN=json.loads((ROOT/'scripts/conformance-reference.json').read_text())
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--provision',action='store_true')
args=parser.parse_args()
if args.provision:
    repo=os.environ.get('LIBTMUX_REFERENCE_PYTHON',str(ROOT/'../../python/libtmux'))
    archive=subprocess.check_output(['git','-C',repo,'archive',PIN['revision'],'src/libtmux'])
    CACHE.mkdir(parents=True,exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(CACHE,filter='data')
    sys.exit(0)
for name,expected in PIN['files'].items():
    path=CACHE/name
    if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
        raise SystemExit('independent port provenance missing/drifted; run --provision outside test loops')
sys.path.insert(0,str(CACHE/'src'))
from libtmux._internal.query_list import QueryList
cases=json.loads((ROOT/'conformance/where-v1.json').read_text())['cases']
start=time.monotonic()
perl=json.loads(subprocess.check_output(['perl','scripts/filter-fixtures.pl'],cwd=ROOT))
results=[]
for case,actual in zip(cases,perl,strict=True):
    expected={'key':case['key'], **({'error':case['error']} if 'error' in case else {'ids':case['ids']})}
    result={'key':case['key'],'perl':'PASS' if actual==expected else 'FAIL'}
    if 'kwargs' in case['python']:
        other=[r['id'] for r in QueryList(case['records']).filter(**case['python']['kwargs'])]
        result['python']='PASS' if other==case['ids'] else 'FAIL'
    else:result.update(python='UNSUPPORTED',reason=case['python']['unsupported'])
    results.append(result)
report={'schema':1,'reference':{k:PIN[k] for k in ('repository','revision')},'adaptation':'Wire fields used as record keys; declared common operators mapped to native QueryList keyword lookups. Unsupported rows are not interoperability passes.','elapsed_seconds':round(time.monotonic()-start,4),'results':results}
(ROOT/'.cache/conformance.json').write_text(json.dumps(report,indent=2)+'\n')
print(f"Perl {sum(r['perl']=='PASS' for r in results)}/{len(results)}; independent shared subset {sum(r['python']=='PASS' for r in results)}; unsupported {sum(r['python']=='UNSUPPORTED' for r in results)}")
if any(r['perl']=='FAIL' or r['python']=='FAIL' for r in results):
    print(json.dumps([r for r in results if r['perl']=='FAIL' or r['python']=='FAIL'],indent=2));sys.exit(1)
