// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import InterfaceDistiller

func writeExample(to destination: URL) throws {
  let source = try #require(
    Bundle.module.url(forResource: "Example", withExtension: nil, subdirectory: "Fixtures"))
  for relative in ["Package.swift", "Sources/EvidenceExample/Example.swift"] {
    let target = destination.appendingPathComponent(relative)
    try FileManager.default.createDirectory(
      at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contentsOf: source.appendingPathComponent(relative)).write(to: target)
  }
}

@Test func collectionsRemainStableAcrossPathsCachesAndConcurrentRuns() async throws {
  let root = try testDirectory("collection-determinism")
  let firstRoot = root.appendingPathComponent("first-checkout")
  let secondRoot = root.appendingPathComponent("second-checkout")
  try writeExample(to: firstRoot)
  try writeExample(to: secondRoot)
  let tools = try await Toolchain.discover(directory: root)
  let collector = InterfaceCollector()
  let scope = CollectionScope(includeSPI: true, sourceLocations: true)
  let cold = try await collector.package(at: firstRoot, toolchain: tools, scope: scope)
  async let left = collector.package(at: firstRoot, toolchain: tools, scope: scope)
  async let right = collector.package(at: firstRoot, toolchain: tools, scope: scope)
  let warm = try await [left, right]
  let relocated = try await collector.package(at: secondRoot, toolchain: tools, scope: scope)
  for result in warm + [relocated] {
    #expect(try CanonicalJSON.encode(result.snapshot) == CanonicalJSON.encode(cold.snapshot))
  }
  #expect(!cold.report.cacheHit)
  #expect(warm.allSatisfy { $0.report.cacheHit })
  let text = String(decoding: try CanonicalJSON.encode(cold.snapshot), as: UTF8.self)
  #expect(!text.contains(root.path))
  #expect(!text.contains("file://"))
  let source = firstRoot.appendingPathComponent("Sources/EvidenceExample/Example.swift")
  var contents = try String(contentsOf: source, encoding: .utf8)
  contents += "\npublic struct AddedItem { public init() {} }\n"
  try contents.write(to: source, atomically: true, encoding: .utf8)
  let changed = try await collector.package(at: firstRoot, toolchain: tools, scope: scope)
  #expect(!changed.report.cacheHit)
  #expect(changed.snapshot.configurations[0].symbols.contains { $0.name == "AddedItem" })
  #expect(!((try SnapshotComparator.compare(cold.snapshot, changed.snapshot)).added.isEmpty))
}

@Test func selectedConditionsProduceDistinctConfigurations() async throws {
  let root = try testDirectory("condition-collection")
  try writeExample(to: root)
  var tools = try await Toolchain.discover(directory: root)
  tools.configuration.conditions = ["EXTRA"]
  let result = try await InterfaceCollector().package(at: root, toolchain: tools)
  #expect(result.snapshot.configurations[0].symbols.contains { $0.name == "ExtraItem" })
  #expect(result.snapshot.configurations[0].configuration.conditions == ["EXTRA"])
}

@Test func explicitBinaryEnvironmentMustMatch() async throws {
  let root = try testDirectory("binary-environment")
  let tools = try await Toolchain.discover(directory: root)
  var mismatch = tools.configuration
  mismatch.toolchain = "another compiler"
  do {
    _ = try await InterfaceCollector().module(
      "Unavailable", searchPaths: [root], toolchain: tools, builtWith: mismatch,
      cache: root.appendingPathComponent(".build/cache"))
    Issue.record("Expected mismatched environment failure")
  } catch let error as DistillerError { #expect(error.code == .conflictingInput) }
}

@Test func clangCollectionRetainsLanguageAndRelativeLocations() async throws {
  let root = try testDirectory("clang-collection")
  let header = root.appendingPathComponent("Point.h")
  try Data(
    "/// A planar point.\ntypedef struct Point { double x; double y; } Point;\n/// Makes a point.\nPoint make_point(double x, double y);\n"
      .utf8
  ).write(to: header)
  let tools = try await Toolchain.discover(directory: root)
  let result = try await InterfaceCollector().headers(
    [header], module: "Geometry", language: "c", toolchain: tools,
    sourceRoot: root, scope: .init(sourceLocations: true),
    cache: root.appendingPathComponent(".build/cache"))
  #expect(result.snapshot.configurations[0].symbols.count == 4)
  #expect(result.snapshot.configurations[0].graphs.allSatisfy { $0.languageView == "c" })
  #expect(
    !String(decoding: try CanonicalJSON.encode(result.snapshot), as: UTF8.self).contains(root.path))
}

@Test func structuralDecoderKeepsConditionsAndSpecialTargets() throws {
  let root = try testDirectory("structure-model")
  try Data("manifest input".utf8).write(to: root.appendingPathComponent("Package.swift"))
  let description: JSONValue = .object([
    "name": .string("Display Name"), "products": .array([]),
    "targets": .array([
      .object([
        "name": .string("Binary"), "type": .string("binary"),
        "module_type": .string("BinaryTarget"), "sources": .array([]),
      ]),
      .object([
        "name": .string("System"), "type": .string("system-target"),
        "module_type": .string("SystemLibraryTarget"), "sources": .array([]),
      ]),
    ]),
  ])
  let condition: JSONValue = .object([
    "platformNames": .array([.string("macos")]), "traits": .array([.string("Extra")]),
  ])
  let manifest: JSONValue = .object([
    "targets": .array([
      .object([
        "name": .string("Binary"),
        "dependencies": .array([
          .object([
            "product": .array([.string("Support"), .string("support-package"), .null, condition])
          ])
        ]),
      ])
    ])
  ])
  let identity = PackageIdentity(
    identity: "identity", displayName: "Display Name", origin: "https://example.org/package.git",
    resolvedVersion: "1.0.0", revision: "revision")
  let result = try PackageDescriptionDecoder.decode(
    description, manifest: manifest, identity: identity, root: root)
  #expect(result.identity.identity != result.identity.displayName)
  #expect(result.targets.map(\.kind) == ["binary", "system-target"])
  #expect(result.targets[0].dependencies[0].condition.platforms == ["macos"])
  #expect(result.targets[0].dependencies[0].condition.traits == ["Extra"])
  #expect(result.targets.allSatisfy { $0.sources.isEmpty })
}

@Test func resolvedDependencySelectionAndMatchingBinaryImports() async throws {
  let root = try testDirectory("resolved-dependency")
  let dependency = root.appendingPathComponent("dependency")
  let consumer = root.appendingPathComponent("consumer")
  let fm = FileManager.default
  try fm.createDirectory(
    at: dependency.appendingPathComponent("Sources/Support"), withIntermediateDirectories: true)
  try fm.createDirectory(
    at: consumer.appendingPathComponent("Sources/Client"), withIntermediateDirectories: true)
  try Data(
    "// swift-tools-version: 6.3\nimport PackageDescription\nlet package = Package(name: \"SupportPackage\", products: [.library(name: \"Support\", targets: [\"Support\"])], targets: [.target(name: \"Support\")])\n"
      .utf8
  ).write(to: dependency.appendingPathComponent("Package.swift"))
  try Data("public struct SupportValue { public init() {} }\n".utf8).write(
    to: dependency.appendingPathComponent("Sources/Support/Support.swift"))
  let runner = ProcessRunner()
  for arguments in [
    ["init", "--initial-branch=master"], ["add", "."],
    [
      "-c", "user.name=Fixture", "-c", "user.email=fixture@example.org", "-c",
      "commit.gpgsign=false", "commit", "-m", "feat: provide fixture",
    ],
    ["-c", "tag.gpgsign=false", "tag", "1.0.0"],
  ] {
    _ = try await runner.checked("git", arguments, directory: dependency)
  }
  // Generated manifests use a local versioned remote; the published package has no dependencies.
  let manifest =
    "// swift-tools-version: 6.3\nimport PackageDescription\nlet package = Package(name: \"Client\", products: [.library(name: \"Client\", targets: [\"Client\"])], dependencies: [.package(url: \"\(dependency.absoluteString)\", from: \"1.0.0\")], targets: [.target(name: \"Client\", dependencies: [.product(name: \"Support\", package: \"dependency\", condition: .when(platforms: [.macOS, .linux]))])])\n"
  try Data(manifest.utf8).write(to: consumer.appendingPathComponent("Package.swift"))
  try Data("import Support\npublic func makeSupport() -> SupportValue { SupportValue() }\n".utf8)
    .write(to: consumer.appendingPathComponent("Sources/Client/Client.swift"))
  let tools = try await Toolchain.discover(directory: root)
  let collector = InterfaceCollector()
  let result = try await collector.package(
    at: consumer, toolchain: tools, dependencyModules: ["Support"])
  #expect(result.snapshot.configurations[0].collectedModules == ["Client", "Support"])
  #expect(
    result.snapshot.configurations[0].packages.contains { $0.identity.resolvedVersion == "1.0.0" })
  let build = consumer.appendingPathComponent(
    ".build/interface-distiller/compilation/" + (try tools.configuration.identity()))
  let bin = try await runner.checked(
    tools.swift,
    ["build"] + tools.packageArguments(root: consumer, scratch: build) + ["--show-bin-path"],
    directory: consumer)
  let path = URL(
    fileURLWithPath: String(decoding: bin.stdout, as: UTF8.self).trimmingCharacters(
      in: .whitespacesAndNewlines)
  ).appendingPathComponent("Modules")
  let binary = try await collector.module(
    "Support", searchPaths: [path], toolchain: tools, builtWith: tools.configuration,
    cache: root.appendingPathComponent(".build/binary-cache"))
  #expect(binary.snapshot.configurations[0].symbols.contains { $0.name == "SupportValue" })
  do {
    _ = try await collector.package(at: consumer, toolchain: tools, dependencyModules: ["Absent"])
    Issue.record("Expected selection failure")
  } catch let error as DistillerError { #expect(error.code == .invalidInput) }
}

@Test func objectiveCHeadersRetainTheirLanguageView() async throws {
  let root = try testDirectory("objc-collection")
  let header = root.appendingPathComponent("Widget.h")
  try Data(
    "__attribute__((objc_root_class)) @interface Widget\n/// A widget count.\n@property (readonly) int count;\n@end\n"
      .utf8
  ).write(to: header)
  let tools = try await Toolchain.discover(directory: root)
  let result = try await InterfaceCollector().headers(
    [header], module: "Widgets", language: "objective-c", toolchain: tools,
    sourceRoot: root, cache: root.appendingPathComponent(".build/cache"))
  #expect(result.snapshot.configurations[0].graphs.allSatisfy { $0.languageView == "objective-c" })
  #expect(result.snapshot.configurations[0].symbols.contains { $0.name == "Widget" })
}

@Test func sourceIdentityIncludesInternalSymlinkTargets() throws {
  let root = try testDirectory("source-symlinks")
  let first = root.appendingPathComponent("first.txt")
  let second = root.appendingPathComponent("second.txt")
  try Data("same source".utf8).write(to: first)
  try Data("same source".utf8).write(to: second)
  let link = root.appendingPathComponent("linked.txt")
  try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "first.txt")
  let original = try PackageDescriptionDecoder.sourceDigest(root)
  try FileManager.default.removeItem(at: link)
  try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "second.txt")
  #expect(try PackageDescriptionDecoder.sourceDigest(root) != original)
  try FileManager.default.removeItem(at: link)
  try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "..")
  #expect(throws: DistillerError.self) { try PackageDescriptionDecoder.sourceDigest(root) }
}
