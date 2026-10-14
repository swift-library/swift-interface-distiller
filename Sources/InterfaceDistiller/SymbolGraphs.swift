// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

/// An owned decoder preserves compiler fields without a dependency on compiler libraries.
public struct SymbolGraphInput: Sendable {
  public var value: JSONValue
  public var sourceRoot: URL?
  public var languageView: String
  public init(value: JSONValue, sourceRoot: URL? = nil, languageView: String = "swift") {
    self.value = value
    self.sourceRoot = sourceRoot
    self.languageView = languageView
  }

  public static func load(_ input: URL, sourceRoot: URL? = nil, languageView: String = "swift")
    throws -> [Self]
  {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: input.path, isDirectory: &isDirectory) else {
      throw DistillerError(.missingInput, "Symbol graph input does not exist")
    }
    var files: [URL] = []
    if isDirectory.boolValue {
      guard
        let enumerator = FileManager.default.enumerator(
          at: input, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
      else {
        throw DistillerError(.io, "Cannot enumerate symbol graph input")
      }
      for case let url as URL in enumerator where url.lastPathComponent.hasSuffix(".symbols.json") {
        if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
          files.append(url)
        }
      }
    } else {
      files = [input]
    }
    guard !files.isEmpty else { throw DistillerError(.missingInput, "No symbol graphs found") }
    return try files.sorted { $0.path < $1.path }.map {
      do {
        return Self(
          value: try JSONValue.read($0), sourceRoot: sourceRoot, languageView: languageView)
      } catch {
        throw DistillerError(
          .invalidInput, "Malformed symbol graph", context: ["file": $0.lastPathComponent])
      }
    }
  }
}

public enum SymbolGraphNormalizer {
  public static func normalize(
    _ inputs: [SymbolGraphInput], configuration: BuildConfiguration,
    scope: CollectionScope = .init(), expectedModules: [String] = [],
    packages: [PackageStructure] = [], inputDigest: String? = nil,
    gaps initialGaps: [CollectionGap] = []
  ) throws -> EvidenceSnapshot {
    var graphs: [String: GraphSource] = [:]
    var candidates: [String: [SymbolRecord]] = [:]
    var relationships: [Relationship] = []
    var gaps = initialGaps
    var merges: [MergeRecord] = []
    var collected: Set<String> = []
    for input in inputs {
      try Task.checkCancellation()
      var raw = input.value
      if scope.includeSynthesized == false {
        var fields = raw.object
        fields["symbols"] = .array(
          raw["symbols"].array.filter {
            !($0["identifier"]["precise"].string ?? "").contains("::SYNTHESIZED::")
          })
        fields["relationships"] = .array(
          raw["relationships"].array.filter {
            !($0["source"].string ?? "").contains("::SYNTHESIZED::")
              && !($0["target"].string ?? "").contains("::SYNTHESIZED::")
          })
        // Validate the original shape before projecting the collection policy.
        if case .array = raw["symbols"], case .array = raw["relationships"] {
          raw = .object(fields)
        }
      }
      guard let module = raw["module"]["name"].string,
        raw["metadata"]["formatVersion"]["major"] == .number(0),
        validFormatVersion(raw["metadata"]["formatVersion"]),
        case .array(let symbols) = raw["symbols"], case .array(let edges) = raw["relationships"]
      else {
        throw DistillerError(
          .invalidInput, "Expected symbol graph format 0.x with module, symbols and relationships")
      }
      if !scope.modules.isEmpty && !scope.modules.contains(module) {
        gaps.append(.init(module, .filtered, "Module excluded by collection scope"))
        continue
      }
      collected.insert(module)
      // Sorting graph sets and translating source locations precede content identity.
      let portable = portableValue(raw, root: input.sourceRoot, locations: scope.sourceLocations)
      var normalized = portable.object
      normalized["symbols"] = .array(try sortedJSON(portable["symbols"].array))
      normalized["relationships"] = .array(try sortedJSON(portable["relationships"].array))
      let graphID = try CanonicalJSON.key(JSONValue.object(normalized))
      if graphs[graphID] != nil {
        merges.append(
          MergeRecord(subject: graphID, kind: "duplicateGraph", variants: [], sources: [graphID]))
        continue
      }
      graphs[graphID] = GraphSource(
        id: graphID, module: module, formatVersion: raw["metadata"]["formatVersion"],
        generator: raw["metadata"]["generator"].string ?? "unknown",
        languageView: input.languageView)
      for original in symbols {
        try Task.checkCancellation()
        guard let precise = original["identifier"]["precise"].string,
          let language = original["identifier"]["interfaceLanguage"].string,
          original["kind"]["identifier"].string != nil, original["names"]["title"].string != nil
        else {
          throw DistillerError(
            .invalidInput, "Symbol lacks compiler identity, language, kind or name")
        }
        let id = SymbolRecord.identity(module: module, language: language, precise: precise)
        let access = original["accessLevel"].string
        // Clang graphs can omit access. That omission is not a Swift access classification.
        if language == "swift" && !["public", "open"].contains(access ?? "") {
          gaps.append(.init(id, .filtered, "Outside public/open access scope"))
          continue
        }
        if original["spi"].boolean == true && !scope.includeSPI {
          gaps.append(.init(id, .filtered, "SPI excluded by collection scope"))
          continue
        }
        let name = original["names"]["title"].string ?? precise
        if !scope.accepts(module: module, id: precise, name: name) {
          gaps.append(.init(id, .filtered, "Symbol excluded by include/exclude rules"))
          continue
        }
        let symbol = portableValue(
          original, root: input.sourceRoot, locations: scope.sourceLocations)
        var fields: [String: EvidenceField] = [:]
        for (key, value) in symbol.object where key != "identifier" {
          fields[key] = EvidenceField(value, sources: [graphID])
        }
        for key in [
          "accessLevel", "spi", "availability", "docComment", "swiftGenerics", "swiftExtension",
          "functionSignature",
        ] where fields[key] == nil {
          fields[key] = EvidenceField(
            state: .notCollected, sources: [graphID], reason: "Field not reported by producer")
        }
        fields["identifier"] = EvidenceField(original["identifier"], sources: [graphID])
        if !scope.sourceLocations {
          fields["location"] = EvidenceField(
            state: .notCollected, provenance: .policy, reason: "Source locations disabled")
        } else if symbol["location"]["uri"].string != nil {
          fields["location"]?.provenance = .derived
          fields["location"]?.reason = "Compiler location made relative to the declared source root"
        } else {
          fields["location"] = EvidenceField(
            state: .unresolved, provenance: .derived,
            sources: [graphID], reason: "No location within the declared source root")
        }
        let attributes = original["declarationFragments"].array.filter {
          $0["kind"].string == "attribute"
            || ["async", "isolated", "nonisolated", "sending", "actor"].contains(
              $0["spelling"].string ?? "")
        }
        fields["reportedConcurrency"] = EvidenceField(
          .array(attributes), state: attributes.isEmpty ? .notCollected : .present,
          provenance: .parsed, sources: [graphID],
          reason: "Attribute fragments and concurrency keywords; no negative isolation inference")
        let refs = Set(references(in: symbol)).subtracting([precise]).sorted()
        candidates[id, default: []].append(
          SymbolRecord(
            module: module, language: language, preciseIdentifier: precise,
            fields: fields, references: refs))
      }
      let languages = Dictionary(grouping: symbols) { $0["identifier"]["precise"].string ?? "" }
        .mapValues {
          $0.compactMap { $0["identifier"]["interfaceLanguage"].string }.sorted().first
            ?? input.languageView
        }
      for edge in edges {
        try Task.checkCancellation()
        guard let kind = edge["kind"].string, let source = edge["source"].string,
          let target = edge["target"].string
        else {
          throw DistillerError(.invalidInput, "Relationship lacks kind or endpoint")
        }
        let language = languages[source] ?? input.languageView
        let extras = portableValue(edge, root: input.sourceRoot, locations: scope.sourceLocations)
          .object
          .filter { !["kind", "source", "target"].contains($0.key) }
        relationships.append(
          Relationship(
            module: module, language: language, kind: kind, source: source, target: target,
            fields: extras.mapValues { EvidenceField($0, sources: [graphID]) }))
      }
    }
    var symbols: [SymbolRecord] = []
    for (id, values) in candidates {
      try Task.checkCancellation()
      let groups = try Dictionary(grouping: values) { try CanonicalJSON.key(withoutSources($0)) }
      if groups.count > 1 {
        let variants = try sortedJSON(
          groups.values.compactMap(\.first).map { try CanonicalJSON.value(withoutSources($0)) })
        merges.append(
          MergeRecord(
            subject: id, kind: "conflict", variants: variants,
            sources: Set(values.flatMap { $0.fields.values.flatMap(\.sources) }).sorted()))
        gaps.append(
          .init(
            id, .unresolved, "Conflicting compiler observations; variants retained in merge record")
        )
        continue
      }
      var value = values[0]
      for key in value.fields.keys {
        value.fields[key]?.sources = Set(values.flatMap { $0.fields[key]?.sources ?? [] }).sorted()
      }
      if values.count > 1 {
        merges.append(
          MergeRecord(
            subject: id, kind: "duplicateSymbol", variants: [],
            sources: Set(value.fields.values.flatMap(\.sources)).sorted()))
      }
      symbols.append(value)
    }
    let byPrecise = Dictionary(grouping: symbols, by: \.preciseIdentifier)
    let external = Set(
      relationships.flatMap { [$0.source, $0.target] } + symbols.flatMap(\.references)
    )
    .filter { byPrecise[$0] == nil }.sorted()
    let expected = Set(
      expectedModules.isEmpty
        ? (scope.modules.isEmpty ? Array(collected) : scope.modules) : expectedModules)
    for module in expected.subtracting(collected) {
      gaps.append(.init(module, .notCollected, "Expected module has no supplied graph"))
    }
    let graphList = graphs.values.sorted { $0.id < $1.id }
    let evidence = ConfigurationEvidence(
      id: try configuration.identity(), configuration: configuration, scope: scope,
      inputDigest: try inputDigest ?? CanonicalJSON.key(graphList.map(\.id)),
      packages: packages.sorted { $0.identity.identity < $1.identity.identity },
      expectedModules: expected.sorted(), collectedModules: collected.sorted(), graphs: graphList,
      symbols: symbols.sorted { $0.id < $1.id },
      relationships: try mergedRelationships(relationships),
      gaps: try uniqueSorted(gaps), merges: try uniqueSorted(merges), externalReferences: external)
    return try EvidenceSnapshot(configurations: [evidence])
  }

  static func mergedRelationships(_ relationships: [Relationship]) throws -> [Relationship] {
    var observations: [String: Relationship] = [:]
    for relationship in relationships {
      var identity = relationship
      for field in identity.fields.keys { identity.fields[field]?.sources = [] }
      let key = try CanonicalJSON.key(identity)
      if var existing = observations[key] {
        for field in existing.fields.keys {
          let sources =
            (existing.fields[field]?.sources ?? [])
            + (relationship.fields[field]?.sources ?? [])
          existing.fields[field]?.sources = Set(sources).sorted()
        }
        observations[key] = existing
      } else {
        observations[key] = relationship
      }
    }
    return try uniqueSorted(Array(observations.values))
  }

  static func validFormatVersion(_ value: JSONValue) -> Bool {
    ["major", "minor", "patch"].allSatisfy { key in
      guard case .number(var number) = value[key], number >= 0 else { return false }
      var integer = Decimal()
      NSDecimalRound(&integer, &number, 0, .down)
      return integer == number
    }
  }

  static func withoutSources(_ symbol: SymbolRecord) -> SymbolRecord {
    var copy = symbol
    for key in copy.fields.keys { copy.fields[key]?.sources = [] }
    return copy
  }

  static func references(in value: JSONValue) -> [String] {
    switch value {
    case .array(let items): return items.flatMap { references(in: $0) }
    case .object(let fields):
      return fields.flatMap { key, value -> [String] in
        if ["preciseIdentifier", "rhsPrecise", "lhsPrecise"].contains(key), let id = value.string {
          return [id]
        }
        return references(in: value)
      }
    default: return []
    }
  }

  static func portableValue(_ value: JSONValue, root: URL?, locations: Bool) -> JSONValue {
    switch value {
    case .object(let object):
      var result: [String: JSONValue] = [:]
      for (key, value) in object {
        if key == "location" && !locations { continue }
        if key == "uri", let path = value.string {
          if locations, let root, let url = URL(string: path), url.isFileURL,
            let relative = PortablePath.relative(url, to: root)
          {
            result[key] = .string(relative)
          } else if locations && !path.hasPrefix("/") && !path.contains(":")
            && !path.split(separator: "/").contains("..")
          {
            result[key] = value
          }
          continue
        }
        if key == "range" && !locations { continue }
        result[key] = portableValue(value, root: root, locations: locations)
      }
      return .object(result)
    case .array(let array):
      return .array(array.map { portableValue($0, root: root, locations: locations) })
    default: return value
    }
  }

  static func sortedJSON(_ values: [JSONValue]) throws -> [JSONValue] {
    try values.map { (String(decoding: try CanonicalJSON.encode($0), as: UTF8.self), $0) }.sorted {
      $0.0 < $1.0
    }.map(\.1)
  }

  static func uniqueSorted<T: Codable>(_ values: [T]) throws -> [T] {
    var found: [String: T] = [:]
    for value in values {
      found[String(decoding: try CanonicalJSON.encode(value), as: UTF8.self)] = value
    }
    return found.sorted { $0.key < $1.key }.map(\.value)
  }
}
