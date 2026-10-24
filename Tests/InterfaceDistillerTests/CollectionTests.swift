// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import InterfaceDistiller

func writeExample(to destination: URL) throws {
  let source = try #require(
    Bundle.module.url(forResource: "Example", withExtension: nil, subdirectory: "Fixtures"))
  for relative in ["Package.swift", "Sources/SnapshotExample/Example.swift"] {
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
  let source = firstRoot.appendingPathComponent("Sources/SnapshotExample/Example.swift")
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

@Test func libraryCollectionWithUnbuiltTestTargets() async throws {
  let root = try testDirectory("library-with-tests")
  try writeExample(to: root)
  let manifest = root.appendingPathComponent("Package.swift")
  let contents = try String(contentsOf: manifest, encoding: .utf8).replacingOccurrences(
    of: "targets: [.target(name: \"SnapshotExample\")]",
    with:
      "targets: [.target(name: \"SnapshotExample\"), .testTarget(name: \"ExampleTests\", dependencies: [\"SnapshotExample\"])]"
  )
  try contents.write(to: manifest, atomically: true, encoding: .utf8)
  let testSource = root.appendingPathComponent("Tests/ExampleTests/ExampleTests.swift")
  try FileManager.default.createDirectory(
    at: testSource.deletingLastPathComponent(), withIntermediateDirectories: true)
  try Data("import Testing\n@Test func example() {}\n".utf8).write(to: testSource)
  let tools = try await Toolchain.discover(directory: root)
  let result = try await InterfaceCollector().package(at: root, toolchain: tools)
  #expect(result.snapshot.configurations[0].collectedModules == ["SnapshotExample"])
  #expect(result.snapshot.configurations[0].symbols.contains { $0.name == "Item" })
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

@Test(arguments: [false, true])
func libraryCollectionResolvesClangImports(customModuleMap: Bool) async throws {
  let root = try testDirectory("clang-import-\(customModuleMap)")
  let files = [
    "Package.swift": """
    // swift-tools-version: 6.3
    import PackageDescription
    let package = Package(name: "Client", products: [.library(name: "Client", targets: ["Client"])],
      targets: [.target(name: "Bridge", publicHeadersPath: "Headers"),
        .target(name: "Client", dependencies: ["Bridge"])])
    """,
    "Sources/Bridge/Headers/Bridge.h": "int bridge_value(void);\n",
    "Sources/Bridge/Bridge.c": "int bridge_value(void) { return 7; }\n",
    "Sources/Client/Client.swift":
      "import Bridge\npublic func value() -> Int32 { bridge_value() }\n",
  ]
  for (path, content) in files {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(content.utf8).write(to: url)
  }
  if customModuleMap {
    try Data("module Bridge { header \"Bridge.h\" export * }\n".utf8).write(
      to: root.appendingPathComponent("Sources/Bridge/Headers/module.modulemap"))
  }
  let tools = try await Toolchain.discover(directory: root)
  let result = try await InterfaceCollector().package(at: root, toolchain: tools)
  let configuration = result.snapshot.configurations[0]
  #expect(configuration.expectedModules == ["Client"])
  #expect(configuration.collectedModules == ["Client"])
  #expect(configuration.symbols.contains { $0.name == "value()" })
  #expect(configuration.packages[0].targets.contains { $0.module == "Bridge" })
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

@Test func libraryModuleSelectionUsesProductRoles() throws {
  let root = try testDirectory("library-module-roles")
  func target(_ name: String, _ kind: String, _ moduleType: String) -> JSONValue {
    .object([
      "name": .string(name), "type": .string(kind), "module_type": .string(moduleType),
      "sources": .array([]),
    ])
  }
  let description: JSONValue = .object([
    "name": .string("Client"),
    "products": .array([
      .object([
        "name": .string("Client"), "type": .object(["library": .array([.string("automatic")])]),
        "targets": .array([.string("Client")]),
      ])
    ]),
    "targets": .array([
      target("Client", "library", "SwiftTarget"), target("Support", "library", "SwiftTarget"),
      target("Macros", "macro", "SwiftTarget"), target("Bridge", "library", "ClangTarget"),
      target("Generator", "executable", "SwiftTarget"), target("Plugin", "plugin", "PluginTarget"),
    ]),
  ])
  let manifest: JSONValue = .object([
    "targets": .array([
      .object([
        "name": .string("Client"),
        "dependencies": .array(
          ["Support", "Macros", "Bridge", "Generator", "Plugin"].map {
            .object(["target": .array([.string($0), .null])])
          }),
      ])
    ])
  ])
  let structure = try PackageDescriptionDecoder.decode(
    description, manifest: manifest,
    identity: .init(identity: "client", displayName: "Client", origin: "local:client"), root: root)
  #expect(structure.libraryModules == ["Client", "Support"])
  #expect(structure.targets.count == 6)
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
    "// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: \"SupportPackage\", products: [.library(name: \"Support\", targets: [\"Support\"])], targets: [.target(name: \"Support\")])\n"
      .utf8
  ).write(to: dependency.appendingPathComponent("Package.swift"))
  try Data(
    "public class SupportValue { public static let shared = SupportValue(); public init() {} }\n"
      .utf8
  ).write(
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

@Test func libraryCollectionIncludesTestingSearchPaths() async throws {
  let root = try testDirectory("testing-library")
  try writeExample(to: root)
  try Data(
    "import Testing\nimport Foundation\npublic func record(_ comment: Comment) { Issue.record(comment) }\n"
      .utf8
  )
  .write(to: root.appendingPathComponent("Sources/SnapshotExample/Example.swift"))
  let tools = try await Toolchain.discover(directory: root)
  let result = try await InterfaceCollector().package(at: root, toolchain: tools)
  #expect(result.snapshot.configurations[0].symbols.contains { $0.name == "record(_:)" })
}

@Test func collectionAcceptsInternalDirectorySymlinksAndHashesTargets() async throws {
  let root = try testDirectory("directory-symlink-package")
  try writeExample(to: root)
  let link = root.appendingPathComponent("LinkedSources")
  try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "Sources")
  // Internal cycles have finite identity and never recursively enumerate the link.
  try FileManager.default.createSymbolicLink(
    atPath: root.appendingPathComponent("Self").path, withDestinationPath: ".")
  let before = try PackageDescriptionDecoder.sourceDigest(root)
  let tools = try await Toolchain.discover(directory: root)
  let result = try await InterfaceCollector().package(at: root, toolchain: tools)
  #expect(result.snapshot.configurations[0].symbols.contains { $0.name == "Item" })
  try Data("public struct Updated {}\n".utf8).write(
    to: link.appendingPathComponent("SnapshotExample/Example.swift"))
  #expect(try PackageDescriptionDecoder.sourceDigest(root) != before)
  try FileManager.default.removeItem(at: link)
  try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "..")
  #expect(throws: DistillerError.self) { try PackageDescriptionDecoder.sourceDigest(root) }
}

@Test func commentOnlyLibraryAndExecutableOnlyScopesNeedNoBuild() async throws {
  let root = try testDirectory("empty-scope")
  try writeExample(to: root)
  let source = root.appendingPathComponent("Sources/SnapshotExample/Example.swift")
  try Data("// Template\n/* outer /* inner */ comment */\n".utf8).write(to: source)
  let tools = try await Toolchain.discover(directory: root)
  let empty = try await InterfaceCollector().package(at: root, toolchain: tools)
  #expect(empty.snapshot.configurations[0].expectedModules.isEmpty)
  #expect(empty.snapshot.configurations[0].symbols.isEmpty)
  #expect(empty.snapshot.configurations[0].gaps.isEmpty)
  #expect(!empty.report.commands.contains { $0.dropFirst().first == "build" })
  let manifest = root.appendingPathComponent("Package.swift")
  let text = try String(contentsOf: manifest, encoding: .utf8)
    .replacingOccurrences(of: ".library(", with: ".executable(")
    .replacingOccurrences(of: ".target(", with: ".executableTarget(")
  try text.write(to: manifest, atomically: true, encoding: .utf8)
  try Data("this executable cannot build\n".utf8).write(to: source)
  let executable = try await InterfaceCollector().package(at: root, toolchain: tools)
  #expect(executable.snapshot.configurations[0].expectedModules.isEmpty)
  #expect(!executable.report.commands.contains { $0.dropFirst().first == "build" })
  #expect(!PackageDescriptionDecoder.isSwiftTrivia(Data("/* unclosed".utf8)))
  #expect(
    !PackageDescriptionDecoder.isSwiftTrivia(Data("/* comment */ public struct Value {}".utf8)))
}

@Test func collectionPolicyDropsCopiesButKeepsProtocolExtensions() async throws {
  let root = try testDirectory("synthesized-policy")
  try writeExample(to: root)
  let tools = try await Toolchain.discover(directory: root)
  let collector = InterfaceCollector()
  let selected = try await collector.package(at: root, toolchain: tools)
  let all = try await collector.package(
    at: root, toolchain: tools, scope: .init(includeSynthesized: true))
  #expect(selected.snapshot.configurations[0].scope.includeSynthesized == false)
  #expect(all.snapshot.configurations[0].scope.includeSynthesized == true)
  #expect(
    !selected.snapshot.configurations[0].symbols.contains {
      $0.preciseIdentifier.contains("::SYNTHESIZED::")
    })
  #expect(
    all.snapshot.configurations[0].symbols.contains {
      $0.preciseIdentifier.contains("::SYNTHESIZED::")
    })
  #expect(selected.snapshot.configurations[0].symbols.contains { $0.name == "label" })
  #expect(
    !selected.snapshot.configurations[0].gaps.contains { $0.subject.contains("::SYNTHESIZED::") })
  #expect(selected.report.commands.contains { $0.contains("-skip-synthesized-members") })
  #expect(!all.report.commands.contains { $0.contains("-skip-synthesized-members") })
}

@Test func collectionCanonicalizesPathsForBuildToolsAndClangModules() async throws {
  let directory = try testDirectory("tool-and-clang-paths")
  let root = directory.appendingPathComponent("package")
  let files = [
    "Package.swift": """
    // swift-tools-version: 6.3
    import PackageDescription
    let package = Package(name: "ToolClient", products: [.library(name: "Client", targets: ["Client"])],
      targets: [.target(name: "Bridge"), .target(name: "Client", dependencies: ["Bridge"], plugins: ["Generate"]),
        .executableTarget(name: "Generator"),
        .plugin(name: "Generate", capability: .buildTool(), dependencies: ["Generator"])])
    """,
    "Sources/Bridge/include/Bridge.h": "#include <stdint.h>\nint32_t bridge_value(void);\n",
    "Sources/Bridge/Bridge.c": "#include \"Bridge.h\"\nint32_t bridge_value(void) { return 7; }\n",
    "Sources/Client/Client.swift": "// Declarations are generated by the build plugin.\n",
    "Sources/Generator/main.swift": """
    import Foundation
    try "import Bridge\\npublic struct GeneratedValue {}\\npublic func value() -> Int32 { bridge_value() }\\n".write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
    """,
    "Plugins/Generate/Generate.swift": """
    import PackagePlugin
    @main struct Generate: BuildToolPlugin {
      func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let output = context.pluginWorkDirectoryURL.appending(path: "Generated.swift")
        return [.buildCommand(displayName: "Generate interface", executable: try context.tool(named: "Generator").url,
          arguments: [output.path], outputFiles: [output])]
      }
    }
    """,
  ]
  for (path, content) in files {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(content.utf8).write(to: url)
  }
  let alias = directory.appendingPathComponent("alias")
  try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: "package")
  let tools = try await Toolchain.discover(directory: directory)
  let result = try await InterfaceCollector().package(at: alias, toolchain: tools)
  #expect(result.snapshot.configurations[0].symbols.contains { $0.name == "GeneratedValue" })
  #expect(result.report.inputPath == root.resolvingSymlinksInPath().path)
  #expect(!result.report.commands.flatMap { $0 }.contains { $0.contains(alias.path) })
  let direct = try await InterfaceCollector().package(at: root, toolchain: tools)
  #expect(direct.report.cacheHit)
  #expect(direct.snapshot == result.snapshot)
}
