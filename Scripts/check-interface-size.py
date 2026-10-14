#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
# Copyright (c) 2026 Xudong Xu
"""Render recorded interface measurements; --check detects documentation drift."""
import argparse
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
data = json.loads((root / 'Documentation/InterfaceSize.json').read_text())
text = f'''# Interface size measurements

Measured {data['date']} with extractor and renderer {data['extractorVersion']},
summary documentation, and the default public/open library-product scope.
Synthesized per-conformer copies are excluded; original protocol extensions and
conformances remain. All 13 organization packages were collected with the same
collector policy. No declarations, modules or documentation paragraphs were
selected to improve the ratios. Canonical JSON uses schema {data['schemaVersion']}.

Toolchain: `{data['toolchain'].replace(chr(10), ' ')}`. SDK: `{data['sdk']}`.
Target: `{data['target']}`. Language mode: `{data['languageMode']}` (each package's
manifest controls its language mode). Input commits, file counts, module names,
scope and SHA-256 digests are in [the measurement record](InterfaceSize.json).
The distiller self-row uses its signed implementation commit before this report;
measurement-only documentation changes do not alter that implementation.

Source bytes count tracked implementation files beneath `Sources/` with extensions
`{', '.join(data['sourceExtensions'])}`, excluding tests, documentation, dependencies
and build outputs. Interface bytes count the entire unsplit default Markdown
output, including header, anchors and fences. JSON bytes count the entire canonical
snapshot, including its terminal newline. These definitions match the original
measurement; generated Swift is reported separately below and does not change
the source denominator.

| Package | Source bytes | Interface bytes | JSON bytes | Interface / source |
| --- | ---: | ---: | ---: | ---: |
'''
for row in data['records']:
    link = f"[{row['package']}](https://github.com/swift-library/{row['package']}/tree/{row['commit']})"
    ratio = row['interfaceBytes'] / row['sourceBytes'] * 100
    text += f"| {link} | {row['sourceBytes']:,} | {row['interfaceBytes']:,} | {row['jsonBytes']:,} | {ratio:.1f}% |\n"
text += '''
## Scope and interpretation

The goal is around half the source size or less. The table reports actual output,
including every row above that goal. All collections succeeded; empty library
scopes measure snapshot metadata and do not describe executable behavior.

'''
for row in data['records']:
    if not row['modules']:
        text += f"- `{row['package']}`: empty default library scope; {row['interfaceBytes']:,} interface bytes are metadata.\n"
    if row['generatedSwiftBytes']:
        text += f"- `{row['package']}`: build plugins supplied {row['generatedSwiftBytes']:,} additional Swift bytes in {row['generatedSwiftFiles']} files for the collected modules. The view includes their public declarations; those build outputs are outside the tracked-source count.\n"
text += '''
Directory links whose targets remain inside the package are accepted. Extraction
uses the selected Apple platform's developer modules, including Testing and its
Foundation overlay. Package language modes are honored, including Swift 5 generator
dependencies. Compiler execution paths use one resolved spelling. Comment-only
library targets with no build plugin, and packages without library products, need
no build. Plugin-generated declaration targets remain in scope. These cases have
collector regression coverage; this sweep has no unavailable package rows.

## Version slice

'''
v = data['versionSlice']
text += f'''`query API.json slice Version --format swift --max-bytes 8000` selects all
{v['inScopeSymbols']} in-snapshot closure symbols with **{v['payloadBytes']:,} payload bytes**.
The complete stdout is **{v['outputBytes']:,} bytes**, including its snapshot header.
Both fit within 8,000 bytes. The slice is **{v['state']}**, with {v['budgetOmissions']}
budget omissions and {v['externalReferenceCount']} external references. External identifiers are
retained in JSON; the Swift view shows their count.

## Reproduce

Use the recorded commits, toolchain and SDK, collect each package's default scope,
then render the resulting canonical JSON with release {data['rendererVersion']}:

```sh
interface-distiller collect package PACKAGE --output .build/api.json
interface-distiller render .build/api.json --docs summary --output-dir .build/interface
interface-distiller query .build/api.json slice Version --format swift --max-bytes 8000
wc -c .build/api.json .build/interface/*.md
```

The source count uses file bytes, not lines or compressed size. When comparing new
measurements, record compiler, SDK, source commit, scope and extractor changes.
`python3 Scripts/check-interface-size.py --check` verifies this page against its
recorded inputs; it does not claim to rerun extraction.
'''
path = root / 'Documentation/InterfaceSize.md'
if args.check:
    if not path.exists() or path.read_text() != text:
        raise SystemExit('InterfaceSize.md differs from InterfaceSize.json; run Scripts/check-interface-size.py')
else:
    path.write_text(text)
