# Interface size measurements

Measured 2026-10-14 with renderer 0.2.0, summary documentation,
and the default public/open library-product scope. Compiler-synthesized declarations
are included. No symbols, modules or documentation paragraphs were selected to improve
these ratios. Collection uses the same scope as the shared API evidence workflow.
Canonical JSON remains schema 1.0; existing 0.1.2 evidence is rendered directly.

Toolchain: `Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1) Target: arm64-apple-macosx27.0.0`. SDK: `macOS:26A425`.
Target: `arm64-apple-macosx27.0.0`. The distiller's own row uses its 0.2.0 source and extractor;
other rows use 0.1.2 extraction. Input revisions, source-file counts, module names,
extractor versions and SHA-256 digests are in [the measurement record](InterfaceSize.json).

Source bytes count the tracked implementation files beneath `Sources/` with extensions
`.swift, .c, .h, .m, .mm, .cpp, .cc`, excluding tests, documentation and build outputs.
The distiller row includes the new release's implementation files. Interface bytes count
the entire unsplit default Markdown output, including its header, anchors and fences.
JSON bytes count the entire canonical snapshot, including its terminal newline.
Unavailable collection has no interface or JSON size; it is not counted as zero.

| Package | Source bytes | Interface bytes | JSON bytes | Interface / source |
| --- | ---: | ---: | ---: | ---: |
| [swift-appstoreconnect](https://github.com/swift-library/swift-appstoreconnect/tree/d69fed4872300bbf78f7e172c82499052b7032c7) | 1,354,387 | — | — | unavailable |
| [swift-benchmark](https://github.com/swift-library/swift-benchmark/tree/f54079d4a1e31d39dbedc6bef9822c429b361ee7) | 343,591 | — | — | unavailable |
| [swift-codex](https://github.com/swift-library/swift-codex/tree/80e68cfafd8275e2eb249c2be06e1bf5c4a20fc9) | 348,627 | — | — | unavailable |
| [swift-data-writable](https://github.com/swift-library/swift-data-writable/tree/bee8707d232010040a071270d83e3ba1608fd0cd) | 66,039 | 33,739 | 776,465 | 51.1% |
| [swift-gyb](https://github.com/swift-library/swift-gyb/tree/d5779b29d719afc9a744eae4c110313f5cce1a1e) | 689 | 268 | 2,052 | 38.9% |
| [swift-interface-distiller](https://github.com/swift-library/swift-interface-distiller/tree/v0.2.0) | 131,231 | 52,180 | 1,662,125 | 39.8% |
| [swift-json-schema](https://github.com/swift-library/swift-json-schema/tree/5a0411b33c6b17af002dd799cabe9405e6a3ac97) | 207,888 | 100,107 | 2,583,296 | 48.2% |
| [swift-package-template](https://github.com/swift-library/swift-package-template/tree/64e8138302beacbcee6d09da759737714884214c) | 164 | — | — | unavailable |
| [swift-pdf](https://github.com/swift-library/swift-pdf/tree/e9ceecc992e628b7f555694eafb9f631ac0818eb) | 54,576 | 838,663 | 14,947,269 | 1536.7% |
| [swift-redux](https://github.com/swift-library/swift-redux/tree/b79420e28d6add8ddd725d7ab29f1265e9471b73) | 17,073 | 9,161 | 175,852 | 53.7% |
| [swift-semver](https://github.com/swift-library/swift-semver/tree/38d82eeba787e1ff6b2f615068621632811ce6ca) | 26,753 | 14,802 | 385,866 | 55.3% |
| [swift-sh](https://github.com/swift-library/swift-sh/tree/3035a02639ca99af57d302358425efdf3d57d50d) | 48,031 | — | — | unavailable |
| [swift-userdefault](https://github.com/swift-library/swift-userdefault/tree/6e01cfa1b626e559e5cdcd2c1ae1dcec9098f47b) | 13,506 | 12,345 | 192,501 | 91.4% |

## Coverage and limits

- `swift-appstoreconnect`: Directory symlinks are not a closed source input. The shared workflow also records failed collection for this package.
- `swift-benchmark`: Compiler cannot load BenchmarkTesting: missing Testing and _Testing_Foundation modules. The shared workflow also records failed collection for this package.
- `swift-codex`: Directory symlinks are not a closed source input. The shared workflow also records failed collection for this package.
- `swift-gyb`: no library modules in the default scope; its row measures metadata, not an API.
- `swift-package-template`: Swift subprocess exited 133 without stderr. The shared workflow also records failed collection for this package.
- `swift-sh`: Directory symlinks are not a closed source input. The shared workflow also records failed collection for this package.

The target is roughly half the source size or less. The table reports actual output,
including rows above that target. A source file can expose many synthesized or inherited
members; a small implementation can therefore have a larger interface view. Empty
library scope is not evidence that an executable has no behavior. Collection failures
need separate collector or toolchain work before their ratios can be assessed.

## Version slice

`query API.json slice Version --format swift --max-bytes 8000` selects all
49 in-scope closure symbols with **6,459 payload bytes**;
stdout is **7,313 bytes**, including the snapshot header and omissions.
Both fit within 8,000 bytes. There are 0 budget omissions.
The closure is **truncated**, not complete: 23 external compiler references
are outside the collected snapshot. No format changes that evidence limitation.

## Reproduce

Use the recorded revisions, toolchain and SDK, collect each package's default scope,
then render the resulting canonical JSON with release 0.2.0:

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
