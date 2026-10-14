# ``InterfaceDistiller``

Collect, query and compare public-interface evidence with explicit provenance.

@Metadata {
    @PageImage(purpose: icon, source: "Logo.png", alt: "Interface Distiller")
    @PageColor(blue)
}

## Overview

``InterfaceCollector`` invokes installed compiler tools and SwiftPM commands.
``SymbolGraphNormalizer`` accepts pre-generated graph inputs. Both produce an
``EvidenceSnapshot`` with separate build configurations, field provenance and
completeness records.

Use ``SnapshotQuery`` for lookup, members, observed conformers, initializer and
return candidates, or a bounded closure. ``SnapshotComparator`` reports changes
without selecting a release policy. ``BaselineStore`` validates before replacing
a baseline; ``CompilerDiagnostics`` keeps toolchain diagnostics separate.

## Topics

### Collection
- ``InterfaceCollector``
- ``Toolchain``
- ``SymbolGraphInput``
- ``SymbolGraphNormalizer``
- ``CollectionScope``

### Evidence
- ``EvidenceSnapshot``
- ``ConfigurationEvidence``
- ``BuildConfiguration``
- ``SymbolRecord``
- ``EvidenceField``
- ``ObservationState``
- ``ProvenanceKind``
- ``PackageStructure``

### Consumption
- ``SnapshotQuery``
- ``MarkdownRenderer``
- ``InterfaceRenderer``
- ``DocumentationStyle``
- ``QueryFormat``
- ``DocumentationCoverage``
- ``SnapshotComparator``
- ``BaselineStore``
- ``CompilerDiagnostics``
