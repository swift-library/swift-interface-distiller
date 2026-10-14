#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
# Copyright (c) 2026 Xudong Xu
"""Render the recorded interface measurements; --check detects documentation drift."""
import argparse
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
data = json.loads((root / 'Documentation/InterfaceSize.json').read_text())
text = f'''# Interface size measurements

Measured {data['date']} with renderer {data['rendererVersion']}, summary documentation,
and the default public/open library-product scope. Compiler-synthesized declarations
are included. No symbols, modules or documentation paragraphs were selected to improve
these ratios. Collection uses the same scope as the shared API evidence workflow.
Canonical JSON remains schema 1.0; existing 0.1.2 evidence is rendered directly.

Toolchain: `{data['toolchain'].replace(chr(10), ' ')}`. SDK: `{data['sdk']}`.
Target: `{data['target']}`. The distiller's own row uses its 0.2.0 source and extractor;
other rows use 0.1.2 extraction. Input revisions, source-file counts, module names,
extractor versions and SHA-256 digests are in [the measurement record](InterfaceSize.json).

Source bytes count the tracked implementation files beneath `Sources/` with extensions
`{', '.join(data['sourceExtensions'])}`, excluding tests, documentation and build outputs.
The distiller row includes the new release's implementation files. Interface bytes count
the entire unsplit default Markdown output, including its header, anchors and fences.
JSON bytes count the entire canonical snapshot, including its terminal newline.
Unavailable collection has no interface or JSON size; it is not counted as zero.

| Package | Source bytes | Interface bytes | JSON bytes | Interface / source |
| --- | ---: | ---: | ---: | ---: |
'''
for row in data['records']:
    name = row['package']
    link = f"[{name}](https://github.com/swift-library/{name}/tree/{row['commit']})"
    if 'interfaceBytes' in row:
        ratio = row['interfaceBytes'] / row['sourceBytes'] * 100
        text += f"| {link} | {row['sourceBytes']:,} | {row['interfaceBytes']:,} | {row['jsonBytes']:,} | {ratio:.1f}% |\n"
    else:
        text += f"| {link} | {row['sourceBytes']:,} | — | — | unavailable |\n"
text += '\n## Coverage and limits\n\n'
for row in data['records']:
    if 'reason' in row:
        text += f"- `{row['package']}`: {row['reason'].rstrip('.')}. The shared workflow also records failed collection for this package.\n"
    elif not row['modules']:
        text += f"- `{row['package']}`: no library modules in the default scope; its row measures metadata, not an API.\n"
text += '''
The target is roughly half the source size or less. The table reports actual output,
including rows above that target. A source file can expose many synthesized or inherited
members; a small implementation can therefore have a larger interface view. Empty
library scope is not evidence that an executable has no behavior. Collection failures
need separate collector or toolchain work before their ratios can be assessed.

## Version slice

'''
v = data['versionSlice']
text += f'''`query API.json slice Version --format swift --max-bytes 8000` selects all
{v['inScopeSymbols']} in-scope closure symbols with **{v['payloadBytes']:,} payload bytes**;
stdout is **{v['outputBytes']:,} bytes**, including the snapshot header and omissions.
Both fit within 8,000 bytes. There are {v['budgetOmissions']} budget omissions.
The closure is **{v['state']}**, not complete: {len(v['unresolvedReferences'])} external compiler references
are outside the collected snapshot. No format changes that evidence limitation.

## Reproduce

Use the recorded revisions, toolchain and SDK, collect each package's default scope,
then render the resulting canonical JSON with release {data['rendererVersion']}:

```sh
interface-distiller collect package PACKAGE --output .build/api.json
interface-distiller render .build/api.json --docs summary --output-dir .build/interface
interface-distiller query .build/api.json slice Version --format swift --max-bytes 8000
wc -c .build/api.json .build/interface/*.md
```

The source count uses file bytes, not lines or compressed size. When comparing new
measurements, record compiler, SDK, source revision, scope and extractor changes.
`python3 Scripts/check-interface-size.py --check` verifies this page against its
recorded inputs; it does not claim to rerun historical extraction.
'''
path = root / 'Documentation/InterfaceSize.md'
if args.check:
    if not path.exists() or path.read_text() != text:
        raise SystemExit('InterfaceSize.md differs from InterfaceSize.json; run Scripts/check-interface-size.py')
else:
    path.write_text(text)
