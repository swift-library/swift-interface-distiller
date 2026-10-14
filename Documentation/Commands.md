# Commands

The examples use `.build/` for generated files. `--help` lists the command grammar;
`--version` prints the product version. Errors are JSON on stderr. Command data is
JSON on stdout by default; query and slice can emit Swift or Markdown. `--output`
writes the chosen format atomically to a file.

```sh
interface-distiller configuration --output .build/configuration.json
interface-distiller collect package . --output .build/api.json --report .build/run.json
interface-distiller query .build/api.json lookup MyType
interface-distiller query .build/api.json members MyType
interface-distiller query .build/api.json conformers MyProtocol
interface-distiller query .build/api.json initializers MyType
interface-distiller query .build/api.json returning MyType
interface-distiller query .build/api.json slice MyType --max-symbols 100 --max-bytes 60000
interface-distiller slice .build/api.json MyType --format swift --max-bytes 8000
interface-distiller query .build/api.json members MyType --format markdown --docs full
interface-distiller coverage .build/api.json
interface-distiller render .build/api.json --output-dir .build/markdown --byte-budget 12000
interface-distiller baseline write .build/api.json .build/baseline.json
interface-distiller baseline check .build/api.json .build/baseline.json
interface-distiller compare .build/baseline.json .build/api.json
```

`render` defaults to `--view interface --docs summary`. It writes one Swift code
block per top-level declaration, nests members, includes reported attributes,
access, generics and conformances, and groups external extensions separately.
Summary keeps the leading prose paragraph and stops at a blank line, list,
heading, quote or code block. A comment containing only parameter lists has no
summary. `--docs full` keeps all comment paragraphs; `--docs none` omits documentation.
Standard requirements implied by observed Codable, Equatable, Hashable,
RawRepresentable and CaseIterable conformances are collapsed in readable views.
`--show-implied` expands the collected requirements in render, query and slice;
JSON and the evidence view retain all collected symbols.

For large APIs, `--by-module` writes `index.md` and linked module parts. Each part
keeps top-level declaration boundaries and the same snapshot context. The index
records module declaration counts and the full file sizes. `render --report FILE`
writes per-symbol UTF-8 accounting for the unsplit interface: declaration,
documentation, anchor and overhead bytes. Indexed file totals include their own
context and the index, so they can be larger than the unsplit report.

```sh
interface-distiller render .build/api.json --by-module --output-dir .build/interface
interface-distiller render .build/api.json --report .build/interface-size.json
interface-distiller query .build/api.json members MyType --format swift --show-implied
```
`--view evidence` preserves the detailed evidence view and its original content.
The render result on stdout remains a JSON list of parts (or names and sizes when
`--output-dir` is supplied). Part names are `part-000001.md`, `part-000002.md`, etc.
A render byte budget never splits a type's members; an oversized declaration fails
with `minimumBytes` rather than dropping members.

All query kinds and `slice` accept `--format json|swift|markdown`, defaulting to
JSON. `slice SNAPSHOT SYMBOL...` is an alias for `query SNAPSHOT slice SYMBOL...`.
`--max-symbols` and `--max-bytes` bound the selected payload; byte counts use the
chosen format, including UTF-8 documentation and declaration context. The snapshot
header and explicit omission diagnostics are outside the query budget, so total
stdout can exceed it. Render budgets, by contrast, include the whole Markdown part.
A budgeted non-slice query returns the slice-shaped JSON envelope with state,
omissions, diagnostics and `symbolBytes`; an unbudgeted JSON query keeps its
original result shape. Text views carry those diagnostics as text or Swift comments.
A slice is `complete` when it includes every in-snapshot reference. `truncated`
means a symbol-count or byte budget omitted in-snapshot symbols. JSON separates
`omittedReferences` from `externalReferences`; text views show their counts.
External references do not imply gaps, and collection gaps remain visible in the
snapshot header independently of the selection's state.

For custom builds, edit the configuration JSON explicitly, then supply
`--configuration .build/configuration.json`. Compiler builds must match the
executing `--swift` tool; the SDK path is `--sdk-path`. The target triple carries
the actual deployment floor; `deploymentTarget` records and must match its version
(or `notApplicable` on Linux). Build mode, language mode, conditions, traits and
declared environment live in that configuration. Detected package configurations
use `languageMode: "package"`, honoring each package's manifest language mode;
a numeric mode explicitly overrides all Swift compilations, including dependencies.
No matrix is inferred.

Package collection defaults to library products. Select `--module ModuleName`
(repeatable) to replace that set. Add an explicitly resolved dependency with
`--dependency-module DependencyModule`. Use `--include` and `--exclude` for
symbol globs; exclusion wins. `--include-spi` and `--source-locations` are opt-ins.
Synthesized per-conformer copies are excluded by default; `--include-synthesized`
includes them and records that choice in scope. Protocol extension declarations
and conformances remain in either scope. Empty library scopes return successful,
empty evidence. Extraction includes the selected Apple platform's developer modules
when present, including Testing and its Foundation overlay.

Pre-generated graphs require their producer's configuration:

```sh
interface-distiller normalize .build/graphs --configuration .build/configuration.json \
  --source-root . --source-locations --output .build/api.json
interface-distiller merge .build/macos.json .build/linux.json --output .build/combined.json
interface-distiller query .build/combined.json lookup MyType --configuration-id CONFIGURATION_ID
```

Binary collection requires its exact producer configuration and explicit content
roots, including any imported module search paths. The executing toolchain must
match. A compiler's import failure is an error, never an empty success.

```sh
interface-distiller collect module Example --search-path .build/modules \
  --built-with .build/producer.json --configuration .build/producer.json \
  --output .build/binary-api.json
interface-distiller collect headers Geometry --header include/Geometry.h \
  --source-root include --language c --output .build/c-api.json
interface-distiller collect headers Widgets --header include/Widgets.h \
  --source-root include --language objective-c --output .build/objc-api.json
```

Header collection records the Clang build and C/Objective-C language view. It does
not substitute an inferred Swift imported view. Header paths are explicit;
compiler system headers follow the configured target and SDK.

Compiler diagnostics are separate artifacts. The package mode compares a Git
revision through SwiftPM; the digester mode accepts existing digester dumps.

```sh
interface-distiller diagnose package . --baseline-ref v0.1.0 \
  --output .build/compiler-diagnostics.json
interface-distiller diagnose digester --baseline .build/old-sdk.json \
  --candidate .build/new-sdk.json --output .build/digester-diagnostics.json
```

`--cache` chooses a producer-owned cache directory, normally below `.build/`.
`--timeout` sets each subprocess timeout in seconds (default 600). SIGINT and
SIGTERM cancel active subprocess groups. See [Contracts](Contracts.md) for schema,
completeness, comparison semantics, budgets and stable exit codes.
