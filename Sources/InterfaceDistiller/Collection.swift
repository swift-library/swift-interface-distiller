// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Execution details belong in this report, never in canonical evidence.
public struct RunReport: Codable, Sendable {
  public var startedAt: String
  public var durationSeconds: Double
  public var inputPath: String
  public var cachePath: String
  public var cacheHit: Bool
  public var commands: [[String]]
}

public struct CollectionResult: Sendable {
  public var snapshot: EvidenceSnapshot
  public var report: RunReport
}

/// Compiler and SDK paths are execution inputs; their declared identities enter evidence.
public struct Toolchain: Sendable {
  public var swift: String
  public var clang: String
  public var sdkPath: String?
  public var configuration: BuildConfiguration

  public init(swift: String, clang: String, sdkPath: String?, configuration: BuildConfiguration) {
    self.swift = swift
    self.clang = clang
    self.sdkPath = sdkPath
    self.configuration = configuration
  }

  public static func discover(
    swift: String = "swift", clang: String = "clang", directory: URL,
    runner: ProcessRunner = .init()
  ) async throws -> Toolchain {
    let version = try await runner.checked(swift, ["--version"], directory: directory)
    let target = try await runner.checked(swift, ["-print-target-info"], directory: directory)
    let info = try JSONDecoder().decode(JSONValue.self, from: target.stdout)
    guard let triple = info["target"]["triple"].string else {
      throw DistillerError(.invalidInput, "Toolchain did not report its target triple")
    }
    var sdkPath: String?
    let sdkIdentity: String
    #if os(macOS)
      let sdk = try await runner.checked(
        "/usr/bin/xcrun", ["--show-sdk-path"], directory: directory)
      sdkPath = String(decoding: sdk.stdout, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines)
      let build = try await runner.checked(
        "/usr/bin/xcrun", ["--show-sdk-build-version"], directory: directory)
      sdkIdentity =
        "macOS:"
        + String(decoding: build.stdout, as: UTF8.self).trimmingCharacters(
          in: .whitespacesAndNewlines)
    #else
      let os = try Data(contentsOf: URL(fileURLWithPath: "/etc/os-release"))
      let libc = try await runner.checked("ldd", ["--version"], directory: directory)
      sdkIdentity = "system:" + Digest.sha256(os + libc.stdout)
    #endif
    let configuration = BuildConfiguration(
      toolchain: String(decoding: version.stdout, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines),
      sdk: sdkIdentity, triple: triple, deploymentTarget: deploymentTarget(in: triple))
    return Self(swift: swift, clang: clang, sdkPath: sdkPath, configuration: configuration)
  }

  func packageArguments(root: URL, scratch: URL) -> [String] {
    var args = [
      "--package-path", root.path, "--scratch-path", scratch.path,
      "--build-system", "native",
      "--security-path", scratch.appendingPathComponent("security").path,
      "--configuration", configuration.buildMode, "--triple", configuration.triple,
      "-Xswiftc", "-swift-version", "-Xswiftc", configuration.languageMode,
    ]
    if let sdkPath { args += ["--sdk", sdkPath] }
    for condition in configuration.conditions { args += ["-Xswiftc", "-D" + condition] }
    if !configuration.traits.isEmpty {
      args += ["--traits", configuration.traits.joined(separator: ",")]
    }
    return args
  }

  func validate(runner: ProcessRunner, directory: URL) async throws {
    let reported = try await runner.checked(swift, ["--version"], directory: directory)
    guard
      String(decoding: reported.stdout, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines) == configuration.toolchain
    else {
      throw DistillerError(
        .conflictingInput, "Configured toolchain build does not match the executing compiler")
    }
    guard configuration.extractorVersion == DistillerVersion.current,
      ["debug", "release"].contains(configuration.buildMode), !configuration.triple.isEmpty,
      !configuration.sdk.isEmpty,
      configuration.deploymentTarget == Self.deploymentTarget(in: configuration.triple)
    else {
      throw DistillerError(.usage, "Incomplete or invalid build configuration")
    }
  }

  static func deploymentTarget(in triple: String) -> String {
    guard triple.contains("-apple-") else { return "notApplicable" }
    guard
      let range = triple.range(of: "[0-9]+(?:\\.[0-9]+)*(?:-macabi)?$", options: .regularExpression)
    else { return "unspecified" }
    return String(triple[range]).replacingOccurrences(of: "-macabi", with: "")
  }
}

public struct InterfaceCollector: Sendable {
  public var runner: ProcessRunner
  public init(runner: ProcessRunner = .init()) { self.runner = runner }

  /// Builds selected library interfaces. Dependency modules must belong to the resolved graph.
  public func package(
    at root: URL, toolchain: Toolchain, scope: CollectionScope = .init(),
    dependencyModules: [String] = [], cache: URL? = nil
  ) async throws -> CollectionResult {
    let start = Date()
    let cache = cache ?? root.appendingPathComponent(".build/interface-distiller")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    let lock = try await CollectionLock.acquire(cache.appendingPathComponent("collection.lock"))
    defer { lock.release() }
    try await toolchain.validate(runner: runner, directory: root)
    let configurationID = try toolchain.configuration.identity()
    let scratch = cache.appendingPathComponent("compilation/" + configurationID)
    let flags = toolchain.packageArguments(root: root, scratch: scratch)
    var environment = ProcessInfo.processInfo.environment
    environment.merge(toolchain.configuration.environment) { _, new in new }
    var commands: [[String]] = []
    func command(_ args: [String]) async throws -> JSONValue {
      commands.append([toolchain.swift] + args)
      let result = try await runner.checked(
        toolchain.swift, args, directory: root, environment: environment)
      return try JSONDecoder().decode(JSONValue.self, from: result.stdout)
    }
    let resolved = try await command(
      ["package"] + flags + ["show-dependencies", "--format", "json"])
    let nodes = flattenDependencies(resolved)
    var packages: [PackageStructure] = []
    var roots: [String: URL] = [:]
    let pins =
      (try? JSONValue.read(root.appendingPathComponent("Package.resolved")))?["pins"].array ?? []
    for (index, node) in nodes.enumerated() {
      guard let path = node["path"].string else {
        throw DistillerError(.invalidInput, "Resolved package lacks checkout path")
      }
      let packageRoot = URL(fileURLWithPath: path)
      let packageFlags = toolchain.packageArguments(
        root: packageRoot, scratch: scratch.appendingPathComponent("structure-\(index)"))
      let description = try await command(
        ["package"] + packageFlags + ["describe", "--type", "json"])
      let manifest = try await command(["package"] + packageFlags + ["dump-package"])
      let display = description["name"].string ?? node["name"].string ?? "unknown"
      let identity =
        index == 0
        ? display.lowercased()
        : (node["identity"].string ?? node["name"].string?.lowercased() ?? display.lowercased())
      let origin = node["url"].string ?? ""
      let portableOrigin =
        origin.hasPrefix("/") || origin.hasPrefix("file:") || origin.isEmpty
        ? "local:" + identity : origin
      let pin = pins.first { $0["identity"].string == identity }
      let version = pin?["state"]["version"].string ?? node["version"].string
      let package = try PackageDescriptionDecoder.decode(
        description, manifest: manifest,
        identity: PackageIdentity(
          identity: identity, displayName: display, origin: portableOrigin,
          resolvedVersion: version == "unspecified" ? nil : version,
          revision: pin?["state"]["revision"].string ?? node["revision"].string), root: packageRoot)
      packages.append(package)
      for target in package.targets {
        if roots[target.module] != nil {
          throw DistillerError(
            .conflictingInput, "Resolved graph contains ambiguous module names",
            context: ["module": target.module])
        }
        roots[target.module] = packageRoot
      }
    }
    guard let primary = packages.first else {
      throw DistillerError(.invalidInput, "Resolved dependency graph is empty")
    }
    var libraryTargets = Set(primary.products.filter { $0.kind == "library" }.flatMap(\.targets))
    var pendingTargets = Array(libraryTargets)
    while let name = pendingTargets.popLast() {
      for dependency in primary.targets.first(where: { $0.name == name })?.dependencies ?? []
      where dependency.kind == "target" || dependency.kind == "byName" {
        if primary.targets.contains(where: { $0.name == dependency.name }),
          libraryTargets.insert(dependency.name).inserted
        {
          pendingTargets.append(dependency.name)
        }
      }
    }
    let defaultModules = primary.targets.filter { libraryTargets.contains($0.name) }.map(\.module)
    let selected = Set((scope.modules.isEmpty ? defaultModules : scope.modules) + dependencyModules)
      .sorted()
    let dependencyCandidates = Set(packages.dropFirst().flatMap { $0.targets.map(\.module) })
    for module in dependencyModules where !dependencyCandidates.contains(module) {
      throw DistillerError(
        .invalidInput, "Selected dependency module is absent from the resolved graph",
        context: ["module": module])
    }
    for module in selected where roots[module] == nil {
      throw DistillerError(
        .invalidInput, "Selected module is absent from the resolved graph",
        context: ["module": module])
    }
    var actualScope = scope
    actualScope.modules = selected
    let key = try CanonicalJSON.key(
      JSONValue.object([
        "configuration": try CanonicalJSON.value(toolchain.configuration),
        "scope": try CanonicalJSON.value(actualScope),
        "packages": try CanonicalJSON.value(packages),
      ]))
    let normalizedURL = cache.appendingPathComponent("normalized/" + key + ".json")
    if FileManager.default.fileExists(atPath: normalizedURL.path) {
      let snapshot = try EvidenceSnapshot.read(normalizedURL)
      return CollectionResult(
        snapshot: snapshot, report: report(start, root, cache, true, commands))
    }
    let collectedURL = cache.appendingPathComponent("collected/" + key)
    let inputs: [SymbolGraphInput]
    if FileManager.default.fileExists(
      atPath: collectedURL.appendingPathComponent("complete.json").path)
    {
      inputs = try loadCollected(collectedURL, roots: roots)
    } else {
      // SwiftPM owns compilation; extraction is limited to the requested module scope.
      let args = ["build"] + flags
      commands.append([toolchain.swift] + args)
      _ = try await runner.checked(toolchain.swift, args, directory: root, environment: environment)
      var found: [SymbolGraphInput] = []
      let bin = try await runner.checked(
        toolchain.swift, ["build"] + flags + ["--show-bin-path"], directory: root,
        environment: environment)
      let binPath = String(decoding: bin.stdout, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines)
      for module in selected {
        let target = packages.flatMap(\.targets).first { $0.module == module }
        if target?.moduleType != "SwiftTarget" { continue }
        let output = cache.appendingPathComponent("extraction/" + module)
        if FileManager.default.fileExists(atPath: output.path) {
          try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let args = moduleArguments(
          module, output: output, toolchain: toolchain,
          searchPaths: [
            URL(fileURLWithPath: binPath).appendingPathComponent("Modules").path, binPath,
          ], scope: actualScope)
        commands.append([toolchain.swift] + args)
        _ = try await runner.checked(
          toolchain.swift, args, directory: root, environment: environment)
        found += try SymbolGraphInput.load(output)
      }
      var adjusted: [SymbolGraphInput] = []
      for var input in found {
        let module = input.value["module"]["name"].string ?? ""
        guard selected.contains(module) else { continue }
        input.sourceRoot = roots[module]
        adjusted.append(input)
      }
      try FileManager.default.createDirectory(at: collectedURL, withIntermediateDirectories: true)
      for (index, input) in adjusted.enumerated() {
        // Portable collected graphs survive a cache relocation.
        let value = SymbolGraphNormalizer.portableValue(
          input.value, root: input.sourceRoot, locations: true)
        try CanonicalJSON.write(
          value, to: collectedURL.appendingPathComponent("\(index).symbols.json"))
      }
      try CanonicalJSON.write(
        ["key": key], to: collectedURL.appendingPathComponent("complete.json"))
      inputs = try loadCollected(collectedURL, roots: roots)
    }
    var gaps: [CollectionGap] = []
    for target in packages.flatMap(\.targets)
    where selected.contains(target.module) && target.moduleType != "SwiftTarget" {
      gaps.append(
        .init(
          target.module, .unsupported,
          "Target recorded as structure; use explicit binary module or header collection for its language view"
        ))
    }
    let snapshot = try SymbolGraphNormalizer.normalize(
      inputs, configuration: toolchain.configuration,
      scope: actualScope, expectedModules: selected, packages: packages, inputDigest: key,
      gaps: gaps)
    try CanonicalJSON.write(snapshot, to: normalizedURL)
    return CollectionResult(snapshot: snapshot, report: report(start, root, cache, false, commands))
  }

  /// Binary import requires an explicit matching compiler/environment record and content roots.
  public func module(
    _ name: String, searchPaths: [URL], toolchain: Toolchain,
    builtWith: BuildConfiguration, scope: CollectionScope = .init(), cache: URL
  ) async throws -> CollectionResult {
    guard builtWith == toolchain.configuration else {
      throw DistillerError(
        .conflictingInput, "Binary module environment does not match its producer")
    }
    guard !searchPaths.isEmpty else {
      throw DistillerError(.usage, "Binary collection requires content roots")
    }
    let start = Date()
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    let lock = try await CollectionLock.acquire(cache.appendingPathComponent("collection.lock"))
    defer { lock.release() }
    try await toolchain.validate(runner: runner, directory: cache)
    let fingerprints = try searchPaths.map { try PackageDescriptionDecoder.sourceDigest($0) }
    let key = try CanonicalJSON.key(
      JSONValue.object([
        "name": .string(name), "configuration": try CanonicalJSON.value(builtWith),
        "scope": try CanonicalJSON.value(scope),
        "contents": .array(fingerprints.map(JSONValue.string)),
      ]))
    let output = cache.appendingPathComponent("collected/" + key)
    let normalized = cache.appendingPathComponent("normalized/" + key + ".json")
    if FileManager.default.fileExists(atPath: normalized.path) {
      return CollectionResult(
        snapshot: try EvidenceSnapshot.read(normalized),
        report: report(start, searchPaths[0], cache, true, []))
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let args = moduleArguments(
      name, output: output, toolchain: toolchain, searchPaths: searchPaths.map(\.path), scope: scope
    )
    _ = try await runner.checked(toolchain.swift, args, directory: cache)
    let graphs = try SymbolGraphInput.load(output)
    let snapshot = try SymbolGraphNormalizer.normalize(
      graphs, configuration: builtWith, scope: scope, expectedModules: [name], inputDigest: key)
    try CanonicalJSON.write(snapshot, to: normalized)
    return CollectionResult(
      snapshot: snapshot,
      report: report(start, searchPaths[0], cache, false, [[toolchain.swift] + args]))
  }

  public func headers(
    _ headers: [URL], module: String, language: String, toolchain: Toolchain,
    sourceRoot: URL, scope: CollectionScope = .init(), cache: URL
  ) async throws -> CollectionResult {
    guard ["c", "objective-c"].contains(language), !headers.isEmpty else {
      throw DistillerError(
        .usage, "Headers require c or objective-c language and at least one input")
    }
    guard headers.allSatisfy({ PortablePath.relative($0, to: sourceRoot) != nil }) else {
      throw DistillerError(.invalidInput, "Every header must be inside its declared source root")
    }
    let start = Date()
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    let lock = try await CollectionLock.acquire(cache.appendingPathComponent("collection.lock"))
    defer { lock.release() }
    let version = try await runner.checked(toolchain.clang, ["--version"], directory: sourceRoot)
    var configuration = toolchain.configuration
    configuration.toolchain = String(decoding: version.stdout, as: UTF8.self).trimmingCharacters(
      in: .whitespacesAndNewlines)
    configuration.languageMode = language
    let key = try CanonicalJSON.key(
      JSONValue.object([
        "configuration": try CanonicalJSON.value(configuration),
        "scope": try CanonicalJSON.value(scope), "module": .string(module),
        "source": .string(try PackageDescriptionDecoder.sourceDigest(sourceRoot)),
        "headers": .array(
          headers.map { .string(PortablePath.relative($0, to: sourceRoot) ?? $0.lastPathComponent) }
        ),
      ]))
    let normalized = cache.appendingPathComponent("normalized/" + key + ".json")
    if FileManager.default.fileExists(atPath: normalized.path) {
      return CollectionResult(
        snapshot: try EvidenceSnapshot.read(normalized),
        report: report(start, sourceRoot, cache, true, []))
    }
    let output = cache.appendingPathComponent("collected/" + key)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let graphURL = output.appendingPathComponent(module + ".symbols.json")
    var args = [
      "-extract-api", "-x", language + "-header", "-target", configuration.triple,
      "-I", sourceRoot.path, "-o", graphURL.path,
    ]
    if let sdk = toolchain.sdkPath { args += ["-isysroot", sdk] }
    for condition in configuration.conditions { args += ["-D" + condition] }
    args += headers.map(\.path)
    _ = try await runner.checked(toolchain.clang, args, directory: sourceRoot)
    var raw = try JSONValue.read(graphURL).object
    var moduleInfo = raw["module"]?.object ?? [:]
    moduleInfo["name"] = .string(module)
    raw["module"] = .object(moduleInfo)
    let snapshot = try SymbolGraphNormalizer.normalize(
      [SymbolGraphInput(value: .object(raw), sourceRoot: sourceRoot, languageView: language)],
      configuration: configuration, scope: scope, expectedModules: [module], inputDigest: key,
      gaps: [.init(module + ".moduleName", .present, "Module label supplied by collection request")]
    )
    try CanonicalJSON.write(snapshot, to: normalized)
    return CollectionResult(
      snapshot: snapshot,
      report: report(start, sourceRoot, cache, false, [[toolchain.clang] + args]))
  }

  private func moduleArguments(
    _ name: String, output: URL, toolchain: Toolchain,
    searchPaths: [String], scope: CollectionScope
  ) -> [String] {
    var args = [
      "symbolgraph-extract", "-module-name", name, "-target", toolchain.configuration.triple,
      "-swift-version", toolchain.configuration.languageMode, "-output-dir", output.path,
      "-emit-extension-block-symbols",
    ]
    if let sdk = toolchain.sdkPath { args += ["-sdk", sdk] }
    if scope.includeSPI { args += ["-include-spi-symbols"] }
    for path in searchPaths { args += ["-I", path] }
    return args
  }

  private func flattenDependencies(_ node: JSONValue) -> [JSONValue] {
    var seen: Set<String> = []
    func visit(_ node: JSONValue) -> [JSONValue] {
      guard seen.insert(node["path"].string ?? "").inserted else { return [] }
      return [node] + node["dependencies"].array.flatMap(visit)
    }
    return visit(node)
  }

  private func loadCollected(_ url: URL, roots: [String: URL]) throws -> [SymbolGraphInput] {
    guard
      (try? FileManager.default.contentsOfDirectory(atPath: url.path).contains {
        $0.hasSuffix(".symbols.json")
      }) == true
    else { return [] }
    return try SymbolGraphInput.load(url).map { input in
      var copy = input
      copy.sourceRoot = roots[input.value["module"]["name"].string ?? ""]
      return copy
    }
  }

  private func report(
    _ start: Date, _ input: URL, _ cache: URL, _ hit: Bool, _ commands: [[String]]
  ) -> RunReport {
    RunReport(
      startedAt: ISO8601DateFormatter().string(from: start),
      durationSeconds: Date().timeIntervalSince(start),
      inputPath: input.path, cachePath: cache.path, cacheHit: hit, commands: commands)
  }
}

private final class CollectionLock {
  let fd: Int32
  private init(fd: Int32) { self.fd = fd }
  static func acquire(_ url: URL) async throws -> CollectionLock {
    let fd = open(url.path, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else { throw DistillerError(.io, "Cannot open collection lock") }
    do {
      while flock(fd, LOCK_EX | LOCK_NB) != 0 {
        guard errno == EWOULDBLOCK || errno == EAGAIN else {
          throw DistillerError(.io, "Cannot lock collection")
        }
        try await Task.sleep(nanoseconds: 25_000_000)
      }
      return CollectionLock(fd: fd)
    } catch {
      close(fd)
      throw error
    }
  }
  func release() {
    flock(fd, LOCK_UN)
    close(fd)
  }
}
