#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
"""Record collection and a bounded Swift query against the measured package."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import shlex
import subprocess
import tarfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--package', type=Path, required=True)
parser.add_argument('--executable', type=Path, default=root / '.build/release/interface-distiller')
args = parser.parse_args()
executable = args.executable.resolve()
measurement = json.loads((root / 'Documentation/InterfaceSize.json').read_text())
measured = next(row for row in measurement['records'] if row['package'] == 'swift-semver')
session = root / '.build/demo-session'
package = session / 'semver'
package.mkdir(parents=True, exist_ok=True)
archive = subprocess.check_output(['git', 'archive', measured['commit']], cwd=args.package)
with tarfile.open(fileobj=io.BytesIO(archive)) as source:
    source.extractall(package, filter='data')
commands = []
for index, argv in enumerate([
    ['collect', 'package', 'semver', '--output', 'api.json'],
    ['query', 'api.json', 'lookup', 'incrementing(_:)', '--format', 'swift', '--max-bytes', '1200'],
]):
    result = subprocess.run([str(executable), *argv], cwd=session, text=True, capture_output=True)
    (session / f'stderr-{index}.txt').write_text(result.stderr)
    result.check_returncode()
    commands.append({'command': shlex.join(['interface-distiller', *argv]),
                     'stdout': result.stdout, 'exit_code': result.returncode})
if 'public func incrementing(' not in commands[1]['stdout']:
    raise SystemExit('The query did not return the demonstrated declaration')
assets = root / 'Documentation/Assets'
(assets / 'Demo-record.json').write_text(json.dumps({
    'title': 'swift-semver · collect and query', 'commands': commands
}, indent=2) + '\n')
provenance = {
    'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
    'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest(),
    'extractor_version': subprocess.check_output([str(executable), '--version'], text=True).strip(),
    'swift': subprocess.check_output(['swift', '--version'], text=True).strip(),
    'package': 'swift-library/swift-semver',
    'package_revision': measured['commit'],
    'archive_sha256': hashlib.sha256(archive).hexdigest(),
    'snapshot_sha256': hashlib.sha256((session / 'api.json').read_bytes()).hexdigest(),
    'command_exit_codes': [command['exit_code'] for command in commands],
}
(assets / 'Demo-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
print('Recorded package collection and a bounded declaration query')
