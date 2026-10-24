# Interface density

Measured 2026-10-15 from the recorded snapshots with renderer implementation
`caa2444d4e6cc2fc7f11afded6a1c4361e49844c`. The comparison is renderer 0.2.0 to 0.3.1 with summary
docs and collapsed implied members in both. Source, generated Swift and JSON definitions are shared with
[Interface size measurements](InterfaceSize.md). Canonical snapshots are unchanged
for these two packages. `render --report` provides the current per-symbol byte
accounting. Reference Markdown and per-symbol accounting are retained as run outputs.

Source origins come from a separate compiler extraction with locations, joined by
module, language and precise identifier. Located declarations beneath Sources are
tracked declarations. Build-plugin outputs and source directives naming a verified
local generation template identify plugin-generated declarations. Members with no
source location are compiler-implicit; here they are decoding and raw-value
initializers. This origin classification is distinct from the presentation rule:
standard requirements may be declared explicitly and still be implied by conformance.
No compiler witness selection is inferred.

## Block anchors

Every interface code block has one top-level anchor. Member and nested-type links
target that block. Standalone extension blocks retain anchors; extensions within
a type's block share the type's destination. The symbols view keeps per-symbol IDs.
Each row measures the complete unsplit interface, including metadata and fences.
The self-row was recollected at the new renderer implementation.

| Package | 0.2.0 bytes | 0.3.1 bytes | Anchors before | Anchors after | Anchor bytes before | Anchor bytes after |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `swift-appstoreconnect` | 4,886,009 | 2,781,942 | 28,749 | 407 | 2,133,592 | 29,525 |
| `swift-benchmark` | 122,216 | 79,825 | 1,004 | 143 | 48,206 | 5,815 |
| `swift-codex` | 2,439,681 | 1,294,628 | 14,903 | 92 | 1,149,455 | 4,402 |
| `swift-data-writable` | 32,710 | 23,333 | 149 | 15 | 10,186 | 809 |
| `swift-gyb` | 399 | 399 | 0 | 0 | 0 | 0 |
| `swift-interface-distiller` | 38,547 | 23,425 | 317 | 49 | 17,528 | 2,341 |
| `swift-json-schema` | 58,044 | 44,647 | 333 | 68 | 16,157 | 2,760 |
| `swift-package-template` | 399 | 399 | 0 | 0 | 0 | 0 |
| `swift-pdf` | 10,658 | 8,854 | 53 | 9 | 2,089 | 285 |
| `swift-redux` | 5,941 | 5,176 | 33 | 14 | 1,194 | 429 |
| `swift-semver` | 9,995 | 7,281 | 61 | 2 | 2,781 | 67 |
| `swift-sh` | 399 | 399 | 0 | 0 | 0 | 0 |
| `swift-userdefault` | 6,323 | 5,086 | 31 | 4 | 1,383 | 146 |

## swift-codex

Tracked source: **348,627 bytes**. Additional generated Swift:
**2,109,916 bytes**. Input commit: `34ffd22fcd05991411c2e74d1e077105e4980ec1`.
The interface changed from **2,439,681** to **1,294,628 bytes**.
There is 1 configuration and 12 collected modules;
0 compiler symbol identities are duplicated across modules.
Symbols in distinct qualified namespaces remain distinct API.

| Component | Before bytes | After bytes |
| --- | ---: | ---: |
| declaration | 1,263,299 | 1,263,299 |
| documentation | 24,462 | 24,462 |
| anchors | 1,149,455 | 4,402 |
| overhead | 2,465 | 2,465 |

| Declaration category | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| CaseIterable | 0 | 0 | 0 |
| CodingKeys | 0 | 0 | 0 |
| Decodable | 2,012 | 0 | 0 |
| Encodable | 129 | 0 | 0 |
| Equatable | 0 | 0 | 0 |
| Hashable | 0 | 0 | 0 |
| RawRepresentable | 1,078 | 0 | 0 |
| other declared API | 14,903 | 2,437,216 | 1,292,163 |

| Source origin | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| compiler-implicit member | 2,961 | 0 | 0 |
| plugin-generated declaration | 14,430 | 2,329,224 | 1,221,240 |
| tracked declaration | 731 | 107,992 | 70,923 |

| Symbol kind | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| swift.class | 11 | 1,819 | 1,819 |
| swift.enum | 1,249 | 232,449 | 139,022 |
| swift.enum.case | 2,906 | 373,030 | 156,058 |
| swift.init | 5,007 | 486,817 | 341,300 |
| swift.method | 332 | 48,633 | 33,545 |
| swift.property | 6,545 | 927,036 | 414,309 |
| swift.protocol | 2 | 310 | 310 |
| swift.struct | 1,938 | 343,913 | 191,528 |
| swift.type.method | 7 | 2,385 | 1,920 |
| swift.typealias | 125 | 20,824 | 12,352 |

| Module | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| Codex | 59 | 8,461 | 6,699 |
| CodexAppServerClient | 268 | 58,187 | 38,912 |
| CodexAppServerHummingbird | 10 | 1,780 | 1,201 |
| CodexAppServerNIO | 26 | 3,421 | 1,898 |
| CodexAppServerProtocol | 17,231 | 2,291,988 | 1,195,648 |
| CodexAppServerRuntime | 68 | 8,073 | 4,405 |
| CodexAppServerStdio | 37 | 6,780 | 4,202 |
| CodexAppServerURLSession | 9 | 1,199 | 630 |
| CodexAppServerVapor | 11 | 1,865 | 1,303 |
| CodexExec | 244 | 34,631 | 23,524 |
| CodexMCP | 159 | 20,831 | 13,741 |

Category, origin, kind and module tables each account for symbol bytes (declarations,
docs and anchors); overhead is counted separately. The module index is
1,906 bytes; all indexed files together are 1,305,785 bytes.
## swift-userdefault

Tracked source: **13,506 bytes**. Additional generated Swift:
**24,185 bytes**. Input commit: `5bd0952df31e2e7ca4010a8aa53587a776da0b3b`.
The interface changed from **6,323** to **5,086 bytes**.
There is 1 configuration and 2 collected modules;
0 compiler symbol identities are duplicated across modules.
Symbols in distinct qualified namespaces remain distinct API.

| Component | Before bytes | After bytes |
| --- | ---: | ---: |
| declaration | 3,276 | 3,276 |
| documentation | 1,060 | 1,060 |
| anchors | 1,383 | 146 |
| overhead | 604 | 604 |

| Declaration category | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| CaseIterable | 0 | 0 | 0 |
| CodingKeys | 0 | 0 | 0 |
| Decodable | 0 | 0 | 0 |
| Encodable | 0 | 0 | 0 |
| Equatable | 0 | 0 | 0 |
| Hashable | 0 | 0 | 0 |
| RawRepresentable | 2 | 0 | 0 |
| other declared API | 31 | 5,719 | 4,482 |

| Source origin | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| plugin-generated declaration | 18 | 3,120 | 2,458 |
| tracked declaration | 15 | 2,599 | 2,024 |

| Symbol kind | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| swift.associatedtype | 1 | 80 | 30 |
| swift.extension | 2 | 374 | 374 |
| swift.init | 17 | 2,774 | 2,150 |
| swift.method | 8 | 1,660 | 1,192 |
| swift.property | 3 | 302 | 207 |
| swift.protocol | 1 | 380 | 380 |
| swift.struct | 1 | 149 | 149 |

| Module | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| UserDefault | 30 | 5,410 | 4,173 |
| UserDefaultUtils | 3 | 309 | 309 |

Category, origin, kind and module tables each account for symbol bytes (declarations,
docs and anchors); overhead is counted separately. The module index is
678 bytes; all indexed files together are 6,207 bytes.

## Interpretation

Removing member anchors changes navigation output without omitting declarations
or documentation. The component tables account for that reduction; member anchor
bytes become zero and collisions are computed only between top-level blocks.

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
begin with parameter lists and have no leading prose paragraph. Summary mode
omits those lists and full mode preserves them. Original
protocol-extension declarations remain. The complete summary interface stays
below half the tracked source size.

No Equatable equality members, Hashable hash members, CaseIterable allCases or
CodingKeys are present in these two default snapshots. Their zero rows reflect
the collected symbols. Public CodingKeys declarations remain visible in the regression
fixture because that named type is not required by Codable.
