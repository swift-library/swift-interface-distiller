// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

public struct FieldChange: Codable, Sendable, Equatable {
  public var configuration: String
  public var symbol: String
  public var category: String
  public var path: String
  public var before: JSONValue
  public var after: JSONValue
}

public struct SnapshotDifference: Codable, Sendable {
  public var baseline: String
  public var candidate: String
  public var added: [String]
  public var removed: [String]
  public var changes: [FieldChange]
  public var incomparableConfigurations: [String]
  public var equal: Bool {
    added.isEmpty && removed.isEmpty && changes.isEmpty && incomparableConfigurations.isEmpty
  }
}

/// Observational comparison deliberately contains no versioning or release decision.
public enum SnapshotComparator {
  public static func compare(_ baseline: EvidenceSnapshot, _ candidate: EvidenceSnapshot) throws
    -> SnapshotDifference
  {
    try baseline.validate()
    try candidate.validate()
    let old = Dictionary(uniqueKeysWithValues: baseline.configurations.map { ($0.id, $0) })
    let new = Dictionary(uniqueKeysWithValues: candidate.configurations.map { ($0.id, $0) })
    let incompatible = Set(old.keys).symmetricDifference(new.keys).sorted()
    var added: [String] = []
    var removed: [String] = []
    var changes: [FieldChange] = []
    for id in Set(old.keys).intersection(new.keys).sorted() {
      guard let lhs = old[id], let rhs = new[id] else { continue }
      guard lhs.scope == rhs.scope else {
        changes.append(
          FieldChange(
            configuration: id, symbol: "", category: "provenance", path: "/scope",
            before: try CanonicalJSON.value(lhs.scope), after: try CanonicalJSON.value(rhs.scope)))
        continue
      }
      let l = Dictionary(uniqueKeysWithValues: lhs.symbols.map { ($0.id, $0) })
      let r = Dictionary(uniqueKeysWithValues: rhs.symbols.map { ($0.id, $0) })
      added += Set(r.keys).subtracting(l.keys).sorted().map { id + "/" + $0 }
      removed += Set(l.keys).subtracting(r.keys).sorted().map { id + "/" + $0 }
      for key in Set(l.keys).intersection(r.keys).sorted() {
        guard let a = l[key], let b = r[key] else { continue }
        for field in Set(a.fields.keys).union(b.fields.keys).sorted() {
          let x = a.fields[field]
          let y = b.fields[field]
          let category =
            field == "docComment"
            ? "documentation"
            : field == "availability"
              ? "availability"
              : field == "location" ? "provenance" : "interface"
          changes += differences(
            x?.value ?? .null, y?.value ?? .null, configuration: id, symbol: key,
            category: category, path: "/fields/" + escape(field) + "/value")
          var xp = try x.map(CanonicalJSON.value)?.object ?? [:]
          var yp = try y.map(CanonicalJSON.value)?.object ?? [:]
          xp.removeValue(forKey: "value")
          yp.removeValue(forKey: "value")
          changes += differences(
            .object(xp), .object(yp), configuration: id, symbol: key, category: "provenance",
            path: "/fields/" + escape(field))
        }
      }
      let le = try CanonicalJSON.value(
        SymbolGraphNormalizer.uniqueSorted(
          lhs.relationships.map { edge -> Relationship in
            var e = edge
            for key in e.fields.keys { e.fields[key]?.sources = [] }
            return e
          }))
      let re = try CanonicalJSON.value(
        SymbolGraphNormalizer.uniqueSorted(
          rhs.relationships.map { edge -> Relationship in
            var e = edge
            for key in e.fields.keys { e.fields[key]?.sources = [] }
            return e
          }))
      changes += differences(
        le, re, configuration: id, symbol: "", category: "interface", path: "/relationships")
      let oldMetadata = try CanonicalJSON.value(lhs).object
      let newMetadata = try CanonicalJSON.value(rhs).object
      for field in [
        "inputDigest", "packages", "expectedModules", "collectedModules", "graphs",
        "externalReferences",
      ] {
        changes += differences(
          oldMetadata[field] ?? .null, newMetadata[field] ?? .null, configuration: id,
          symbol: "", category: "provenance", path: "/" + field)
      }
      changes += differences(
        try CanonicalJSON.value(lhs.gaps), try CanonicalJSON.value(rhs.gaps), configuration: id,
        symbol: "", category: "provenance", path: "/gaps")
      changes += differences(
        try CanonicalJSON.value(lhs.merges), try CanonicalJSON.value(rhs.merges), configuration: id,
        symbol: "", category: "provenance", path: "/merges")
    }
    return SnapshotDifference(
      baseline: try baseline.identity(), candidate: try candidate.identity(), added: added.sorted(),
      removed: removed.sorted(),
      changes: changes, incomparableConfigurations: incompatible)
  }

  private static func differences(
    _ before: JSONValue, _ after: JSONValue, configuration: String, symbol: String,
    category: String, path: String
  ) -> [FieldChange] {
    guard before != after else { return [] }
    if case .object(let lhs) = before, case .object(let rhs) = after {
      return Set(lhs.keys).union(rhs.keys).sorted().flatMap {
        differences(
          lhs[$0] ?? .null, rhs[$0] ?? .null, configuration: configuration, symbol: symbol,
          category: category, path: path + "/" + escape($0))
      }
    }
    return [
      FieldChange(
        configuration: configuration, symbol: symbol, category: category, path: path,
        before: before, after: after)
    ]
  }
  private static func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
  }
}

public enum BaselineStore {
  public static func write(_ snapshot: EvidenceSnapshot, to url: URL) throws {
    try snapshot.validate()
    guard !snapshot.configurations.isEmpty else {
      throw DistillerError(.incomplete, "An empty snapshot cannot become a baseline")
    }
    for c in snapshot.configurations {
      guard Set(c.expectedModules).isSubset(of: Set(c.collectedModules)),
        !c.merges.contains(where: { $0.kind == "conflict" }),
        !c.gaps.contains(where: { $0.state == .failed || $0.state == .unsupported })
      else {
        throw DistillerError(.incomplete, "Incomplete collection cannot replace a baseline")
      }
    }
    try CanonicalJSON.write(snapshot, to: url)
  }

  public static func check(_ snapshot: EvidenceSnapshot, against url: URL) throws
    -> SnapshotDifference
  {
    try SnapshotComparator.compare(EvidenceSnapshot.read(url), snapshot)
  }
}

/// Compiler diagnostics remain separate evidence; exit status does not become release policy.
public struct CompilerDiagnostics: Codable, Sendable {
  public var producer: String
  public var baseline: String
  public var candidate: String
  public var status: Int32
  public var stdout: String
  public var stderr: String

  public static func package(
    root: URL, baselineRevision: String, toolchain: Toolchain,
    cache: URL, runner: ProcessRunner = .init()
  ) async throws -> Self {
    let flags = toolchain.packageArguments(
      root: root, scratch: cache.appendingPathComponent("compilation"))
    let output = try await runner.run(
      toolchain.swift,
      ["package"] + flags + [
        "diagnose-api-breaking-changes", baselineRevision,
        "--baseline-dir", cache.appendingPathComponent("baseline").path,
      ], directory: root)
    return Self(
      producer: "swift package diagnose-api-breaking-changes", baseline: baselineRevision,
      candidate: try PackageDescriptionDecoder.sourceDigest(root), status: output.status,
      stdout: portable(output.stdout, root: root, cache: cache),
      stderr: portable(output.stderr, root: root, cache: cache))
  }

  public static func digester(
    baseline: URL, candidate: URL, executable: String = "swift-api-digester",
    cache: URL, runner: ProcessRunner = .init()
  ) async throws -> Self {
    let result = try await runner.run(
      executable,
      [
        "-diagnose-sdk", "-input-paths", baseline.path,
        "-input-paths", candidate.path, "-compiler-style-diags",
      ], directory: cache)
    return Self(
      producer: "swift-api-digester", baseline: Digest.sha256(try Data(contentsOf: baseline)),
      candidate: Digest.sha256(try Data(contentsOf: candidate)), status: result.status,
      stdout: portable(result.stdout, root: baseline.deletingLastPathComponent(), cache: cache),
      stderr: portable(result.stderr, root: baseline.deletingLastPathComponent(), cache: cache))
  }

  static func portable(_ data: Data, root: URL, cache: URL) -> String {
    var text = String(decoding: data, as: UTF8.self)
    let paths = [
      (root.path, "<input>"), (cache.path, "<cache>"),
      (FileManager.default.homeDirectoryForCurrentUser.path, "<home>"),
      (NSTemporaryDirectory(), "<temporary>/"),
    ]
    for (path, name) in paths.sorted(by: { $0.0.count > $1.0.count }) where !path.isEmpty {
      text = text.replacingOccurrences(of: path, with: name)
    }
    return text
  }
}
