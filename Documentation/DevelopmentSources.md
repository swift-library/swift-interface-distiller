# Development sources

This record owns implementation provenance and the independent-development audit
boundary. The implementation was developed from the accepted specification,
official toolchain documentation, and selected owner-authored foundations.

## Owner-authored foundations consulted

Read-only consultation of distiller-ultra:

- Root AGENTS.md and README.md for ownership and scope.
- Package/Sources/DistillerDocC/SymbolGraphInputLoader.swift and
  Package/Tests/DistillerDocCTests/SymbolGraphInputLoaderTests.swift: deterministic
  graph discovery and strict input errors. The new decoder owns its JSON model.
- Package/Sources/DistillerCore/Models/PackageGraph.swift, TargetGraph.swift and
  SourceFileIndex.swift: package/product/target/source distinctions. Identity,
  origins, conditions and portable paths are redesigned here.
- SwiftPMStructuralScannerTests.swift and SwiftPMGoldenAcceptanceTests.swift in
  Package/Tests/DistillerSwiftPMTests, plus the StructuralFixture,
  DefaultPathFixture, SpecialTargetKindsFixture and InvalidManifestFixture
  manifests: structural behavior, custom/default paths and invalid manifests.
- Package/Sources/DistillerCore/Models/FactGraphInvariantValidator.swift:
  uniqueness, ordering, provenance and reference validation test methods.
- Excerpts from ArtifactEncodingTests, DistillerFactsTraversalTests,
  GraphProjectionExecutorTests, CoreGraphQueryExecutorRedTests and
  FactsSummaryReportTests in Package/Tests/DistillerCoreTests: round trips,
  deterministic traversal, missing matches, closure and coverage assertions.
- CLIFailureProbeTests and excerpts from CLIQueryProjectionTests in
  Package/Tests/DistillerCLITests: stream separation and failed-operation probes.
  Subprocess implementation was not reused.

These owner-authored foundations are adapted under this repository's license.
The source repository was not modified. No prior distiller implementation,
external implementation, integrated pipeline, source index or syntax adapter
was used. The independent overlap audit belongs to the publication reviewer.

## Toolchain contracts

- Installed Swift 6.3.1 and Apple Swift 6.4 command help for `package`,
  `dump-symbol-graph`, `describe`, `diagnose-api-breaking-changes` and
  `symbolgraph-extract`.
- [SwiftPM documentation](https://docs.swift.org/swiftpm/).
- [SymbolKit graph format documentation](https://github.com/swiftlang/swift-docc-symbolkit/tree/main/Sources/SymbolKit/SymbolKit.docc).
- [Clang ExtractAPI serializer documentation](https://clang.llvm.org/doxygen/classclang_1_1extractapi_1_1SymbolGraphSerializer.html).

## Publication standards

The shared organization repository at
`862ac66095c731ecf037e79ceafc7291d434b019` supplies license, workflow, design and
maintenance conventions. These are publication inputs, not extraction code.

The framework-icon design skill and its geometry, color and iconography references
supply presentation guidance. The generator is consumed read-only from
`showxu/skills` at `6bc0813a95365107a00b9d1d04f4ab4b19618396`; no skill content was
changed. The website's Inter 4.1 font (SIL Open Font License) supplies outlined
social-card lettering, not a redistributed font dependency. Official Swift 6.3.1
installation/signature instructions and Ubuntu 24.04 cloud-image checksums were
used to provision isolated Linux validation.
