#!/usr/bin/env python3
"""Provision pinned releases separately; qualify owned Linux tmux fixtures."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
LOCK = json.loads((ROOT / 'scripts/tmux-lock.json').read_text())
CACHE = ROOT / '.cache/tmux-builds'
REQUIRED = [row['version'] for row in LOCK['releases']]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def provision(row):
    version = row['version']
    archive = CACHE / f'tmux-{version}.tar.gz'
    CACHE.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        request = urllib.request.Request(row['url'], headers={'User-Agent': 'libtmux-perl-qualification'})
        with urllib.request.urlopen(request, timeout=30) as source:
            archive.write_bytes(source.read())
    if sha(archive) != row['sha256']:
        raise RuntimeError(f'{version}: release digest mismatch')
    source = CACHE / f'tmux-{version}'
    marker = source / 'libtmux-build.json'
    if marker.exists():
        record = json.loads(marker.read_text())
        if record['archive_sha256'] == row['sha256'] and record['binary_sha256'] == sha(source / 'tmux'):
            return record
    # Cache is owned by this script. Re-extraction binds source to the locked asset.
    if source.exists():
        shutil.rmtree(source)
    with tarfile.open(archive) as tar:
        tar.extractall(CACHE, filter='data')
    start = time.monotonic()
    with (source / 'provision.log').open('w') as log:
        try:
            subprocess.run(['./configure', *row['configure']], cwd=source, stdout=log, stderr=subprocess.STDOUT, check=True)
            subprocess.run(['make', '-j2'], cwd=source, stdout=log, stderr=subprocess.STDOUT, check=True)
        except subprocess.CalledProcessError:
            print((source / 'provision.log').read_text(errors='replace')[-6000:], flush=True)
            raise
    identity = subprocess.check_output([str(source / 'tmux'), '-V'], text=True).strip()
    if identity != f'tmux {version}':
        raise RuntimeError(f'{version}: wrong binary identity {identity}')
    record = dict(version=version, source_revision=row['source_revision'], archive_sha256=row['sha256'],
                  binary_sha256=sha(source / 'tmux'), configure=row['configure'],
                  compiler=subprocess.check_output(['cc', '--version'], text=True).splitlines()[0],
                  elapsed_seconds=round(time.monotonic() - start, 4), os=platform.platform())
    marker.write_text(json.dumps(record, indent=2) + '\n')
    print(f'{version}: pinned build ready', flush=True)
    return record


def qualify(row, installed=None):
    version = row['version']
    binary = CACHE / f'tmux-{version}/tmux'
    marker = binary.parent / 'libtmux-build.json'
    if not marker.exists():
        return dict(version=version, status='UNVERIFIED', reason='run --provision outside test loops')
    provenance = json.loads(marker.read_text())
    if provenance['archive_sha256'] != row['sha256'] or provenance['binary_sha256'] != sha(binary):
        return dict(version=version, status='FAIL', reason='build provenance drift')
    env = dict(os.environ, LIBTMUX_TEST_TMUX=str(binary))
    libs = [f'-I{installed}/lib/perl5', '-Ilocal/lib/perl5', '-Iscripts/lib'] if installed else ['-Ilocal/lib/perl5', '-Ipackages/core/lib', '-Ipackages/async/lib', '-Ipackages/workspace/lib', '-Iscripts/lib']
    if installed: env['LIBTMUX_TEST_CLI']=str(Path(installed)/'bin/libtmux-workspace')
    suites = [str(p.relative_to(ROOT)) for package in ('core','async','workspace') for p in sorted((ROOT / f'packages/{package}/t/integration').glob('*.t'))]
    commands = [['python3', 'scripts/with-subreaper.py', 'perl', *libs, suite] for suite in suites]
    commands.append(['perl', 'scripts/run-examples.pl', *(['--installed', installed] if installed else [])])
    results = []
    for index, command in enumerate(commands):
        start = time.monotonic()
        try:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=25)
            code, output = result.returncode, result.stdout
        except subprocess.TimeoutExpired as error:
            code, output = 124, error.stdout or b''
        path = ROOT / f'.cache/compatibility/{version}-{index}.log'
        path.write_bytes(output)
        results.append(dict(argv=command, exit_status=code, elapsed_seconds=round(time.monotonic() - start, 4), evidence=str(path.relative_to(ROOT))))
    status = 'PASS' if all(r['exit_status'] == 0 for r in results) else 'FAIL'
    print(f'{version}: {status}', flush=True)
    return dict(version=version, status=status, provenance=provenance, checks=results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--provision', action='store_true')
    modes.add_argument('--check', action='store_true')
    parser.add_argument('--installed', help='qualified consumer prefix outside the checkout')
    parser.add_argument('--version', choices=REQUIRED)
    args = parser.parse_args()
    rows = [r for r in LOCK['releases'] if not args.version or r['version'] == args.version]
    if args.provision:
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(provision, rows))
        return
    if not platform.system() == 'Linux':
        raise SystemExit('required qualification platform is Linux')
    (ROOT / '.cache/compatibility').mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        cells = list(pool.map(lambda row: qualify(row, args.installed), rows))
    evidence = dict(schema=1, source_revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    diff_sha256=hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT)).hexdigest(),
                    perl=subprocess.check_output(['perl', '-e', 'print $^V'], text=True), os=platform.platform(),
                    elapsed_seconds=round(time.monotonic() - start, 4), cells=cells)
    (ROOT / f'.cache/compatibility/evidence-{args.version or "all"}.json').write_text(json.dumps(evidence, indent=2) + '\n')
    if any(c['status'] != 'PASS' for c in cells):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
