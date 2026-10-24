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
subprocess.run(['swift', 'build', '--build-system', 'native', '-c', 'release'], cwd=ROOT, check=True)
binary_dir = subprocess.check_output(['swift', 'build', '--build-system', 'native', '-c', 'release', '--show-bin-path'], cwd=ROOT, text=True).strip()
CLI = str(pathlib.Path(binary_dir) / 'interface-distiller')


def run(*args, code=0):
    result = subprocess.run([CLI, *map(str, args)], cwd=ROOT, capture_output=True, timeout=120)
    assert result.returncode == code, (args, result.returncode, result.stderr.decode())
    if code in (0, 1):
        assert not result.stderr, result.stderr
    return result


assert run('--version').stdout.strip() == b'0.4.0'
config = OUT / 'configuration.json'
config.write_bytes(run('configuration').stdout)
snapshot = OUT / 'snapshot.json'
run('normalize', 'Tests/InterfaceDistillerTests/Fixtures/Graphs', '--configuration', config, '--include-spi', '--output', snapshot)
snapshot_data = json.loads(snapshot.read_bytes())
assert len(snapshot_data['configurations'][0]['symbols']) == 18
assert snapshot_data['schemaVersion'] == '2.0'
schema = json.loads((ROOT / 'Documentation/Schema/InterfaceSnapshot.schema.json').read_text())
assert schema['properties']['schemaVersion']['pattern'] == r'^2\.[0-9]+$'
assert snapshot_data['configurations'][0]['scope']['includeSynthesized'] is False
all_snapshot = OUT / 'all-snapshot.json'
run('normalize', 'Tests/InterfaceDistillerTests/Fixtures/Graphs', '--configuration', config,
    '--include-spi', '--include-synthesized', '--output', all_snapshot)
all_snapshot_data = json.loads(all_snapshot.read_bytes())
assert all_snapshot_data['configurations'][0]['scope']['includeSynthesized'] is True
assert len(all_snapshot_data['configurations'][0]['symbols']) == 19
assert not any(g['state'] == 'unresolved' for g in snapshot_data['configurations'][0]['gaps'])
for kind in ['lookup', 'members', 'conformers', 'initializers', 'returning', 'slice']:
    selector = 'Named' if kind == 'conformers' else 'Item'
    data = json.loads(run('query', snapshot, kind, selector).stdout)
    assert data['symbols'], kind
assert json.loads(run('query', snapshot, 'slice', 'Item', '--max-symbols', 1).stdout)['state'] == 'truncated'
for fmt in ['json', 'swift', 'markdown']:
    for kind in ['lookup', 'members', 'conformers', 'initializers', 'returning', 'slice']:
        selector = 'Named' if kind == 'conformers' else 'Item'
        result = run('query', snapshot, kind, selector, '--format', fmt)
        if fmt == 'json':
            assert json.loads(result.stdout)['symbols']
        else:
            assert b'public ' in result.stdout
            assert b'Selection:' in result.stdout
    assert run('slice', snapshot, 'Item', '--format', fmt).stdout == run('query', snapshot, 'slice', 'Item', '--format', fmt).stdout
    limited = run('query', snapshot, 'members', 'Item', '--format', fmt, '--max-bytes', 10)
    if fmt == 'json':
        assert json.loads(limited.stdout)['state'] == 'truncated'
    else:
        assert b'budget exhausted' in limited.stdout and b'Omitted in-snapshot symbols:' in limited.stdout
for option, value in [('format', 'xml'), ('docs', 'brief'), ('view', 'other')]:
    failure = run('query', snapshot, 'lookup', 'Item', '--' + option, value, code=2)
    assert json.loads(failure.stderr)['code'] == 'usage'
for docs in ['summary', 'full', 'none']:
    output = OUT / ('interface-' + docs + '.swift')
    run('query', snapshot, 'slice', 'Item', '--format', 'swift', '--docs', docs, '--output', output)
    assert (b'///' in output.read_bytes()) == (docs != 'none')
symbols_parts = json.loads(run('render', snapshot, '--view', 'symbols').stdout)
assert 'Compiler identifier:' in symbols_parts[0]['markdown']
interface_parts = json.loads(run('render', snapshot).stdout)
assert 'public struct Item' in interface_parts[0]['markdown']
assert 'Compiler identifier:' not in interface_parts[0]['markdown']
assert interface_parts[0]['markdown'].count('<a id=') == 7
member_view = run('query', snapshot, 'members', 'Item', '--format', 'markdown').stdout
assert member_view.count(b'<a id=') == 1
assert b'<a id="snapshotexample-item"></a>' in member_view
assert symbols_parts[0]['markdown'].count('<a id=') == 18
report = OUT / 'interface-size.json'
indexed = json.loads(run('render', snapshot, '--by-module', '--report', report).stdout)
assert indexed[0]['name'] == 'index.md'
assert all('(' + part['name'] + ')' in indexed[0]['markdown'] for part in indexed[1:])
assert json.loads(report.read_bytes())['totalBytes'] == len(interface_parts[0]['markdown'].encode())
run('render', snapshot, '--show-implied')
run('render', snapshot, '--view', 'symbols', '--report', report, code=2)

assert json.loads(run('coverage', snapshot).stdout)[0]['eligible'] == 17
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
