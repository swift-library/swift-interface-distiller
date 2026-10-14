# Interface density

Measured 2026-10-15 from the recorded snapshots with renderer implementation
`292f6d63fdd21cee55e6b115e703d3a06a253762`. These are complete default interface views with summary
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

## swift-codex

Tracked source: **348,627 bytes**. Additional generated Swift:
**2,109,916 bytes**. Input commit: `34ffd22fcd05991411c2e74d1e077105e4980ec1`.
The interface changed from **3,729,244** to **2,439,681 bytes**.
There is 1 configuration and 12 collected modules;
0 compiler symbol identities are duplicated across modules.
Symbols in distinct qualified namespaces remain distinct API.

| Component | Before bytes | After bytes |
| --- | ---: | ---: |
| declaration | 1,420,042 | 1,263,299 |
| documentation | 242,933 | 24,462 |
| anchors | 2,063,867 | 1,149,455 |
| overhead | 2,402 | 2,465 |

| Declaration category | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| CaseIterable | 0 | 0 | 0 |
| CodingKeys | 0 | 0 | 0 |
| Decodable | 2,012 | 474,558 | 0 |
| Encodable | 129 | 26,847 | 0 |
| Equatable | 0 | 0 | 0 |
| Hashable | 0 | 0 | 0 |
| RawRepresentable | 1,078 | 252,788 | 0 |
| other declared API | 14,903 | 2,972,649 | 2,437,216 |

| Source origin | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| compiler-implicit member | 2,961 | 699,084 | 0 |
| plugin-generated declaration | 14,430 | 2,910,758 | 2,329,224 |
| tracked declaration | 731 | 117,000 | 107,992 |

| Symbol kind | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| swift.class | 11 | 1,825 | 1,819 |
| swift.enum | 1,249 | 278,763 | 232,449 |
| swift.enum.case | 2,906 | 481,181 | 373,030 |
| swift.init | 5,007 | 1,335,434 | 486,817 |
| swift.method | 332 | 75,771 | 48,633 |
| swift.property | 6,545 | 1,134,955 | 927,036 |
| swift.protocol | 2 | 310 | 310 |
| swift.struct | 1,938 | 392,465 | 343,913 |
| swift.type.method | 7 | 2,641 | 2,385 |
| swift.typealias | 125 | 23,497 | 20,824 |

| Module | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| Codex | 59 | 8,774 | 8,461 |
| CodexAppServerClient | 268 | 60,090 | 58,187 |
| CodexAppServerHummingbird | 10 | 1,906 | 1,780 |
| CodexAppServerNIO | 26 | 3,544 | 3,421 |
| CodexAppServerProtocol | 17,231 | 3,570,923 | 2,291,988 |
| CodexAppServerRuntime | 68 | 11,241 | 8,073 |
| CodexAppServerStdio | 37 | 7,141 | 6,780 |
| CodexAppServerURLSession | 9 | 1,221 | 1,199 |
| CodexAppServerVapor | 11 | 2,002 | 1,865 |
| CodexExec | 244 | 37,593 | 34,631 |
| CodexMCP | 159 | 22,407 | 20,831 |

Category, origin, kind and module tables each account for symbol bytes (declarations,
docs and anchors); overhead is counted separately. The module index is
1,906 bytes; all indexed files together are 2,450,838 bytes.
## swift-userdefault

Tracked source: **13,506 bytes**. Additional generated Swift:
**24,185 bytes**. Input commit: `5bd0952df31e2e7ca4010a8aa53587a776da0b3b`.
The interface changed from **12,340** to **6,323 bytes**.
There is 1 configuration and 2 collected modules;
0 compiler symbol identities are duplicated across modules.
Symbols in distinct qualified namespaces remain distinct API.

| Component | Before bytes | After bytes |
| --- | ---: | ---: |
| declaration | 3,369 | 3,276 |
| documentation | 6,191 | 1,060 |
| anchors | 2,236 | 1,383 |
| overhead | 544 | 604 |

| Declaration category | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| CaseIterable | 0 | 0 | 0 |
| CodingKeys | 0 | 0 | 0 |
| Decodable | 0 | 0 | 0 |
| Encodable | 0 | 0 | 0 |
| Equatable | 0 | 0 | 0 |
| Hashable | 0 | 0 | 0 |
| RawRepresentable | 2 | 285 | 0 |
| other declared API | 31 | 11,511 | 5,719 |

| Source origin | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| plugin-generated declaration | 18 | 8,856 | 3,120 |
| tracked declaration | 15 | 2,940 | 2,599 |

| Symbol kind | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| swift.associatedtype | 1 | 80 | 80 |
| swift.extension | 2 | 374 | 374 |
| swift.init | 17 | 8,627 | 2,774 |
| swift.method | 8 | 1,716 | 1,660 |
| swift.property | 3 | 458 | 302 |
| swift.protocol | 1 | 380 | 380 |
| swift.struct | 1 | 161 | 149 |

| Module | Symbols | Before bytes | After bytes |
| --- | ---: | ---: | ---: |
| UserDefault | 30 | 11,202 | 5,410 |
| UserDefaultUtils | 3 | 594 | 309 |

Category, origin, kind and module tables each account for symbol bytes (declarations,
docs and anchors); overhead is counted separately. The module index is
678 bytes; all indexed files together are 7,444 bytes.

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
