# Interface size measurements

Measured 2026-10-15 with renderer 0.3.1 and recorded snapshots
from extractors 0.2.0, 0.3.1, summary documentation,
collapsed conformance requirements, top-level block anchors, and the default
public/open library-product scope.
Synthesized per-conformer copies are excluded; original protocol extensions and
conformances remain. All 13 organization packages were collected with the same
collector policy. The same presentation rules apply to every package; no package-specific selection
was used to improve the ratios. Canonical JSON uses schema 2.0.

Toolchain: `Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1) Target: arm64-apple-macosx27.0.0`. SDK: `macOS:26A425`.
Target: `arm64-apple-macosx27.0.0`. Language mode: `package` (each package's
manifest controls its language mode). Input commits, file counts, module names,
scope and SHA-256 digests are in [the measurement record](InterfaceSize.json).
Renderer implementation: `caa2444d4e6cc2fc7f11afded6a1c4361e49844c`. Existing snapshots were
rerendered to isolate this presentation change; their JSON and per-row collection
dates are retained. The distiller self-row was recollected at that signed implementation
commit before this report;
measurement-only documentation changes do not alter that implementation.

Source bytes count tracked implementation files beneath `Sources/` with extensions
`.swift, .c, .h, .m, .mm, .cpp, .cc`, excluding tests, documentation, dependencies
and build outputs. Interface bytes count the entire unsplit default Markdown
output, including header, anchors and fences. JSON bytes count the entire canonical
snapshot, including its terminal newline. These definitions match the original
measurement; generated Swift is reported separately below and does not change
the source denominator.

| Package | Source bytes | Interface bytes | JSON bytes | Interface / source |
| --- | ---: | ---: | ---: | ---: |
| [swift-appstoreconnect](https://github.com/swift-library/swift-appstoreconnect/tree/c82402c0cdfb090b0c8c9f4b4b6989ee81102b14) | 1,354,387 | 2,781,942 | 174,825,963 | 205.4% |
| [swift-benchmark](https://github.com/swift-library/swift-benchmark/tree/804431603fbbe4f504665efc71df1f7011ca44ea) | 343,591 | 79,825 | 4,928,218 | 23.2% |
| [swift-codex](https://github.com/swift-library/swift-codex/tree/34ffd22fcd05991411c2e74d1e077105e4980ec1) | 348,627 | 1,294,628 | 94,362,934 | 371.4% |
| [swift-data-writable](https://github.com/swift-library/swift-data-writable/tree/bee8707d232010040a071270d83e3ba1608fd0cd) | 66,039 | 23,333 | 763,863 | 35.3% |
| [swift-gyb](https://github.com/swift-library/swift-gyb/tree/d5779b29d719afc9a744eae4c110313f5cce1a1e) | 689 | 399 | 2,109 | 57.9% |
| [swift-interface-distiller](https://github.com/swift-library/swift-interface-distiller/tree/caa2444d4e6cc2fc7f11afded6a1c4361e49844c) | 158,233 | 23,425 | 1,517,438 | 14.8% |
| [swift-json-schema](https://github.com/swift-library/swift-json-schema/tree/236b9a10041c57400a5c05e9e0db37c33efb6ec3) | 207,888 | 44,647 | 1,669,084 | 21.5% |
| [swift-package-template](https://github.com/swift-library/swift-package-template/tree/64e8138302beacbcee6d09da759737714884214c) | 164 | 399 | 1,845 | 243.3% |
| [swift-pdf](https://github.com/swift-library/swift-pdf/tree/e9ceecc992e628b7f555694eafb9f631ac0818eb) | 54,576 | 8,854 | 247,106 | 16.2% |
| [swift-redux](https://github.com/swift-library/swift-redux/tree/a2094d43d5ce9a5c9bcafd5be92a1e3a7d3b44c8) | 17,073 | 5,176 | 155,477 | 30.3% |
| [swift-semver](https://github.com/swift-library/swift-semver/tree/38d82eeba787e1ff6b2f615068621632811ce6ca) | 26,753 | 7,281 | 297,002 | 27.2% |
| [swift-sh](https://github.com/swift-library/swift-sh/tree/3035a02639ca99af57d302358425efdf3d57d50d) | 48,031 | 399 | 256,081 | 0.8% |
| [swift-userdefault](https://github.com/swift-library/swift-userdefault/tree/5bd0952df31e2e7ca4010a8aa53587a776da0b3b) | 13,506 | 5,086 | 190,908 | 37.7% |

## Scope and interpretation

The goal is around half the source size or less. The [density breakdown](InterfaceDensity.md)
accounts for Codex and UserDefault before and after this projection. The table reports actual output,
including every row above that goal. All collections succeeded; empty library
scopes measure snapshot metadata and do not describe executable behavior.

- `swift-appstoreconnect`: build plugins supplied 7,286,536 additional Swift bytes in 4 files for the collected modules. The view includes their public declarations; those build outputs are outside the tracked-source count.
- `swift-codex`: build plugins supplied 2,109,916 additional Swift bytes in 1540 files for the collected modules. The view includes their public declarations; those build outputs are outside the tracked-source count.
- `swift-gyb`: empty default library scope; 399 interface bytes are metadata.
- `swift-package-template`: empty default library scope; 399 interface bytes are metadata.
- `swift-sh`: empty default library scope; 399 interface bytes are metadata.
- `swift-userdefault`: build plugins supplied 24,185 additional Swift bytes in 2 files for the collected modules. The view includes their public declarations; those build outputs are outside the tracked-source count.

Directory links whose targets remain inside the package are accepted. Extraction
uses the selected Apple platform's developer modules, including Testing and its
Foundation overlay. Package language modes are honored, including Swift 5 generator
dependencies. Compiler execution paths use one resolved spelling. Comment-only
library targets with no build plugin, and packages without library products, need
no build. Plugin-generated declaration targets remain in scope. These cases have
collector regression coverage; this sweep has no unavailable package rows.

## View revision

Anchors identify top-level declaration blocks and standalone extension groups.
Member links target their containing block; members have no separate anchor IDs
and do not participate in collisions. Top-level anchors use the module, immediate
owner and declaration name, with identity suffixes on collision. Standard conformance
requirements remain collapsed and summary docs keep leading prose. `--by-module`
adds an index with links and full byte counts for every module. Its index is a
navigation surface, not a replacement for measuring the complete interface.

| Package | 0.2.0 interface bytes | 0.3.1 interface bytes |
| --- | ---: | ---: |
| `swift-appstoreconnect` | 4,886,009 | 2,781,942 |
| `swift-benchmark` | 122,216 | 79,825 |
| `swift-codex` | 2,439,681 | 1,294,628 |
| `swift-data-writable` | 32,710 | 23,333 |
| `swift-gyb` | 399 | 399 |
| `swift-interface-distiller` | 38,547 | 23,425 |
| `swift-json-schema` | 58,044 | 44,647 |
| `swift-package-template` | 399 | 399 |
| `swift-pdf` | 10,658 | 8,854 |
| `swift-redux` | 5,941 | 5,176 |
| `swift-semver` | 9,995 | 7,281 |
| `swift-sh` | 399 | 399 |
| `swift-userdefault` | 6,323 | 5,086 |

## Version slice

`query API.json slice Version --format swift --max-bytes 8000` selects all
37 in-snapshot closure symbols with **3,910 payload bytes**.
The complete stdout is **4,414 bytes**, including its snapshot header.
Both fit within 8,000 bytes. The slice is **complete**, with 0
budget omissions and 18 external references. External identifiers are
retained in JSON; the Swift view shows their count.

## Reproduce

For exact reproduction, use the recorded commits, toolchain, SDK and each row's
extractor version to collect its default scope, then render that canonical JSON
with release 0.3.1. Rerendering captured snapshots isolates
presentation changes from compiler observations:

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
