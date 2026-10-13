#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
# Copyright (c) 2026 Xudong Xu
"""Exercise the installed command's stream, error and baseline contracts."""
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / '.build/check'
OUT.mkdir(parents=True, exist_ok=True)
binary_dir = subprocess.check_output(['swift', 'build', '--build-system', 'native', '-c', 'release', '--show-bin-path'], cwd=ROOT, text=True).strip()
CLI = str(pathlib.Path(binary_dir) / 'interface-distiller')


def run(*args, code=0):
    result = subprocess.run([CLI, *map(str, args)], cwd=ROOT, capture_output=True, timeout=120)
    assert result.returncode == code, (args, result.returncode, result.stderr.decode())
    if code in (0, 1):
        assert not result.stderr, result.stderr
    return result


assert run('--version').stdout.strip() == b'0.1.1'
config = OUT / 'configuration.json'
config.write_bytes(run('configuration').stdout)
snapshot = OUT / 'snapshot.json'
run('normalize', 'Tests/InterfaceDistillerTests/Fixtures/Graphs', '--configuration', config, '--include-spi', '--output', snapshot)
evidence = json.loads(snapshot.read_bytes())
assert len(evidence['configurations'][0]['symbols']) == 19
for kind in ['lookup', 'members', 'conformers', 'initializers', 'returning', 'slice']:
    selector = 'Named' if kind == 'conformers' else 'Item'
    data = json.loads(run('query', snapshot, kind, selector).stdout)
    assert data['symbols'], kind
assert json.loads(run('query', snapshot, 'slice', 'Item', '--max-symbols', 1).stdout)['state'] == 'truncated'
assert json.loads(run('coverage', snapshot).stdout)[0]['eligible'] == 18
baseline = OUT / 'baseline.json'
run('baseline', 'write', snapshot, baseline)
before = baseline.read_bytes()
run('baseline', 'check', snapshot, baseline)
run('compare', baseline, snapshot)
run('render', snapshot, '--output-dir', OUT / 'markdown', '--byte-budget', 3000)
assert all(p.stat().st_size <= 3000 for p in (OUT / 'markdown').glob('*.md'))
malformed = OUT / 'malformed.json'
malformed.write_text('{')
failure = run('baseline', 'write', malformed, baseline, code=2)
assert not failure.stdout and json.loads(failure.stderr)['code'] == 'io'
assert baseline.read_bytes() == before
failure = run('normalize', OUT / 'missing', '--configuration', config, code=2)
assert not failure.stdout and json.loads(failure.stderr)['code'] == 'missingInput'
changed = json.loads(snapshot.read_bytes())
changed['configurations'][0]['symbols'].pop()
candidate = OUT / 'candidate.json'
candidate.write_text(json.dumps(changed))
assert json.loads(run('baseline', 'check', candidate, baseline, code=1).stdout)['removed']
assert baseline.read_bytes() == before
print('CLI streams, queries, rendering, comparison and baseline safety passed')
