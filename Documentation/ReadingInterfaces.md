# Reading public interfaces

Read a package’s public promises before deciding which implementation files you need.
The collector asks SwiftPM and the compiler for declarations and build context;
it does not guess a public API by scanning source syntax. Each snapshot retains
configuration identity, field provenance and completeness records. Unsupported,
not-collected, failed, filtered and unresolved observations stay distinct; an
unknown observation never becomes a negative fact. The [contracts](Contracts.md)
and [capability matrix](Capabilities.md) define those boundaries.

## A measured package

The published [0.2.0 measurement page](https://github.com/swift-library/swift-interface-distiller/blob/v0.2.0/Documentation/InterfaceSize.md)
and its [record](https://github.com/swift-library/swift-interface-distiller/blob/v0.2.0/Documentation/InterfaceSize.json)
report swift-semver at commit `38d82eeba787e1ff6b2f615068621632811ce6ca`:

| Representation | Bytes |
| --- | ---: |
| Tracked implementation source | 26,753 |
| Default interface Markdown | 9,995 |
| Canonical JSON | 297,002 |

The snapshot contains 67 symbols in the default public/open library-product
scope, excluding synthesized per-conformer copies. The interface is 37.4% of the
tracked source size. Source bytes exclude documentation, tests, dependencies and
build outputs; interface bytes include headings, anchors and fences; JSON counts
the whole canonical snapshot. The measurement page records the compiler, SDK,
configuration and counting rules. It also includes packages whose generated APIs
exceed their tracked source size. These are measured outputs, not a size guarantee.

## Read, query and slice

The default Markdown view nests members beneath their types and uses summary
documentation. Swift text serves code-oriented queries; JSON preserves the full
machine-readable model. Use `--docs full` or `--show-implied` when the question
needs full comments or collected standard conformance requirements.

`query` and `slice` select declarations within symbol and byte budgets. The byte
budget counts the chosen payload format; snapshot context and explicit omission
diagnostics are outside that budget. Truncation, external references and collection
gaps remain separate observations. [Commands](Commands.md) documents selectors,
formats, budgets and the complete-slice contract.

## Compare releases

The organization’s [shared workflows](https://github.com/swift-library/.github/blob/master/Documentation/Reference/WorkflowIntegration.md)
attach public API snapshots to releases and report API changes on pull requests.
The distiller compares declarations, documentation, availability and provenance;
compiler compatibility diagnostics remain a separate artifact. This gives people
Markdown they can review and machines JSON they can query and diff.

Normalization produces byte-identical evidence for identical observations on
macOS and Linux. That is separate from reproducing a compiler build: sources,
dependencies, compiler, SDK, target and selected configuration belong to snapshot
identity. The [determinism contract](Contracts.md) defines the inputs and the tests
exercise shuffled inputs, checkout paths, caches and concurrent runs.

## What it is not

The distiller does not choose SemVer bumps or maintain release policy. It does
not index implementation usages or choose source files for a task; those belong
to an upper layer. Compiler collection may build a package, while consuming an
existing snapshot through the library does not run a compiler.
