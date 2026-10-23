# Usage guide

## Quick start

From this repository, collect its fixture package, query a declaration, then
render the snapshot:

```sh
.build/release/interface-distiller collect package \
  Tests/InterfaceDistillerTests/Fixtures/Example --output .build/fixture.json
.build/release/interface-distiller query .build/fixture.json lookup Item
.build/release/interface-distiller render .build/fixture.json --output-dir .build/markdown
```

The query includes this compiler identity for `Item`:

```json
{
  "language": "swift",
  "module": "SnapshotExample",
  "preciseIdentifier": "s:15SnapshotExample4ItemV"
}
```

This excerpt selects three fields from the returned symbol. The complete result
also carries the snapshot identity, configuration, declaration fields and
provenance. Markdown is written as `part-000001.md` and subsequent parts when a
byte budget splits the output.

## Usage

Replace the fixture path with a local package path to collect its library
products. Select modules with `--module`, add resolved dependency modules with
`--dependency-module`, and narrow declarations with `--include` and `--exclude`;
exclusion takes precedence. SPI, synthesized per-conformer copies and source
locations are opt-in (`--include-spi`, `--include-synthesized`, `--source-locations`).

```sh
interface-distiller query .build/api.json members MyType --format swift
interface-distiller query .build/api.json slice MyType --format swift --max-bytes 8000
interface-distiller render .build/api.json --output-dir .build/interface --docs summary
interface-distiller render .build/api.json --by-module --output-dir .build/modules
interface-distiller coverage .build/api.json
interface-distiller baseline write .build/api.json .build/baseline.json
interface-distiller baseline check .build/api.json .build/baseline.json
```

Use the installed executable, or substitute `.build/release/interface-distiller`
when running from a checkout. Command data goes to stdout, errors are JSON on
stderr, and failed writes preserve existing baselines. Queries default to JSON;
`--format swift|markdown` selects a readable view.
Rendering defaults to a nested Swift interface with summary documentation; use
`--docs full|none`, `--show-implied` to expand standard conformance requirements,
or `--view symbols` for the detailed symbols view. `--by-module` adds an index
and linked module files for large APIs. Query byte
budgets count the chosen payload format; headers and omission diagnostics remain
outside that budget. A slice is complete when every in-snapshot reference fits;
text views count external references, and JSON retains their identities.
[Commands](../../Documentation/Commands.md) covers
configuration, graph normalization, binary modules, headers and API diagnostics.
