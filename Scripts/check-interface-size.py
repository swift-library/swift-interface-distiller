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
summary documentation, collapsed conformance requirements, and the default
public/open library-product scope.
Synthesized per-conformer copies are excluded; original protocol extensions and
conformances remain. All 13 organization packages were collected with the same
collector policy. The same presentation rules apply to every package; no package-specific selection
was used to improve the ratios. Canonical JSON uses schema {data['schemaVersion']}.

Toolchain: `{data['toolchain'].replace(chr(10), ' ')}`. SDK: `{data['sdk']}`.
Target: `{data['target']}`. Language mode: `{data['languageMode']}` (each package's
manifest controls its language mode). Input commits, file counts, module names,
scope and SHA-256 digests are in [the measurement record](InterfaceSize.json).
Renderer implementation: `{data['rendererCommit']}`. Captured snapshots retain
their per-row collection dates. The distiller self-row uses that signed implementation
commit before this report;
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

The goal is around half the source size or less. The [density breakdown](InterfaceDensity.md)
accounts for Codex and UserDefault before and after this projection. The table reports actual output,
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

## View revision

Standard conformance requirements are collapsed by default and expand with
`--show-implied`. Summary docs stop at Markdown block boundaries, so parameter
lists and examples are kept in `--docs full`. Anchors use the module, immediate
owner and declaration name, with identity suffixes on collision. `--by-module`
adds an index with links and full byte counts for every module. Its index is a
navigation surface, not a replacement for measuring the complete interface.

| Package | Previous interface bytes | Current interface bytes |
| --- | ---: | ---: |
'''
for row in data['records']:
    text += f"| `{row['package']}` | {row['beforeInterfaceBytes']:,} | {row['interfaceBytes']:,} |\n"
text += '\n## Version slice\n\n'
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
density = json.loads((root / 'Documentation/InterfaceDensity.json').read_text())
density_text = f"""# Interface density

Measured {density['date']} from the recorded snapshots with renderer implementation
`{density['rendererCommit']}`. These are complete default interface views with summary
docs. Source, generated Swift and JSON definitions are shared with
[Interface size measurements](InterfaceSize.md). Canonical snapshots are unchanged
for these two packages. `render --report` provides the current per-symbol byte
accounting. Reference Markdown and per-symbol accounting are retained as run evidence.

Source origins come from a separate compiler extraction with locations, joined by
module, language and precise identifier. Located declarations beneath Sources are
tracked declarations. Build-plugin outputs and source directives naming a verified
local generation template identify plugin-generated declarations. Members with no
source location are compiler-implicit; here they are decoding and raw-value
initializers. This origin classification is distinct from the presentation rule:
standard requirements may be declared explicitly and still be implied by conformance.
No compiler witness selection is inferred.

"""
for record in density['records']:
    name = record['package']
    density_text += f"""## {name}

Tracked source: **{record['sourceBytes']:,} bytes**. Additional generated Swift:
**{record['generatedSwiftBytes']:,} bytes**. Input commit: `{record['inputCommit']}`.
The interface changed from **{record['beforeBytes']:,}** to **{record['afterBytes']:,} bytes**.
There is {record['configurationCount']} configuration and {record['moduleCount']} collected modules;
{record['duplicateModuleIdentities']} compiler symbol identities are duplicated across modules.
Symbols in distinct qualified namespaces remain distinct API.

| Component | Before bytes | After bytes |
| --- | ---: | ---: |
"""
    for component in ['declaration', 'documentation', 'anchors', 'overhead']:
        density_text += f"| {component} | {record['components']['before'][component]:,} | {record['components']['after'][component]:,} |\n"
    for title, key in [('Declaration category', 'byCategory'), ('Source origin', 'byOrigin'), ('Symbol kind', 'byKind'), ('Module', 'byModule')]:
        density_text += f"\n| {title} | Symbols | Before bytes | After bytes |\n| --- | ---: | ---: | ---: |\n"
        for category, row in sorted(record[key].items()):
            density_text += f"| {category} | {row['symbols']:,} | {row['beforeBytes']:,} | {row['afterBytes']:,} |\n"
    density_text += f"\nCategory, origin, kind and module tables each account for symbol bytes (declarations,\ndocs and anchors); overhead is counted separately. The module index is\n{record['indexBytes']:,} bytes; all indexed files together are {record['indexedBytes']:,} bytes.\n"
density_text += """
## Interpretation

Codex's generated Stable and Experimental namespaces expose a genuinely large API.
Their qualified identifiers differ; equal-looking declarations in those namespaces
are not duplicate observations. After collapsing 3,219 standard requirements,
14,903 declarations remain visible. Their declarations and structural context alone
exceed 1.26 MB, so retaining full signatures cannot fit into the 348 KB tracked-source
count. Generated Swift contributes another 2.11 MB of actual input, reported separately
rather than changing that denominator. The complete interface remains above the tracked
source goal; module indexing and focused lookup/member queries provide smaller entry
points. The index size is not presented as the API's size.

UserDefault's initializers are emitted from generation templates. Their comments
begin with parameter lists, not a prose paragraph; repeating those lists was the
summary error. Summary mode omits them and full mode preserves them. Original
protocol-extension declarations remain. The complete summary interface now fits
around half the tracked source size.

No Equatable equality members, Hashable hash members, CaseIterable allCases or
CodingKeys are present in these two default snapshots. Their zero rows reflect
collected evidence. Public CodingKeys declarations remain visible in the regression
fixture because that named type is not required by Codable.
"""
outputs = {'InterfaceSize.md': text, 'InterfaceDensity.md': density_text}
for name, content in outputs.items():
    path = root / 'Documentation' / name
    if args.check:
        if not path.exists() or path.read_text() != content:
            raise SystemExit(name + ' differs from its measurement record; run Scripts/check-interface-size.py')
    else:
        path.write_text(content)
