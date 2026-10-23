// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import InterfaceDistiller

let fixtureConfiguration: BuildConfiguration = {
  var config = BuildConfiguration(
    toolchain: "fixture compiler", sdk: "fixture-sdk", triple: "fixture-target",
    deploymentTarget: "fixture-floor")
  config.extractorVersion = "0.2.0"
  return config
}()

func fixtureGraphs() throws -> [SymbolGraphInput] {
  try SymbolGraphInput.load(
    #require(Bundle.module.url(forResource: "Graphs", withExtension: nil, subdirectory: "Fixtures"))
  )
}

func fixtureSnapshot(scope: CollectionScope = .init(includeSPI: true)) throws -> EvidenceSnapshot {
  try SymbolGraphNormalizer.normalize(
    fixtureGraphs(), configuration: fixtureConfiguration, scope: scope)
}

@Test func compilerFixtureMatchesGoldenProjection() throws {
  let evidence = try fixtureSnapshot().configurations[0]
  let projection: JSONValue = .object([
    "symbols": .array(
      evidence.symbols.map {
        .string(
          $0.name + "|" + ($0.fields["kind"]?.value["identifier"].string ?? "") + "|"
            + $0.preciseIdentifier)
      }.sorted { ($0.string ?? "") < ($1.string ?? "") }),
    "relationships": .array(
      Set(evidence.relationships.map { $0.kind + "|" + $0.source + "|" + $0.target }).sorted().map(
        JSONValue.string)),
  ])
  let expected = try JSONValue.read(
    #require(
      Bundle.module.url(
        forResource: "ExpectedProjection", withExtension: "json", subdirectory: "Fixtures")))
  #expect(projection == expected)
}

func testDirectory(_ name: String) throws -> URL {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
  let url = root.appendingPathComponent(".build/test-output/" + name)
  if FileManager.default.fileExists(atPath: url.path) {
    try FileManager.default.removeItem(at: url)
  }
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

@Test func normalizationIgnoresInputOrderingAndLocations() throws {
  let inputs = try fixtureGraphs()
  let first = try SymbolGraphNormalizer.normalize(inputs, configuration: fixtureConfiguration)
  let shuffled = inputs.reversed().map { input -> SymbolGraphInput in
    var object = input.value.object
    object["symbols"] = .array(object["symbols"]!.array.reversed())
    object["relationships"] = .array(object["relationships"]!.array.reversed())
    return SymbolGraphInput(value: .object(object))
  }
  let second = try SymbolGraphNormalizer.normalize(shuffled, configuration: fixtureConfiguration)
  #expect(try CanonicalJSON.encode(first) == CanonicalJSON.encode(second))
  #expect(first.configurations[0].graphs.count == 2)
  #expect(
    first.configurations[0].symbols.contains {
      $0.fields["kind"]?.value["identifier"].string == "swift.extension"
    })
}

@Test func queryKindsAndCoverageHaveDefinedResults() throws {
  let snapshot = try fixtureSnapshot()
  let query = try SnapshotQuery(snapshot)
  let item = try #require(query.lookup("Item").symbols.first)
  #expect(query.lookup(item.preciseIdentifier).symbols.count == 1)
  #expect(query.members(of: item.id).symbols.contains { $0.name == "name" })
  #expect(query.initializers(of: "Item").symbols.count == 1)
  #expect(query.returning("Item").symbols.contains { $0.name == "make()" })
  #expect(query.observedConformers(to: "Named").symbols.contains { $0.name == "Item" })
  #expect(query.lookup("unknown-symbol").symbols.isEmpty)
  let coverage = DocumentationCoverage.measure(query.evidence)
  #expect(coverage.eligible == 17)
  #expect(coverage.documented == 6)
  #expect(coverage.undocumented.count == coverage.eligible - coverage.documented)
}

@Test func emptyGraphRetainsModuleAndHasNoCoverage() throws {
  var graph = try #require(fixtureGraphs().first).value.object
  graph["symbols"] = .array([])
  graph["relationships"] = .array([])
  let snapshot = try SymbolGraphNormalizer.normalize(
    [.init(value: .object(graph))], configuration: fixtureConfiguration,
    expectedModules: ["EvidenceExample"])
  let query = try SnapshotQuery(snapshot)
  #expect(query.evidence.collectedModules == ["EvidenceExample"])
  #expect(query.evidence.symbols.isEmpty)
  #expect(query.lookup("missing").symbols.isEmpty)
  let coverage = DocumentationCoverage.measure(query.evidence)
  #expect(coverage.eligible == 0)
  #expect(coverage.documented == 0)
  #expect(coverage.fraction == nil)
  #expect(
    try JSONDecoder().decode(EvidenceSnapshot.self, from: CanonicalJSON.encode(snapshot))
      == snapshot)
}

@Test func sliceReportsOmittedReferencesAndBudgets() throws {
  let query = try SnapshotQuery(fixtureSnapshot())
  let result = try query.slice(roots: ["Item"], maximumSymbols: 1)
  #expect(result.state == "truncated")
  #expect(result.symbols.count == 1)
  #expect(!result.omittedReferences.isEmpty)
  #expect(result.diagnostics.contains("Symbol payload budget exhausted"))
  let external = try query.slice(roots: ["Item"])
  #expect(external.externalReferences.contains("s:SS"))
  #expect(external.state == "complete")
  #expect(external.omittedReferences.isEmpty)
  let empty = try query.slice(roots: [])
  #expect(empty.state == "complete")
  #expect(empty.symbols.isEmpty)
}

@Test func duplicateAndConflictRecordsPreserveObservations() throws {
  let graphs = try fixtureGraphs()
  let duplicated = try SymbolGraphNormalizer.normalize(
    graphs + graphs, configuration: fixtureConfiguration)
  #expect(duplicated.configurations[0].merges.contains { $0.kind == "duplicateGraph" })
  var changed = try #require(
    graphs.first { $0.value["symbols"].array.contains { $0["names"]["title"].string == "Item" } })
  var root = changed.value.object
  var symbols = changed.value["symbols"].array
  let index = try #require(symbols.firstIndex { $0["names"]["title"].string == "Item" })
  var symbol = symbols[index].object
  symbol["accessLevel"] = .string("open")
  symbols[index] = .object(symbol)
  root["symbols"] = .array(symbols)
  changed.value = .object(root)
  let conflict = try SymbolGraphNormalizer.normalize(
    graphs + [changed], configuration: fixtureConfiguration)
  #expect(conflict.configurations[0].merges.filter { $0.kind == "conflict" }.count == 1)
  #expect(!conflict.configurations[0].symbols.contains { $0.name == "Item" })
  let file = try testDirectory("conflict-baseline").appendingPathComponent("baseline.json")
  try BaselineStore.write(fixtureSnapshot(), to: file)
  let before = try Data(contentsOf: file)
  #expect(throws: DistillerError.self) { try BaselineStore.write(conflict, to: file) }
  #expect(try Data(contentsOf: file) == before)
}

@Test func accessSPIFiltersAndUnknownIsolationRemainSeparate() throws {
  let all = try fixtureSnapshot()
  let normal = try fixtureSnapshot(scope: .init())
  let inspect = try #require(all.configurations[0].symbols.first { $0.name == "inspect()" })
  #expect(inspect.fields["accessLevel"]?.value == .string("public"))
  #expect(inspect.fields["spi"]?.value == .bool(true))
  #expect(!normal.configurations[0].symbols.contains { $0.id == inspect.id })
  let item = try #require(all.configurations[0].symbols.first { $0.name == "Item" })
  #expect(item.fields["reportedConcurrency"]?.state == .notCollected)
  let excluded = try fixtureSnapshot(
    scope: .init(include: ["*"], exclude: ["Item"], includeSPI: true))
  #expect(!excluded.configurations[0].symbols.contains { $0.name == "Item" })
  let store = try #require(all.configurations[0].symbols.first { $0.name == "Store" })
  #expect(
    store.fields["reportedConcurrency"]?.value.array.contains {
      $0["spelling"].string == "MainActor"
    } == true)
}

@Test func comparisonSeparatesDocumentationAvailabilityAndInterface() throws {
  let base = try fixtureSnapshot()
  var changed = base
  let index = try #require(changed.configurations[0].symbols.firstIndex { $0.name == "Item" })
  changed.configurations[0].symbols[index].fields["docComment"]?.value = .object([
    "lines": .array([.object(["text": .string("Updated documentation")])])
  ])
  changed.configurations[0].symbols[index].fields["availability"] = EvidenceField(
    .array([.object(["domain": .string("*"), "isUnconditionallyDeprecated": .bool(true)])]),
    sources: base.configurations[0].symbols[index].fields["identifier"]!.sources)
  changed.configurations[0].symbols[index].fields["declarationFragments"]?.value = .array([])
  let diff = try SnapshotComparator.compare(base, changed)
  #expect(!diff.equal)
  #expect(
    Set(diff.changes.map(\.category)) == [
      "documentation", "availability", "interface", "provenance",
    ])
  #expect(diff.changes.allSatisfy { $0.path.hasPrefix("/fields/") })
  #expect(try SnapshotComparator.compare(base, base).equal)
}

@Test func schemaAndMultipleConfigurationContracts() throws {
  let base = try fixtureSnapshot()
  let data = try CanonicalJSON.encode(base)
  #expect(try JSONDecoder().decode(EvidenceSnapshot.self, from: data) == base)
  var incompatible = base
  incompatible.schemaVersion = "3.0"
  #expect(throws: DistillerError.self) { try incompatible.validate() }
  var otherConfig = fixtureConfiguration
  otherConfig.conditions = ["EXTRA"]
  let other = try SymbolGraphNormalizer.normalize(fixtureGraphs(), configuration: otherConfig)
  let merged = try EvidenceSnapshot.merge([other, base])
  #expect(merged.configurations.count == 2)
  #expect(throws: DistillerError.self) { try SnapshotQuery(merged) }
  #expect(
    try SnapshotQuery(merged, configuration: base.configurations[0].id).evidence.id
      == base.configurations[0].id)
  #expect(try SnapshotComparator.compare(base, other).incomparableConfigurations.count == 2)
}

@Test func markdownStableAnchorsAndStrictBudgets() throws {
  let snapshot = try fixtureSnapshot()
  let parts = try MarkdownRenderer.render(snapshot, byteBudget: 3000, view: .evidence)
  #expect(parts.allSatisfy { $0.markdown.utf8.count <= 3000 })
  #expect(parts.count > 1)
  let content = parts.map(\.markdown).joined()
  for s in snapshot.configurations[0].symbols {
    #expect(
      content.contains(
        "id=\""
          + MarkdownRenderer.anchor(configuration: snapshot.configurations[0].id, symbol: s.id)
          + "\""))
  }
  #expect(throws: DistillerError.self) {
    try MarkdownRenderer.render(snapshot, byteBudget: 256, view: .evidence)
  }
}

@Test func loaderRejectsMissingEmptyAndMalformedInputs() throws {
  let root = try testDirectory("invalid-graphs")
  #expect(throws: DistillerError.self) { try SymbolGraphInput.load(root) }
  #expect(throws: DistillerError.self) {
    try SymbolGraphInput.load(root.appendingPathComponent("missing"))
  }
  let file = root.appendingPathComponent("bad.symbols.json")
  try Data("{".utf8).write(to: file)
  #expect(throws: DistillerError.self) { try SymbolGraphInput.load(file) }
}

@Test func invalidProvenanceAndSchemaCannotReplaceBaseline() throws {
  let baseline = try testDirectory("invalid-provenance").appendingPathComponent("baseline.json")
  let valid = try fixtureSnapshot()
  try BaselineStore.write(valid, to: baseline)
  let original = try Data(contentsOf: baseline)
  var invalid = valid
  invalid.schemaVersion = "1.invalid"
  #expect(throws: DistillerError.self) { try BaselineStore.write(invalid, to: baseline) }
  invalid = valid
  invalid.configurations[0].symbols[0].fields["identifier"]?.sources = ["missing-graph"]
  #expect(throws: DistillerError.self) { try BaselineStore.write(invalid, to: baseline) }
  invalid.configurations[0].symbols[0].fields["identifier"]?.sources = []
  #expect(throws: DistillerError.self) { try BaselineStore.write(invalid, to: baseline) }
  #expect(try Data(contentsOf: baseline) == original)
}

@Test func graphFormatAndRelativeLocationBoundaries() throws {
  var graph = try #require(fixtureGraphs().first)
  var root = graph.value.object
  root["metadata"] = .object(["formatVersion": .object(["major": .number(0)])])
  graph.value = .object(root)
  #expect(throws: DistillerError.self) {
    try SymbolGraphNormalizer.normalize([graph], configuration: fixtureConfiguration)
  }
  let unsafe = JSONValue.object(["location": .object(["uri": .string("../outside.swift")])])
  #expect(
    SymbolGraphNormalizer.portableValue(unsafe, root: nil, locations: true)["location"]["uri"]
      == .null)
  let relative = JSONValue.object(["location": .object(["uri": .string("Sources/Item.swift")])])
  #expect(SymbolGraphNormalizer.portableValue(relative, root: nil, locations: true) == relative)
  #expect(
    SymbolGraphNormalizer.portableValue(relative, root: nil, locations: false)["location"] == .null)
}

@Test func comparisonReportsCollectionProvenanceWithoutInterfaceChanges() throws {
  let baseline = try fixtureSnapshot()
  var candidate = baseline
  candidate.configurations[0].inputDigest = Digest.sha256(Data("new input".utf8))
  candidate.configurations[0].graphs[0].generator = "another reported producer"
  let difference = try SnapshotComparator.compare(baseline, candidate)
  #expect(!difference.equal)
  #expect(difference.added.isEmpty && difference.removed.isEmpty)
  #expect(Set(difference.changes.map(\.category)) == ["provenance"])
  #expect(Set(difference.changes.map(\.path)) == ["/inputDigest", "/graphs"])
  let first = Relationship(
    module: "Example", language: "swift", kind: "memberOf", source: "a", target: "b",
    fields: ["condition": EvidenceField(.string("same"), sources: ["first"])])
  var second = first
  second.fields["condition"]?.sources = ["second"]
  let merged = try SymbolGraphNormalizer.mergedRelationships([first, second])
  #expect(merged.count == 1)
  #expect(merged[0].fields["condition"]?.sources == ["first", "second"])
}

@Test func externalReferenceMetadataChangesAreCompared() throws {
  let baseline = try fixtureSnapshot()
  var candidate = baseline
  candidate.configurations[0].externalReferences?.append("additional-external-reference")
  let difference = try SnapshotComparator.compare(baseline, candidate)
  #expect(!difference.equal)
  #expect(
    difference.changes.contains { $0.path == "/externalReferences" && $0.category == "provenance" })
}

@Test func normalizationHonorsTaskCancellation() async throws {
  let graphs = try fixtureGraphs()
  let task = Task {
    withUnsafeCurrentTask { $0?.cancel() }
    return try SymbolGraphNormalizer.normalize(graphs, configuration: fixtureConfiguration)
  }
  do {
    _ = try await task.value
    Issue.record("Expected cancelled normalization")
  } catch is CancellationError {}
}
