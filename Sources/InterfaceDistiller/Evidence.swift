// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

public enum DistillerVersion { public static let current = "0.1.2" }

/// Observation state. An absent field is distinct from an uncollected field.
public enum ObservationState: String, Codable, Sendable {
  case present, absent, notCollected, unsupported, failed, filtered, unresolved
}

public enum ProvenanceKind: String, Codable, Sendable {
  case compilerReported, parsed, derived, policy
}

/// Provenance applies to a whole JSON field and its descendants unless overridden.
public struct EvidenceField: Codable, Sendable, Equatable {
  public var value: JSONValue
  public var state: ObservationState
  public var provenance: ProvenanceKind
  public var sources: [String]
  public var reason: String?

  public init(
    _ value: JSONValue = .null, state: ObservationState = .present,
    provenance: ProvenanceKind = .compilerReported, sources: [String] = [], reason: String? = nil
  ) {
    self.value = value
    self.state = state
    self.provenance = provenance
    self.sources = sources.sorted()
    self.reason = reason
  }
}

/// All build choices are explicit; environment variables must be declared to be reproducible.
public struct BuildConfiguration: Codable, Sendable, Equatable {
  public var toolchain: String
  public var sdk: String
  public var triple: String
  public var deploymentTarget: String
  public var languageMode: String
  public var buildMode: String
  public var conditions: [String]
  public var traits: [String]
  public var environment: [String: String]
  public var extractorVersion: String

  public init(
    toolchain: String, sdk: String, triple: String, deploymentTarget: String,
    languageMode: String = "6", buildMode: String = "debug", conditions: [String] = [],
    traits: [String] = [], environment: [String: String] = [:]
  ) {
    self.toolchain = toolchain
    self.sdk = sdk
    self.triple = triple
    self.deploymentTarget = deploymentTarget
    self.languageMode = languageMode
    self.buildMode = buildMode
    self.conditions = conditions.sorted()
    self.traits = traits.sorted()
    self.environment = environment
    self.extractorVersion = DistillerVersion.current
  }

  public func identity() throws -> String { try CanonicalJSON.key(self) }
}

/// Exclusion wins over inclusion. Empty module and include lists select all available modules and symbols.
public struct CollectionScope: Codable, Sendable, Equatable {
  public var modules: [String]
  public var include: [String]
  public var exclude: [String]
  public var includeSPI: Bool
  public var sourceLocations: Bool
  public init(
    modules: [String] = [], include: [String] = [], exclude: [String] = [],
    includeSPI: Bool = false, sourceLocations: Bool = false
  ) {
    self.modules = modules.sorted()
    self.include = include.sorted()
    self.exclude = exclude.sorted()
    self.includeSPI = includeSPI
    self.sourceLocations = sourceLocations
  }

  func accepts(module: String, id: String, name: String) -> Bool {
    let candidates = [id, name, module + "." + name]
    return (modules.isEmpty || modules.contains(module))
      && (include.isEmpty || include.contains { p in candidates.contains { Self.matches(p, $0) } })
      && !exclude.contains { p in candidates.contains { Self.matches(p, $0) } }
  }

  static func matches(_ pattern: String, _ value: String) -> Bool {
    let regex =
      "^"
      + NSRegularExpression.escapedPattern(for: pattern)
      .replacingOccurrences(of: "\\*", with: ".*").replacingOccurrences(of: "\\?", with: ".") + "$"
    return value.range(of: regex, options: .regularExpression) != nil
  }
}

public struct SymbolRecord: Codable, Sendable, Equatable {
  /// Module, language and compiler identifier form the semantic identity within a configuration.
  public var id: String
  public var module: String
  public var language: String
  public var preciseIdentifier: String
  public var fields: [String: EvidenceField]
  public var references: [String]
  public var name: String { fields["names"]?.value["title"].string ?? preciseIdentifier }

  public init(
    module: String, language: String, preciseIdentifier: String,
    fields: [String: EvidenceField], references: [String] = []
  ) {
    self.module = module
    self.language = language
    self.preciseIdentifier = preciseIdentifier
    self.id = Self.identity(module: module, language: language, precise: preciseIdentifier)
    self.fields = fields
    self.references = references.sorted()
  }

  public static func identity(module: String, language: String, precise: String) -> String {
    [module, language, precise].map { "\($0.utf8.count):\($0)" }.joined()
  }
}

public struct Relationship: Codable, Sendable, Equatable {
  public var module: String
  public var language: String
  public var kind: String
  public var source: String
  public var target: String
  public var fields: [String: EvidenceField]
}

public struct GraphSource: Codable, Sendable, Equatable {
  public var id: String
  public var module: String
  public var formatVersion: JSONValue
  public var generator: String
  public var languageView: String
}

public struct CollectionGap: Codable, Sendable, Equatable {
  public var subject: String
  public var state: ObservationState
  public var reason: String
  public init(_ subject: String, _ state: ObservationState, _ reason: String) {
    self.subject = subject
    self.state = state
    self.reason = reason
  }
}

/// Conflicts retain every observed variant. No last-writer winner is selected.
public struct MergeRecord: Codable, Sendable, Equatable {
  public var subject: String
  public var kind: String
  public var variants: [JSONValue]
  public var sources: [String]
}

public struct ConfigurationEvidence: Codable, Sendable, Equatable {
  public var id: String
  public var configuration: BuildConfiguration
  public var scope: CollectionScope
  public var inputDigest: String
  public var packages: [PackageStructure]
  public var expectedModules: [String]
  public var collectedModules: [String]
  public var graphs: [GraphSource]
  public var symbols: [SymbolRecord]
  public var relationships: [Relationship]
  public var gaps: [CollectionGap]
  public var merges: [MergeRecord]
}

/// Schema 1.x permits unknown object keys, but unknown major versions are rejected.
public struct EvidenceSnapshot: Codable, Sendable, Equatable {
  public var schemaVersion: String
  public var configurations: [ConfigurationEvidence]

  public init(configurations: [ConfigurationEvidence]) throws {
    self.schemaVersion = "1.0"
    self.configurations = configurations.sorted { $0.id < $1.id }
    try validate()
  }

  public func identity() throws -> String { try CanonicalJSON.key(self) }

  public static func read(_ url: URL) throws -> EvidenceSnapshot {
    let snapshot = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    try snapshot.validate()
    return snapshot
  }

  public func validate() throws {
    guard schemaVersion.range(of: #"^1\.[0-9]+$"#, options: .regularExpression) != nil else {
      throw DistillerError(
        .incompatibleSchema, "Unsupported evidence schema", context: ["schema": schemaVersion])
    }
    guard Set(configurations.map(\.id)).count == configurations.count else {
      throw DistillerError(.invalidEvidence, "Duplicate configuration identities")
    }
    for c in configurations {
      guard c.id == (try c.configuration.identity()),
        Set(c.symbols.map(\.id)).count == c.symbols.count
      else {
        throw DistillerError(.invalidEvidence, "Invalid configuration or duplicate symbol identity")
      }
      let graphIDs = Set(c.graphs.map(\.id))
      guard graphIDs.count == c.graphs.count else {
        throw DistillerError(.invalidEvidence, "Duplicate graph identities")
      }
      let fields =
        c.symbols.flatMap { Array($0.fields.values) }
        + c.relationships.flatMap { Array($0.fields.values) }
      for field in fields {
        guard Set(field.sources).isSubset(of: graphIDs),
          ![ProvenanceKind.compilerReported, .parsed].contains(field.provenance)
            || !field.sources.isEmpty
        else {
          throw DistillerError(
            .invalidEvidence, "Field provenance does not resolve to a source graph")
        }
      }
      for merge in c.merges {
        guard ["duplicateGraph", "duplicateSymbol", "conflict"].contains(merge.kind),
          !merge.sources.isEmpty, Set(merge.sources).isSubset(of: graphIDs)
        else {
          throw DistillerError(.invalidEvidence, "Invalid merge provenance")
        }
      }
      for s in c.symbols
      where s.id
        != SymbolRecord.identity(
          module: s.module, language: s.language, precise: s.preciseIdentifier)
      {
        throw DistillerError(.invalidEvidence, "Invalid symbol identity", context: ["symbol": s.id])
      }
    }
  }

  public static func merge(_ snapshots: [EvidenceSnapshot]) throws -> EvidenceSnapshot {
    var found: [String: ConfigurationEvidence] = [:]
    for snapshot in snapshots {
      try snapshot.validate()
      for c in snapshot.configurations {
        if let old = found[c.id], old != c {
          throw DistillerError(
            .conflictingInput,
            "Configuration identity has different observations; keep snapshots separate",
            context: ["configuration": c.id])
        }
        found[c.id] = c
      }
    }
    return try Self(configurations: Array(found.values))
  }
}

public struct DistillerError: Error, Codable, Sendable, CustomStringConvertible {
  public enum Code: String, Codable, Sendable {
    case usage, missingInput, invalidInput, invalidEvidence, incompatibleSchema, conflictingInput
    case processFailed, timeout, cancelled, unsupported, incomplete, io
  }
  public var code: Code
  public var message: String
  public var context: [String: String]
  public init(_ code: Code, _ message: String, context: [String: String] = [:]) {
    self.code = code
    self.message = message
    self.context = context
  }
  public var description: String { "\(code.rawValue): \(message)" }
}
