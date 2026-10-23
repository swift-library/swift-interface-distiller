# ``InterfaceDistiller``

Distill a Swift package to its public API: a compact interface to read, snapshots to query and diff.

@Metadata {
    @PageImage(purpose: icon, source: "Logo.png", alt: "Interface Distiller")
    @PageColor(blue)
}

## Overview

Read public declarations reported by the compiler without walking a package’s implementation. Markdown serves people and JSON serves machines, with explicit gaps and deterministic normalization for identical observations. See the [interface guide](https://github.com/swift-library/swift-interface-distiller/blob/master/Documentation/ReadingInterfaces.md) for measured sizes, budgets, collection scope, and limits.

## Topics

### Collection
- ``InterfaceCollector``
- ``Toolchain``
- ``SymbolGraphInput``
- ``SymbolGraphNormalizer``
- ``CollectionScope``

### Snapshots
- ``InterfaceSnapshot``
- ``ConfigurationSnapshot``
- ``BuildConfiguration``
- ``SymbolRecord``
- ``ObservedField``
- ``ObservationState``
- ``ProvenanceKind``
- ``PackageStructure``

### Consumption
- ``SnapshotQuery``
- ``MarkdownRenderer``
- ``InterfaceRenderer``
- ``InterfaceSizeReport``
- ``InterfaceSymbolSize``
- ``DocumentationStyle``
- ``QueryFormat``
- ``DocumentationCoverage``
- ``SnapshotComparator``
- ``BaselineStore``
- ``CompilerDiagnostics``
