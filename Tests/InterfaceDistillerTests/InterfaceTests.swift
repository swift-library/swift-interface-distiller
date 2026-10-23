// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import InterfaceDistiller

@Test func readableAndSymbolsViewsMatchSnapshots() throws {
  for (view, name) in [(MarkdownRenderer.View.interface, "Interface"), (.symbols, "Symbols")] {
    let snapshot =
      try view == .symbols
      ? InterfaceSnapshot.read(
        #require(
          Bundle.module.url(
            forResource: "Snapshot-v1", withExtension: "json", subdirectory: "Fixtures")))
      : fixtureSnapshot()
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
  #expect(InterfaceRenderer.anchors(in: snapshot)[key] == "snapshotexample-item")
  var overload = SymbolRecord(
    module: item.module, language: item.language, preciseIdentifier: "overloaded-item",
    fields: item.fields)
  snapshot.configurations[0].symbols.append(overload)
  let first = InterfaceRenderer.anchors(in: snapshot)
  #expect(first[key]?.hasPrefix("snapshotexample-item-") == true)
  #expect(Set(first.values).count == 8)
  snapshot.configurations[0].symbols.reverse()
  #expect(InterfaceRenderer.anchors(in: snapshot) == first)
  overload.fields["docComment"] = ObservedField(.null, provenance: .derived)
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
  #expect(throws: DistillerError.self) { try MarkdownRenderer.render(snapshot, byteBudget: 500) }
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
  #expect(summary.contains("public struct Item: Named, Sendable"))
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
      #expect(text.contains("External references:"))
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
        "targetFallback": ObservedField(.string("Other.Protocol"), provenance: .derived),
        "swiftConstraints": ObservedField(constraint, provenance: .derived),
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
  #expect(text.contains("<a id=\"snapshotexample-item\"></a>"))
  #expect(text.components(separatedBy: "<a id=").count == 2)
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
  #expect(Set(anchors.values).count == 14)
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
    .string(String(colliding.dropFirst("snapshotexample-".count)))
  ])
  snapshot.configurations[0].symbols.append(
    SymbolRecord(
      module: item.module, language: item.language, preciseIdentifier: "suffix-collision",
      fields: fields))
  let distinct = InterfaceRenderer.anchors(in: snapshot)
  #expect(Set(distinct.values).count == 9)
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

@Test func memberLinksShareBlockAnchorsWithoutChangingTypeCollisions() throws {
  var snapshot = try fixtureSnapshot()
  let item = try #require(snapshot.configurations[0].symbols.first { $0.name == "Item" })
  var fields = item.fields
  fields["pathComponents"]?.value = .array([.string("Item"), .string("==(_:_:)")])
  let member = SymbolRecord(
    module: item.module, language: item.language, preciseIdentifier: "operator", fields: fields)
  snapshot.configurations[0].symbols.append(member)
  snapshot.configurations[0].relationships.append(
    Relationship(
      module: item.module, language: item.language, kind: "memberOf",
      source: member.preciseIdentifier, target: item.preciseIdentifier, fields: [:]))
  let anchors = InterfaceRenderer.anchors(in: snapshot)
  #expect(anchors[snapshot.configurations[0].id + ":" + item.id] == "snapshotexample-item")
  #expect(anchors[snapshot.configurations[0].id + ":" + member.id] == "snapshotexample-item")
  let text = try MarkdownRenderer.render(snapshot).map(\.markdown).joined()
  #expect(text.components(separatedBy: "<a id=").count == Set(anchors.values).count + 1)
  for symbol in try SnapshotQuery(snapshot).members(of: "Item").symbols {
    #expect(anchors[snapshot.configurations[0].id + ":" + symbol.id] == "snapshotexample-item")
  }
  let original = try CanonicalJSON.encode(snapshot)
  _ = try MarkdownRenderer.render(snapshot, view: .symbols)
  #expect(try CanonicalJSON.encode(snapshot) == original)
}

@Test func nestedAndExtensionMembersNavigateToTheirContainingBlocks() throws {
  var snapshot = try fixtureSnapshot()
  let c = snapshot.configurations[0]
  let item = try #require(c.symbols.first { $0.name == "Item" })
  let shelf = try #require(c.symbols.first { $0.name == "Shelf" })
  let external = try #require(c.symbols.first { $0.name == "Array" })
  snapshot.configurations[0].relationships.append(
    Relationship(
      module: shelf.module, language: shelf.language, kind: "memberOf",
      source: shelf.preciseIdentifier, target: item.preciseIdentifier, fields: [:]))
  let anchors = InterfaceRenderer.anchors(in: snapshot)
  let query = try SnapshotQuery(snapshot)
  for symbol in query.members(of: "Shelf").symbols + [shelf] {
    #expect(anchors[c.id + ":" + symbol.id] == anchors[c.id + ":" + item.id])
  }
  for symbol in query.members(of: external.id).symbols {
    #expect(anchors[c.id + ":" + symbol.id] == anchors[c.id + ":" + external.id])
  }
  #expect(anchors[c.id + ":" + external.id] == "snapshotexample-array")
  let subset = try query.bounded(query.members(of: "Shelf"), format: .markdown)
  let text = String(decoding: try query.encode(subset, format: .markdown), as: UTF8.self)
  #expect(text.contains("<a id=\"snapshotexample-item\"></a>"))
  #expect(text.components(separatedBy: "<a id=").count == 2)
}

@Test func markerConformancesAndExternalReferencesStayInSymbols() throws {
  let snapshot = try fixtureSnapshot()
  let configuration = snapshot.configurations[0]
  #expect(configuration.relationships.contains { $0.target == "s:s16SendableMetatypeP" })
  #expect(configuration.externalReferences?.contains("s:SS") == true)
  #expect(!configuration.gaps.contains { $0.state == .unresolved })
  let interface = try MarkdownRenderer.render(snapshot).map(\.markdown).joined()
  #expect(!interface.contains("SendableMetatype"))
  #expect(!interface.contains("s:SS"))
  let detailed = try MarkdownRenderer.render(snapshot, view: .symbols).map(\.markdown).joined()
  #expect(detailed.contains("s:SS"))
  #expect(detailed.contains("s:s16SendableMetatypeP"))
  let query = try SnapshotQuery(snapshot)
  let result = try query.slice(roots: ["Item"])
  #expect(result.state == "complete")
  #expect(!result.externalReferences.isEmpty)
  for format in [QueryFormat.swift, .markdown] {
    let text = String(decoding: try query.encode(result, format: format), as: UTF8.self)
    #expect(text.contains("Selection: complete"))
    #expect(text.contains("External references: \(result.externalReferences.count)"))
    #expect(!text.contains("s:SS"))
  }
  var invalid = snapshot
  invalid.configurations[0].scope.includeSynthesized = nil
  #expect(throws: DistillerError.self) { try invalid.validate() }
  invalid = snapshot
  invalid.configurations[0].externalReferences = nil
  #expect(throws: DistillerError.self) { try invalid.validate() }
}

@Test func normalizationPolicyDoesNotRecordSynthesizedCopiesAsGaps() throws {
  let selected = try fixtureSnapshot()
  let all = try fixtureSnapshot(scope: .init(includeSPI: true, includeSynthesized: true))
  #expect(all.configurations[0].symbols.count == selected.configurations[0].symbols.count + 1)
  #expect(selected.configurations[0].symbols.contains { $0.name == "label" })
  #expect(!selected.configurations[0].gaps.contains { $0.subject.contains("::SYNTHESIZED::") })
  #expect(
    !selected.configurations[0].relationships.contains { $0.source.contains("::SYNTHESIZED::") })
  #expect(
    try MarkdownRenderer.render(selected).first?.markdown.contains("synthesized excluded by policy")
      == true)
}

@Test func legacySnapshotsCanBeReadAndQueriedWithoutMixingSchemaMajors() throws {
  let legacy = try InterfaceSnapshot.read(
    #require(
      Bundle.module.url(forResource: "Snapshot-v1", withExtension: "json", subdirectory: "Fixtures")
    ))
  #expect(legacy.schemaVersion == "1.0")
  #expect(legacy.configurations[0].scope.includeSynthesized == nil)
  let query = try SnapshotQuery(legacy)
  let result = try query.slice(roots: ["Item"], format: .swift)
  #expect(result.state == "complete")
  let text = String(decoding: try query.encode(result, format: .swift), as: UTF8.self)
  #expect(text.contains("external references"))
  #expect(!text.contains("unresolved"))
  #expect(throws: DistillerError.self) { try InterfaceSnapshot.merge([legacy, fixtureSnapshot()]) }
  #expect(try InterfaceSnapshot.merge([legacy]).schemaVersion == "1.0")
}

@Test func macroPackageInterfaceMatchesSnapshot() throws {
  let graphs = try SymbolGraphInput.load(
    #require(
      Bundle.module.url(forResource: "MacroGraphs", withExtension: nil, subdirectory: "Fixtures")))
  let snapshot = try SymbolGraphNormalizer.normalize(graphs, configuration: fixtureConfiguration)
  let expected = try String(
    contentsOf: #require(
      Bundle.module.url(
        forResource: "MacroInterface", withExtension: "md", subdirectory: "Fixtures")),
    encoding: .utf8)
  #expect(try MarkdownRenderer.render(snapshot).map(\.markdown).joined() == expected)
  #expect(
    snapshot.configurations[0].symbols.contains {
      $0.fields["kind"]?.value["identifier"].string == "swift.macro"
    })
  #expect(
    !snapshot.configurations[0].symbols.contains {
      $0.preciseIdentifier.contains("::SYNTHESIZED::")
    })
  let query = try SnapshotQuery(snapshot)
  #expect(query.members(of: "Counter").symbols.filter { $0.name == "count" }.count == 2)
  let defaults = try query.slice(roots: ["Counter"], format: .swift)
  #expect(defaults.state == "complete")
  #expect(defaults.symbols.filter { $0.name == "count" }.count == 2)
  let view = String(decoding: try query.encode(defaults, format: .swift), as: UTF8.self)
  #expect(view.contains("extension Counter"))

  #expect(query.members(of: "ChildCounter").symbols.contains { $0.name == "value()" })
  let inherited = try query.slice(roots: ["ChildCounter"], format: .swift)
  let childView = String(decoding: try query.encode(inherited, format: .swift), as: UTF8.self)
  #expect(childView.contains("extension ChildCounter"))
  #expect(!childView.contains("extension ParentCounter"))

}
