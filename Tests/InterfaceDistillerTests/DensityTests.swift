// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import InterfaceDistiller

private func impliedSnapshot() throws -> EvidenceSnapshot {
  try SymbolGraphNormalizer.normalize(
    SymbolGraphInput.load(
      #require(
        Bundle.module.url(
          forResource: "ImpliedGraphs", withExtension: nil, subdirectory: "Fixtures"))),
    configuration: fixtureConfiguration)
}

@Test func conformanceRequirementsCollapseWithoutChangingEvidence() throws {
  let snapshot = try impliedSnapshot()
  let original = try CanonicalJSON.encode(snapshot)
  let collapsed = try MarkdownRenderer.render(snapshot).map(\.markdown).joined()
  let expanded = try MarkdownRenderer.render(snapshot, showImplied: true).map(\.markdown).joined()
  for name in ["ImpliedInterface", "ImpliedExpanded"] {
    let expected = try String(
      contentsOf: #require(
        Bundle.module.url(
          forResource: name, withExtension: "md", subdirectory: "Fixtures")), encoding: .utf8)
    #expect((name == "ImpliedInterface" ? collapsed : expanded) == expected)
  }
  let categories = ImpliedMembers.categories(in: snapshot.configurations[0])
  #expect(
    Set(categories.values).isSuperset(of: [
      "Decodable", "RawRepresentable", "Hashable", "Equatable", "CaseIterable",
    ]))
  #expect(collapsed.utf8.count < expanded.utf8.count)
  #expect(collapsed.contains("public init(from value: Int)"))
  #expect(collapsed.contains("public init(rawValue: Int)"))
  #expect(collapsed.contains("public enum CodingKeys"))
  #expect(collapsed.contains("extension DecoderDefaults"))
  #expect(collapsed.contains("public init(from decoder: any Decoder) throws"))
  #expect(try CanonicalJSON.encode(snapshot) == original)
  #expect(
    try MarkdownRenderer.render(snapshot, view: .evidence).map(\.markdown)
      == MarkdownRenderer.render(snapshot, view: .evidence, showImplied: true).map(\.markdown))
}

@Test func documentationSummaryRecognizesMarkdownBlockBoundaries() throws {
  for block in [
    "- Parameters:", "* A list", "1. A step", "## Details", "```swift", "~~~swift", "    example()",
    "> A quote",
  ] {
    var snapshot = try fixtureSnapshot()
    let index = try #require(snapshot.configurations[0].symbols.firstIndex { $0.name == "Item" })
    func docs(_ lines: [String]) -> EvidenceField {
      EvidenceField(
        .object(["lines": .array(lines.map { .object(["text": .string($0)]) })]),
        provenance: .derived)
    }
    snapshot.configurations[0].symbols[index].fields["docComment"] = docs([
      "First prose paragraph.", "A continuation with Unicode: résumé.", block,
      "Details to exclude.",
    ])
    let summary = try MarkdownRenderer.render(snapshot).map(\.markdown).joined()
    #expect(summary.contains("/// A continuation with Unicode: résumé."))
    #expect(!summary.contains("Details to exclude."))
    #expect(
      try MarkdownRenderer.render(snapshot, docs: .full).map(\.markdown).joined().contains(
        "Details to exclude."))
    snapshot.configurations[0].symbols[index].fields["docComment"] = docs([
      block, "Details to exclude.",
    ])
    #expect(
      !(try MarkdownRenderer.render(snapshot).map(\.markdown).joined()).contains(
        "Details to exclude."))
  }
}

@Test func compactAnchorsUseOwnerAndNameWithStableCollisionSuffixes() throws {
  var snapshot = try fixtureSnapshot()
  let item = try #require(snapshot.configurations[0].symbols.first { $0.name == "Item" })
  var fields = item.fields
  let labels = (0..<100).map { "parameter\($0):" }.joined()
  fields["pathComponents"]?.value = .array([
    .string("Namespace"), .string("DenseItem"), .string("init(" + labels + ")"),
  ])
  let first = SymbolRecord(
    module: item.module, language: "swift", preciseIdentifier: "first-init", fields: fields)
  snapshot.configurations[0].symbols.append(first)
  let key = snapshot.configurations[0].id + ":" + first.id
  #expect(InterfaceRenderer.anchors(in: snapshot)[key] == "evidenceexample-denseitem-init")
  let second = SymbolRecord(
    module: item.module, language: "swift", preciseIdentifier: "second-init", fields: fields)
  snapshot.configurations[0].symbols.append(second)
  let anchors = InterfaceRenderer.anchors(in: snapshot)
  #expect(anchors[key]?.hasPrefix("evidenceexample-denseitem-init-") == true)
  #expect(Set(anchors.values).count == anchors.count)
  snapshot.configurations[0].symbols.reverse()
  #expect(InterfaceRenderer.anchors(in: snapshot) == anchors)
}

@Test func moduleIndexKeepsEveryDeclarationAndBudgetBoundary() throws {
  var snapshot = try fixtureSnapshot()
  let item = try #require(snapshot.configurations[0].symbols.first { $0.name == "Item" })
  snapshot.configurations[0].symbols.append(
    SymbolRecord(
      module: "Other", language: "swift", preciseIdentifier: "other-item", fields: item.fields))
  snapshot.configurations[0].collectedModules.append("Other")
  snapshot.configurations[0].expectedModules.append("Other")
  let parts = try MarkdownRenderer.render(snapshot, byteBudget: 1400, byModule: true)
  #expect(parts.first?.name == "index.md")
  #expect(parts.allSatisfy { $0.markdown.utf8.count <= 1400 })
  let index = try #require(parts.first).markdown
  for part in parts.dropFirst() { #expect(index.contains("(" + part.name + ")")) }
  let all = parts.dropFirst().map(\.markdown).joined()
  for anchor in InterfaceRenderer.anchors(in: snapshot).values {
    #expect(all.components(separatedBy: "id=\"" + anchor + "\"").count == 2)
  }
  #expect(throws: DistillerError.self) {
    try MarkdownRenderer.render(snapshot, byteBudget: 100, byModule: true)
  }
  #expect(throws: DistillerError.self) {
    try MarkdownRenderer.render(snapshot, view: .evidence, byModule: true)
  }
}

@Test func sizeReportsAccountForUTF8AndCollapsedSymbols() throws {
  let snapshot = try impliedSnapshot()
  for showImplied in [false, true] {
    let report = try InterfaceRenderer.measure(snapshot, showImplied: showImplied)
    #expect(
      try report.totalBytes
        == MarkdownRenderer.render(snapshot, showImplied: showImplied)
        .reduce(0) { $0 + $1.markdown.utf8.count })
    #expect(report.symbols.count == snapshot.configurations[0].symbols.count)
    #expect(report.overheadBytes >= 0)
    #expect(
      report.symbols.reduce(report.overheadBytes) {
        $0 + $1.declarationBytes + $1.documentationBytes + $1.anchorBytes
      } == report.totalBytes)
    #expect(
      report.symbols.filter { $0.impliedBy != nil }.allSatisfy {
        showImplied
          ? $0.declarationBytes > 0
          : $0.declarationBytes == 0 && $0.anchorBytes == 0 && $0.documentationBytes == 0
      })
  }
}

@Test func impliedViewPolicyCountsChosenFormatBudgets() throws {
  let query = try SnapshotQuery(impliedSnapshot())
  let collapsed = try query.slice(roots: ["Flags"], format: .swift)
  let expanded = try query.slice(roots: ["Flags"], format: .swift, showImplied: true)
  #expect(collapsed.symbols == expanded.symbols)
  #expect(collapsed.state == "complete" && expanded.state == "complete")
  #expect(collapsed.symbolBytes < expanded.symbolBytes)
  #expect(
    try query.slice(roots: ["Flags"], maximumBytes: collapsed.symbolBytes, format: .swift).state
      == "complete")
  #expect(
    try query.slice(
      roots: ["Flags"], maximumBytes: collapsed.symbolBytes, format: .swift, showImplied: true
    ).state == "truncated")
  #expect(
    try query.encode(query.slice(roots: ["Flags"]), format: .json)
      == query.encode(query.slice(roots: ["Flags"], showImplied: true), format: .json))
}

@Test func requirementMatchingKeepsUnknownSignaturesAndForeignProtocols() throws {
  var snapshot = try impliedSnapshot()
  let original = ImpliedMembers.categories(in: snapshot.configurations[0])
  let decoder = try #require(
    snapshot.configurations[0].symbols.firstIndex {
      original[$0.id] == "Decodable"
    })
  snapshot.configurations[0].symbols[decoder].fields["functionSignature"] =
    EvidenceField(.null, state: .notCollected, provenance: .derived)
  #expect(
    ImpliedMembers.categories(in: snapshot.configurations[0])[
      snapshot.configurations[0].symbols[decoder].id] == nil)
  snapshot.configurations[0].relationships = snapshot.configurations[0].relationships.map {
    var edge = $0
    if edge.kind == "conformsTo", ["s:Se", "s:SH", "s:SQ"].contains(edge.target) {
      edge.target = "foreign-protocol"
    }
    return edge
  }
  let categories = ImpliedMembers.categories(in: snapshot.configurations[0])
  #expect(!categories.values.contains("Decodable"))
  #expect(!categories.values.contains("Equatable"))
  #expect(!categories.values.contains("Hashable"))
}

@Test func anchorCollisionsScaleWithoutRepeatedIdentityHashing() throws {
  var snapshot = try fixtureSnapshot()
  let item = try #require(snapshot.configurations[0].symbols.first { $0.name == "Item" })
  snapshot.configurations[0].symbols = (0..<1000).map {
    SymbolRecord(
      module: item.module, language: item.language,
      preciseIdentifier: "collision-\($0)", fields: item.fields)
  }
  let anchors = InterfaceRenderer.anchors(in: snapshot)
  #expect(anchors.count == 1000 && Set(anchors.values).count == 1000)
  snapshot.configurations[0].symbols.reverse()
  #expect(InterfaceRenderer.anchors(in: snapshot) == anchors)
}
