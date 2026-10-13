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
  public var diagnostics: [String]
  public var symbolBytes: Int
}

/// Queries cannot mix observations from separate snapshots or configurations.
public struct SnapshotQuery: Sendable {
  public let snapshotID: String
  public let evidence: ConfigurationEvidence

  public init(_ snapshot: EvidenceSnapshot, configuration: String? = nil) throws {
    try snapshot.validate()
    guard
      let selected = configuration.flatMap({ id in snapshot.configurations.first { $0.id == id } })
        ?? (configuration == nil && snapshot.configurations.count == 1
          ? snapshot.configurations.first : nil)
    else {
      throw DistillerError(.usage, "Select exactly one existing configuration")
    }
    self.snapshotID = try snapshot.identity()
    self.evidence = selected
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
  /// Budgets constrain encoded symbol payload; omitted identities and diagnostics remain explicit.
  public func slice(roots: [String], maximumSymbols: Int? = nil, maximumBytes: Int? = nil) throws
    -> SliceResult
  {
    guard maximumSymbols.map({ $0 > 0 }) ?? true, maximumBytes.map({ $0 > 0 }) ?? true else {
      throw DistillerError(.usage, "Slice budgets must be positive")
    }
    var pending = roots.sorted()
    var seen: Set<String> = []
    var selected: [String: SymbolRecord] = [:]
    var omitted: Set<String> = []
    var diagnostics: Set<String> = []
    var bytes = 0
    while !pending.isEmpty {
      let current = pending.removeFirst()
      guard seen.insert(current).inserted else { continue }
      let matches = lookup(current).symbols
      if matches.isEmpty {
        omitted.insert(current)
        diagnostics.insert("References outside this snapshot or scope are unresolved")
        continue
      }
      for symbol in matches {
        if selected[symbol.id] != nil { continue }
        let size = try CanonicalJSON.encode(symbol).count
        if maximumSymbols.map({ selected.count >= $0 }) == true
          || maximumBytes.map({ bytes + size > $0 }) == true
        {
          omitted.insert(symbol.id)
          diagnostics.insert("Symbol payload budget exhausted")
          continue
        }
        selected[symbol.id] = symbol
        bytes += size
        pending += symbol.references
        for edge in evidence.relationships where edge.source == symbol.preciseIdentifier {
          pending.append(edge.target)
        }
        for edge in evidence.relationships
        where edge.target == symbol.preciseIdentifier
          && ["memberOf", "requirementOf", "optionalRequirementOf"].contains(edge.kind)
        {
          pending.append(edge.source)
        }
      }
      pending = Array(Set(pending)).sorted()
    }
    let identities = Set(selected.values.map(\.preciseIdentifier))
    return SliceResult(
      snapshot: snapshotID, configuration: evidence.id,
      state: omitted.isEmpty ? "complete" : "truncated",
      symbols: selected.values.sorted { $0.id < $1.id },
      relationships: evidence.relationships.filter {
        identities.contains($0.source) && identities.contains($0.target)
      },
      omittedReferences: omitted.sorted(), diagnostics: diagnostics.sorted(), symbolBytes: bytes)
  }

  private func related(to identifier: String, kinds: Set<String>) -> QueryResult {
    let ids = Set(lookup(identifier).symbols.map(\.preciseIdentifier) + [identifier])
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
