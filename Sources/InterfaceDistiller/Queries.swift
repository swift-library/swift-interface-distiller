// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

public struct QueryResult: Codable, Sendable {
  public var snapshot: String
  public var configuration: String
  public var symbols: [SymbolRecord]
}

public struct SliceResult: Codable, Sendable {
  public var snapshot: String
  public var configuration: String
  public var state: String
  public var symbols: [SymbolRecord]
  public var relationships: [Relationship]
  public var omittedReferences: [String]
  public var externalReferences: [String]
  public var diagnostics: [String]
  public var symbolBytes: Int
}

/// Queries cannot mix observations from separate snapshots or configurations.
public struct SnapshotQuery: Sendable {
  public let snapshotID: String
  public let evidence: ConfigurationEvidence
  private let schemaVersion: String
  private let parentReferences: [String: [String]]
  private let childrenByParent: [String: [String]]

  public init(_ snapshot: EvidenceSnapshot, configuration: String? = nil) throws {
    try snapshot.validate()
    guard
      let selected = configuration.flatMap({ id in snapshot.configurations.first { $0.id == id } })
        ?? (configuration == nil && snapshot.configurations.count == 1
          ? snapshot.configurations.first : nil)
    else {
      throw DistillerError(.usage, "Select exactly one existing configuration")
    }
    self.schemaVersion = snapshot.schemaVersion
    self.snapshotID = try snapshot.identity()
    self.evidence = selected
    let parents = DeclarationNesting.parents(in: selected)
    self.parentReferences = parents
    self.childrenByParent = Dictionary(
      grouping: parents.flatMap { child, targets in
        targets.map { (parent: $0, child: child) }
      }, by: \.parent
    ).mapValues { $0.map(\.child).sorted() }
  }

  public func lookup(_ identifierOrName: String) -> QueryResult {
    result(
      evidence.symbols.filter {
        $0.id == identifierOrName || $0.preciseIdentifier == identifierOrName
          || $0.name == identifierOrName
          || $0.fields["pathComponents"]?.value.strings.joined(separator: ".") == identifierOrName
      })
  }

  public func members(of identifier: String) -> QueryResult {
    related(to: identifier, kinds: ["memberOf", "requirementOf", "optionalRequirementOf"])
  }

  public func observedConformers(to identifier: String) -> QueryResult {
    related(to: identifier, kinds: ["conformsTo"])
  }

  public func initializers(of identifier: String) -> QueryResult {
    result(
      members(of: identifier).symbols.filter {
        $0.fields["kind"]?.value["identifier"].string == "swift.init"
      })
  }

  /// Candidates contain the requested compiler type identifier in reported return fragments.
  public func returning(_ identifier: String) -> QueryResult {
    let precise = Set(lookup(identifier).symbols.map(\.preciseIdentifier) + [identifier])
    return result(
      evidence.symbols.filter { symbol in
        let returns = symbol.fields["functionSignature"]?.value["returns"] ?? .null
        return !precise.isDisjoint(with: SymbolGraphNormalizer.references(in: returns))
      })
  }

  /// Closure follows declaration references, outgoing relationships and contained declarations.
  /// Budgets constrain the selected format's payload; diagnostics remain explicit outside the budget.
  public func slice(
    roots: [String], maximumSymbols: Int? = nil, maximumBytes: Int? = nil,
    format: QueryFormat = .json, docs: DocumentationStyle = .summary
  ) throws
    -> SliceResult
  {
    guard maximumSymbols.map({ $0 > 0 }) ?? true, maximumBytes.map({ $0 > 0 }) ?? true else {
      throw DistillerError(.usage, "Slice budgets must be positive")
    }
    for root in roots where lookup(root).symbols.isEmpty {
      throw DistillerError(
        .invalidInput, "Slice root is outside the snapshot", context: ["root": root])
    }
    var pending = roots.sorted()
    var seen: Set<String> = []
    var selected: [String: SymbolRecord] = [:]
    var omitted: Set<String> = []
    var external: Set<String> = []
    var diagnostics: Set<String> = []
    var bytes = 0
    while !pending.isEmpty {
      let current = pending.removeFirst()
      guard seen.insert(current).inserted else { continue }
      let matches = lookup(current).symbols
      if matches.isEmpty {
        external.insert(current)
        continue
      }
      for symbol in matches {
        if selected[symbol.id] != nil { continue }
        let size: Int
        if format == .json {
          size = try bytes + CanonicalJSON.encode(symbol).count
        } else if maximumBytes != nil {
          size = try payloadBytes(Array(selected.values) + [symbol], format: format, docs: docs)
        } else {
          size = 0
        }
        if maximumSymbols.map({ selected.count >= $0 }) == true
          || maximumBytes.map({ size > $0 }) == true
        {
          omitted.insert(symbol.id)
          diagnostics.insert("Symbol payload budget exhausted")
          continue
        }
        selected[symbol.id] = symbol
        bytes = size
        pending += symbol.references
        for edge in evidence.relationships where edge.source == symbol.preciseIdentifier {
          pending.append(edge.target)
        }
        pending += childrenByParent[symbol.preciseIdentifier] ?? []
      }
      pending = Array(Set(pending)).sorted()
    }
    if format != .json && maximumBytes == nil {
      bytes = try payloadBytes(Array(selected.values), format: format, docs: docs)
    }
    let identities = Set(selected.values.map(\.preciseIdentifier))
    return SliceResult(
      snapshot: snapshotID, configuration: evidence.id,
      state: omitted.isEmpty ? "complete" : "truncated",
      symbols: selected.values.sorted { $0.id < $1.id },
      relationships: evidence.relationships.filter {
        identities.contains($0.source) && identities.contains($0.target)
      },
      omittedReferences: omitted.sorted(), externalReferences: external.sorted(),
      diagnostics: diagnostics.sorted(), symbolBytes: bytes)
  }

  /// Applies payload budgets to a query without following its reference closure.
  public func bounded(
    _ result: QueryResult, maximumSymbols: Int? = nil, maximumBytes: Int? = nil,
    format: QueryFormat = .json, docs: DocumentationStyle = .summary
  ) throws -> SliceResult {
    guard result.snapshot == snapshotID, result.configuration == evidence.id,
      maximumSymbols.map({ $0 > 0 }) ?? true, maximumBytes.map({ $0 > 0 }) ?? true
    else { throw DistillerError(.usage, "Invalid query result or budget") }
    var symbols: [SymbolRecord] = []
    var omitted: [String] = []
    for symbol in result.symbols.sorted(by: { $0.id < $1.id }) {
      let exceedsBytes =
        try maximumBytes.map {
          try payloadBytes(symbols + [symbol], format: format, docs: docs) > $0
        } == true
      if maximumSymbols.map({ symbols.count >= $0 }) == true || exceedsBytes {
        omitted.append(symbol.id)
      } else {
        symbols.append(symbol)
      }
    }
    return SliceResult(
      snapshot: snapshotID, configuration: evidence.id,
      state: omitted.isEmpty ? "complete" : "truncated",
      symbols: symbols, relationships: [], omittedReferences: omitted, externalReferences: [],
      diagnostics: omitted.isEmpty ? [] : ["Symbol payload budget exhausted"],
      symbolBytes: try payloadBytes(symbols, format: format, docs: docs))
  }

  /// Encodes a result in its snapshot context. Readable formats include explicit omission diagnostics.
  public func encode(
    _ result: SliceResult, format: QueryFormat = .json, docs: DocumentationStyle = .summary
  ) throws -> Data {
    guard result.snapshot == snapshotID, result.configuration == evidence.id else {
      throw DistillerError(.usage, "Query result belongs to another snapshot")
    }
    if format == .json { return try CanonicalJSON.encode(result) }
    let snapshot = try EvidenceSnapshot(configurations: [evidence], schemaVersion: schemaVersion)
    var header = InterfaceRenderer.header(snapshot)
    header += "Snapshot: \(snapshotID.prefix(12)) · Selection: \(result.state)\n"
    if !result.omittedReferences.isEmpty {
      header +=
        "Omitted in-snapshot symbols: \(result.omittedReferences.count)\n"
    }
    header += "External references: \(result.externalReferences.count)\n"
    for diagnostic in result.diagnostics { header += InterfaceRenderer.oneLine(diagnostic) + "\n" }
    if format == .swift {
      header = header.components(separatedBy: "\n").map { "// " + $0 }.joined(separator: "\n")
    }
    let body = try InterfaceRenderer.body(
      result.symbols, evidence: evidence, format: format, docs: docs)
    return Data((header + "\n" + body).utf8)
  }

  func payloadBytes(_ symbols: [SymbolRecord], format: QueryFormat, docs: DocumentationStyle) throws
    -> Int
  {
    if format == .json { return try symbols.reduce(0) { try $0 + CanonicalJSON.encode($1).count } }
    return try InterfaceRenderer.body(symbols, evidence: evidence, format: format, docs: docs).utf8
      .count
  }

  private func related(to identifier: String, kinds: Set<String>) -> QueryResult {
    let ids = Set(lookup(identifier).symbols.map(\.preciseIdentifier) + [identifier])
    if kinds == DeclarationNesting.kinds {
      return result(
        evidence.symbols.filter {
          !ids.isDisjoint(with: parentReferences[$0.id] ?? [])
        })
    }
    let sources = Set(
      evidence.relationships.filter { kinds.contains($0.kind) && ids.contains($0.target) }.map(
        \.source))
    return result(evidence.symbols.filter { sources.contains($0.preciseIdentifier) })
  }

  private func result(_ symbols: [SymbolRecord]) -> QueryResult {
    QueryResult(
      snapshot: snapshotID, configuration: evidence.id, symbols: symbols.sorted { $0.id < $1.id })
  }
}

public struct DocumentationCoverage: Codable, Sendable {
  public var configuration: String
  public var eligible: Int
  public var documented: Int
  public var undocumented: [String]
  public var fraction: Double?

  /// Denominator: all collected non-extension symbols; a nonblank raw comment counts once.
  public static func measure(_ evidence: ConfigurationEvidence) -> Self {
    let eligible = evidence.symbols.filter {
      $0.fields["kind"]?.value["identifier"].string != "swift.extension"
    }
    let missing = eligible.filter {
      ($0.fields["docComment"]?.value["lines"].array ?? []).allSatisfy {
        ($0["text"].string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
    }.map(\.id).sorted()
    return Self(
      configuration: evidence.id, eligible: eligible.count,
      documented: eligible.count - missing.count,
      undocumented: missing,
      fraction: eligible.isEmpty
        ? nil : Double(eligible.count - missing.count) / Double(eligible.count))
  }
}
