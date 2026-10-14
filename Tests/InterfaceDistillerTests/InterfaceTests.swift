// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import InterfaceDistiller

@Test func readableAndEvidenceViewsMatchSnapshots() throws {
  let snapshot = try fixtureSnapshot()
  for (view, name) in [(MarkdownRenderer.View.interface, "Interface"), (.evidence, "Evidence")] {
    let expected = try String(
      contentsOf: #require(
        Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Fixtures")),
      encoding: .utf8)
    #expect(try MarkdownRenderer.render(snapshot, view: view).map(\.markdown).joined() == expected)
  }
}

@Test func interfaceDeterminismAcrossOrderingAndCheckoutPaths() throws {
  let snapshot = try fixtureSnapshot()
  let expected = try MarkdownRenderer.render(snapshot).map(\.markdown)
  var reordered = snapshot
  reordered.configurations[0].symbols.reverse()
  reordered.configurations[0].relationships.reverse()
  reordered.configurations[0].gaps.reverse()
  #expect(try MarkdownRenderer.render(reordered).map(\.markdown) == expected)
  for checkout in ["checkout-one", "checkout-two"] {
    let root = try testDirectory(checkout)
    let graphs = try fixtureGraphs().map { input -> SymbolGraphInput in
      var graph = input.value.object
      graph["symbols"] = .array(
        input.value["symbols"].array.map { value in
          var symbol = value.object
          symbol["location"] = .object([
            "uri": .string(root.appendingPathComponent("Sources/Example.swift").absoluteString)
          ])
          return .object(symbol)
        })
      return SymbolGraphInput(value: .object(graph), sourceRoot: root)
    }
    let normalized = try SymbolGraphNormalizer.normalize(
      graphs, configuration: fixtureConfiguration, scope: .init(includeSPI: true))
    #expect(try MarkdownRenderer.render(normalized).map(\.markdown) == expected)
  }
}

@Test func interfaceAnchorsAreReadableStableAndDisambiguated() throws {
  var snapshot = try fixtureSnapshot()
  let item = try #require(snapshot.configurations[0].symbols.first { $0.name == "Item" })
  let key = snapshot.configurations[0].id + ":" + item.id
  #expect(InterfaceRenderer.anchors(in: snapshot)[key] == "evidenceexample-item")
  var overload = SymbolRecord(
    module: item.module, language: item.language, preciseIdentifier: "overloaded-item",
    fields: item.fields)
  snapshot.configurations[0].symbols.append(overload)
  let first = InterfaceRenderer.anchors(in: snapshot)
  #expect(first[key]?.hasPrefix("evidenceexample-item-") == true)
  #expect(Set(first.values).count == first.count)
  snapshot.configurations[0].symbols.reverse()
  #expect(InterfaceRenderer.anchors(in: snapshot) == first)
  overload.fields["docComment"] = EvidenceField(.null, provenance: .derived)
  snapshot.configurations[0].symbols = snapshot.configurations[0].symbols.map {
    $0.id == overload.id ? overload : $0
  }
  #expect(InterfaceRenderer.anchors(in: snapshot) == first)
  var config = snapshot.configurations[0].configuration
  config.extractorVersion = "another-extractor"
  snapshot.configurations[0].configuration = config
  snapshot.configurations[0].id = try config.identity()
  #expect(Set(InterfaceRenderer.anchors(in: snapshot).values) == Set(first.values))
}

@Test func interfaceSplitsOnlyBetweenTopLevelDeclarations() throws {
  let snapshot = try fixtureSnapshot()
  let parts = try MarkdownRenderer.render(snapshot, byteBudget: 1300)
  #expect(parts.count > 1)
  #expect(parts.allSatisfy { $0.markdown.utf8.count <= 1300 })
  let shelf = try #require(parts.first { $0.markdown.contains("public struct Shelf") })
  #expect(shelf.markdown.contains("extension Shelf where T == Item"))
  #expect(shelf.markdown.contains("public var firstName"))
  let anchors = InterfaceRenderer.anchors(in: snapshot)
  let content = parts.map(\.markdown).joined()
  for anchor in anchors.values {
    #expect(content.components(separatedBy: "id=\"" + anchor + "\"").count == 2)
  }
  #expect(throws: DistillerError.self) { try MarkdownRenderer.render(snapshot, byteBudget: 700) }
}

@Test func documentationStylesAndFullDeclarations() throws {
  var snapshot = try fixtureSnapshot()
  let index = try #require(snapshot.configurations[0].symbols.firstIndex { $0.name == "Item" })
  snapshot.configurations[0].symbols[index].fields["docComment"]?.value = .object([
    "lines": .array(
      ["Résumé with Unicode.", "", "More details.", "```swift", "example()", "```"].map {
        .object(["text": .string($0)])
      })
  ])
  let summary = try MarkdownRenderer.render(snapshot).map(\.markdown).joined()
  let full = try MarkdownRenderer.render(snapshot, docs: .full).map(\.markdown).joined()
  let none = try MarkdownRenderer.render(snapshot, docs: .none).map(\.markdown).joined()
  #expect(summary.contains("/// Résumé with Unicode."))
  #expect(!summary.contains("More details."))
  #expect(full.contains("/// More details."))
  #expect(full.contains("````swift"))
  #expect(!none.contains("///"))
  #expect(summary.contains("public struct Item: Named, Sendable, SendableMetatype"))
  #expect(summary.contains("@available(*, deprecated, renamed: \"Item\")"))
  #expect(summary.contains("@MainActor public func load() async throws -> Item"))
  #expect(summary.contains("extension Array where Element == Item"))
}

@Test func queryFormatsCountTheirOwnUTF8Payload() throws {
  let query = try SnapshotQuery(fixtureSnapshot())
  for format in [QueryFormat.json, .swift, .markdown] {
    let full = try query.slice(roots: ["Item"], format: format)
    #expect(
      try full.symbolBytes == query.payloadBytes(full.symbols, format: format, docs: .summary))
    let exact = try query.slice(roots: ["Item"], maximumBytes: full.symbolBytes, format: format)
    #expect(exact.symbols == full.symbols)
    let bounded = try query.slice(roots: ["Item"], maximumBytes: 100, format: format)
    #expect(bounded.symbolBytes <= 100)
    #expect(bounded.state == "truncated")
    #expect(bounded.diagnostics.contains("Symbol payload budget exhausted"))
    let lookup = try query.bounded(query.members(of: "Item"), maximumBytes: 100, format: format)
    #expect(lookup.symbolBytes <= 100)
    #expect(!lookup.omittedReferences.isEmpty)
    let bytes = try query.encode(full, format: format)
    if format == .json {
      #expect(try bytes == CanonicalJSON.encode(full))
    } else {
      let text = String(decoding: bytes, as: UTF8.self)
      #expect(text.contains("Omitted references:"))
      #expect(text.contains("public struct Item"))
    }
  }
  let json = try query.slice(roots: ["Item"], maximumBytes: 800)
  let swift = try query.slice(roots: ["Item"], maximumBytes: 800, format: .swift)
  #expect(swift.symbols.count > json.symbols.count)
}

@Test func conditionalConformancesAndNestedExtensionsKeepTheirContext() throws {
  var snapshot = try fixtureSnapshot()
  let c = snapshot.configurations[0]
  let shelf = try #require(c.symbols.first { $0.name == "Shelf" })
  let item = try #require(c.symbols.first { $0.name == "Item" })
  let constraint = JSONValue.array([
    .object(["kind": .string("sameType"), "lhs": .string("T"), "rhs": .string("Item")])
  ])
  snapshot.configurations[0].relationships.append(
    Relationship(
      module: shelf.module, language: shelf.language, kind: "conformsTo",
      source: shelf.preciseIdentifier,
      target: "external-protocol",
      fields: [
        "targetFallback": EvidenceField(.string("Other.Protocol"), provenance: .derived),
        "swiftConstraints": EvidenceField(constraint, provenance: .derived),
      ]))
  snapshot.configurations[0].relationships.append(
    Relationship(
      module: shelf.module, language: shelf.language, kind: "memberOf",
      source: shelf.preciseIdentifier,
      target: item.preciseIdentifier, fields: [:]))
  let index = try #require(snapshot.configurations[0].symbols.firstIndex { $0.id == shelf.id })
  snapshot.configurations[0].symbols[index].fields["pathComponents"]?.value = .array([
    .string("Item"), .string("Shelf"),
  ])
  let text = try MarkdownRenderer.render(snapshot).map(\.markdown).joined()
  #expect(text.contains("  public struct Shelf<T> where T : Named {"))
  #expect(text.contains("\n}\n\nextension Item.Shelf where T == Item"))
  #expect(text.contains("extension Item.Shelf: Other.Protocol where T == Item {}"))
  #expect(!text.contains("struct Shelf<T>: Other.Protocol"))
}

@Test func subsetQueriesCarryAncestorContextAndStableAnchors() throws {
  let snapshot = try fixtureSnapshot()
  let query = try SnapshotQuery(snapshot)
  let result = try query.bounded(query.members(of: "Item"), format: .markdown)
  let text = String(decoding: try query.encode(result, format: .markdown), as: UTF8.self)
  #expect(text.contains("public struct Item"))
  #expect(text.contains("evidenceexample-item-name"))
  #expect(!text.contains("public struct Shelf"))
  let empty = try query.bounded(query.lookup("missing"), format: .swift)
  #expect(empty.symbolBytes == 0)
}

@Test func multipleConfigurationsAndNaturalSuffixCollisionsAreDistinct() throws {
  var snapshot = try fixtureSnapshot()
  var other = snapshot.configurations[0]
  other.configuration.conditions = ["FEATURE"]
  other.id = try other.configuration.identity()
  snapshot.configurations.append(other)
  let anchors = InterfaceRenderer.anchors(in: snapshot)
  #expect(Set(anchors.values).count == anchors.count)
  #expect(
    try MarkdownRenderer.render(snapshot).map(\.markdown).joined().contains(
      String(other.id.prefix(12))))
  snapshot.configurations.removeLast()
  let item = try #require(snapshot.configurations[0].symbols.first { $0.name == "Item" })
  let duplicate = SymbolRecord(
    module: item.module, language: item.language, preciseIdentifier: "another-item",
    fields: item.fields)
  snapshot.configurations[0].symbols.append(duplicate)
  let key = snapshot.configurations[0].id + ":" + item.id
  let colliding = try #require(InterfaceRenderer.anchors(in: snapshot)[key])
  var fields = item.fields
  fields["pathComponents"]?.value = .array([
    .string(String(colliding.dropFirst("evidenceexample-".count)))
  ])
  snapshot.configurations[0].symbols.append(
    SymbolRecord(
      module: item.module, language: item.language, preciseIdentifier: "suffix-collision",
      fields: fields))
  let distinct = InterfaceRenderer.anchors(in: snapshot)
  #expect(Set(distinct.values).count == distinct.count)
}

@Test func genericConstraintDoesNotHideATypeConformance() throws {
  var snapshot = try fixtureSnapshot()
  let shelf = try #require(snapshot.configurations[0].symbols.first { $0.name == "Shelf" })
  let named = try #require(snapshot.configurations[0].symbols.first { $0.name == "Named" })
  snapshot.configurations[0].relationships.append(
    Relationship(
      module: shelf.module, language: shelf.language, kind: "conformsTo",
      source: shelf.preciseIdentifier, target: named.preciseIdentifier, fields: [:]))
  let text = try MarkdownRenderer.render(snapshot).map(\.markdown).joined()
  #expect(text.contains("public struct Shelf<T>: Named where T : Named"))
}
