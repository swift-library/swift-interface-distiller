// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

/// Identity is independent of display name and checkout location.
public struct PackageIdentity: Codable, Sendable, Equatable {
  public var identity: String
  public var displayName: String
  public var origin: String
  public var resolvedVersion: String?
  public var revision: String?
}

public struct ProductStructure: Codable, Sendable, Equatable {
  public var name: String
  public var kind: String
  public var targets: [String]
}

public struct DependencyCondition: Codable, Sendable, Equatable {
  public var platforms: [String]
  public var traits: [String]
  public var configuration: String?
  public var state: ObservationState
  public var raw: JSONValue
}

public struct TargetDependency: Codable, Sendable, Equatable {
  public var kind: String
  public var name: String
  public var package: String?
  public var condition: DependencyCondition
}

public struct SourceFile: Codable, Sendable, Equatable {
  public var path: String
  public var digest: String
}

public struct TargetStructure: Codable, Sendable, Equatable {
  public var name: String
  public var module: String
  public var kind: String
  public var moduleType: String
  public var sources: [SourceFile]
  public var dependencies: [TargetDependency]
}

public struct PackageStructure: Codable, Sendable, Equatable {
  public var identity: PackageIdentity
  public var products: [ProductStructure]
  public var targets: [TargetStructure]
  public var sourceDigest: String
  public var provenance: ProvenanceKind
}

enum PortablePath {
  static func relative(_ url: URL, to root: URL) -> String? {
    let base = root.standardizedFileURL.resolvingSymlinksInPath().path
    let path = url.standardizedFileURL.resolvingSymlinksInPath().path
    guard path.hasPrefix(base + "/") else { return path == base ? "." : nil }
    return String(path.dropFirst(base.count + 1))
  }
}

/// Decodes SwiftPM's public command output into package-owned types.
public enum PackageDescriptionDecoder {
  public static func decode(
    _ description: JSONValue, manifest: JSONValue, identity: PackageIdentity,
    root: URL
  ) throws -> PackageStructure {
    guard description["name"].string != nil, case .array = description["targets"] else {
      throw DistillerError(.invalidInput, "Malformed SwiftPM description")
    }
    let products = description["products"].array.map { p in
      ProductStructure(
        name: p["name"].string ?? "", kind: p["type"].object.keys.sorted().first ?? "unknown",
        targets: p["targets"].strings.sorted())
    }.sorted { $0.name < $1.name }
    let targets = try description["targets"].array.map { target in
      let name = target["name"].string ?? ""
      let path = target["path"].string ?? "Sources/\(name)"
      let sourceFiles = try target["sources"].strings.map { source in
        let url = root.appendingPathComponent(path).appendingPathComponent(source)
        guard let relative = PortablePath.relative(url, to: root) else {
          throw DistillerError(
            .invalidInput, "Target source escapes package root", context: ["target": name])
        }
        return SourceFile(path: relative, digest: Digest.sha256(try Data(contentsOf: url)))
      }.sorted { $0.path < $1.path }
      let rawTarget = manifest["targets"].array.first { $0["name"].string == name }
      var dependencies: [TargetDependency] = []
      if let rawTarget {
        dependencies = rawTarget["dependencies"].array.map { dep in
          let kind = dep.object.keys.sorted().first ?? "unknown"
          let values = dep[kind].array
          let condition = values.last ?? .null
          return TargetDependency(
            kind: kind, name: values.first?.string ?? "",
            package: kind == "product" && values.count > 1 ? values[1].string : nil,
            condition: DependencyCondition(
              platforms: condition["platformNames"].strings.sorted(),
              traits: condition["traits"].strings.sorted(),
              configuration: condition["config"].string,
              state: condition == .null ? .absent : .present, raw: condition))
        }
      } else {
        dependencies =
          (target["target_dependencies"].strings + target["product_dependencies"].strings).map {
            TargetDependency(
              kind: "unresolved", name: $0, package: nil,
              condition: DependencyCondition(
                platforms: [], traits: [], configuration: nil, state: .notCollected, raw: .null))
          }
      }
      return TargetStructure(
        name: name, module: target["c99name"].string ?? name,
        kind: target["type"].string ?? "unknown",
        moduleType: target["module_type"].string ?? "unknown",
        sources: sourceFiles,
        dependencies: dependencies.sorted { ($0.kind, $0.name) < ($1.kind, $1.name) })
    }.sorted { $0.name < $1.name }
    return PackageStructure(
      identity: identity, products: products, targets: targets,
      sourceDigest: try sourceDigest(root), provenance: .parsed)
  }

  /// Includes uncommitted and untracked regular files. Producer outputs and VCS metadata are excluded.
  public static func sourceDigest(_ root: URL) throws -> String {
    guard
      let enumerator = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    else {
      throw DistillerError(.missingInput, "Cannot enumerate package sources")
    }
    var entries: [SourceFile] = []
    for case let url as URL in enumerator {
      if [".build", ".git", ".swiftpm"].contains(url.lastPathComponent) {
        enumerator.skipDescendants()
        continue
      }
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      if values.isSymbolicLink == true {
        guard let relative = PortablePath.relative(url, to: root) else {
          throw DistillerError(
            .unsupported, "Source symlinks outside the package require an explicit input boundary")
        }
        let resolved = url.resolvingSymlinksInPath()
        if try resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile != true {
          throw DistillerError(.unsupported, "Directory symlinks are not a closed source input")
        }
        let lexical = String(
          url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
        let digest = try CanonicalJSON.key([
          "target": relative, "content": Digest.sha256(try Data(contentsOf: resolved)),
        ])
        entries.append(SourceFile(path: lexical, digest: digest))
      } else if values.isRegularFile == true, let relative = PortablePath.relative(url, to: root) {
        entries.append(SourceFile(path: relative, digest: Digest.sha256(try Data(contentsOf: url))))
      }
    }
    return try CanonicalJSON.key(entries.sorted { $0.path < $1.path })
  }
}
