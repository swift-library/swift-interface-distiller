// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import InterfaceDistiller

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

@main struct InterfaceDistillerCommand {
  static func main() async {
    let task = Task { try await execute(Array(CommandLine.arguments.dropFirst())) }
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
    let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
    interrupt.setEventHandler { task.cancel() }
    terminate.setEventHandler { task.cancel() }
    interrupt.resume()
    terminate.resume()
    do {
      let status = try await task.value
      interrupt.cancel()
      terminate.cancel()
      exit(status)
    } catch {
      let failure =
        error as? DistillerError
        ?? DistillerError(error is CancellationError ? .cancelled : .io, String(describing: error))
      if let data = try? CanonicalJSON.encode(failure) { FileHandle.standardError.write(data) }
      switch failure.code {
      case .cancelled: exit(130)
      case .processFailed, .timeout: exit(3)
      case .incomplete: exit(4)
      default: exit(2)
      }
    }
  }

  static func execute(_ values: [String]) async throws -> Int32 {
    if values == ["--version"] {
      print(DistillerVersion.current)
      return 0
    }
    if values.isEmpty || values == ["--help"] {
      print(
        """
        interface-distiller — public-interface evidence

        configuration                           Print detected build configuration
        collect package PATH                    Collect a local package
        collect module NAME --search-path PATH --built-with CONFIG
        collect headers NAME --header PATH --language c|objective-c
        normalize GRAPH... --configuration CONFIG
        merge SNAPSHOT...
        render SNAPSHOT --output-dir DIR [--view interface|evidence] [--byte-budget N]
        query SNAPSHOT lookup|members|conformers|initializers|returning|slice SYMBOL...
        slice SNAPSHOT SYMBOL...                Query a reference closure
        compare BASELINE CANDIDATE
        baseline write|check SNAPSHOT FILE
        coverage SNAPSHOT
        diagnose package PATH --baseline-ref REV
        diagnose digester --baseline FILE --candidate FILE

        Common options: --output FILE, --configuration FILE, --module NAME,
        --include GLOB, --exclude GLOB, --include-spi, --source-locations,
        --source-root DIR, --cache DIR, --report FILE, --timeout SECONDS,
        --swift EXECUTABLE, --clang EXECUTABLE, --sdk-path DIR.
        Query options: --configuration-id ID, --max-symbols N, --max-bytes N,
        --format json|swift|markdown (default json).
        Readable views: --docs summary|full|none (default summary).
        Package option: --dependency-module NAME (repeatable).
        See Documentation/Commands.md for contracts and exit codes.
        """)
      return 0
    }
    let args = try Arguments(values)
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let runner = ProcessRunner(timeout: try args.double("timeout") ?? 600)
    func file(_ text: String) -> URL {
      URL(fileURLWithPath: text, relativeTo: cwd).standardizedFileURL
    }
    func emit<T: Encodable>(_ value: T) throws {
      if let output = args.one("output") {
        try CanonicalJSON.write(value, to: file(output))
      } else {
        FileHandle.standardOutput.write(try CanonicalJSON.encode(value))
      }
    }
    func position(_ index: Int) throws -> String {
      guard args.positionals.count > index else {
        throw DistillerError(.usage, "Missing command argument")
      }
      return args.positionals[index]
    }
    func toolchain() async throws -> Toolchain {
      var tools = try await Toolchain.discover(
        swift: args.one("swift") ?? "swift", clang: args.one("clang") ?? "clang", directory: cwd,
        runner: runner)
      if let config = args.one("configuration") {
        tools.configuration = try JSONDecoder().decode(
          BuildConfiguration.self, from: Data(contentsOf: file(config)))
      }
      if let sdk = args.one("sdk-path") { tools.sdkPath = file(sdk).path }
      return tools
    }
    let scope = CollectionScope(
      modules: args.many("module"), include: args.many("include"), exclude: args.many("exclude"),
      includeSPI: args.flag("include-spi"), sourceLocations: args.flag("source-locations"))
    guard let docs = DocumentationStyle(rawValue: args.one("docs") ?? "summary"),
      let format = QueryFormat(rawValue: args.one("format") ?? "json"),
      let view = MarkdownRenderer.View(rawValue: args.one("view") ?? "interface")
    else { throw DistillerError(.usage, "Invalid view, format or documentation style") }
    switch try position(0) {
    case "configuration": try emit(try await toolchain().configuration)
    case "collect":
      let tools = try await toolchain()
      let collector = InterfaceCollector(runner: runner)
      let mode = try position(1)
      let input = try position(2)
      let cache = args.one("cache").map(file)
      let result: CollectionResult
      switch mode {
      case "package":
        result = try await collector.package(
          at: file(input), toolchain: tools, scope: scope,
          dependencyModules: args.many("dependency-module"), cache: cache)
      case "module":
        guard let producer = args.one("built-with") else {
          throw DistillerError(.usage, "Binary module collection requires --built-with")
        }
        let builtWith = try JSONDecoder().decode(
          BuildConfiguration.self, from: Data(contentsOf: file(producer)))
        result = try await collector.module(
          input, searchPaths: args.many("search-path").map(file), toolchain: tools,
          builtWith: builtWith, scope: scope,
          cache: cache ?? cwd.appendingPathComponent(".build/interface-distiller-module"))
      case "headers":
        let root = args.one("source-root").map(file) ?? cwd
        result = try await collector.headers(
          args.many("header").map(file), module: input, language: args.one("language") ?? "c",
          toolchain: tools, sourceRoot: root, scope: scope,
          cache: cache ?? root.appendingPathComponent(".build/interface-distiller-headers"))
      default: throw DistillerError(.usage, "Unknown collection mode")
      }
      if let path = args.one("report") { try CanonicalJSON.write(result.report, to: file(path)) }
      try emit(result.snapshot)
    case "normalize":
      guard let configuration = args.one("configuration"), args.positionals.count > 1 else {
        throw DistillerError(.usage, "Normalization requires graphs and their --configuration")
      }
      let config = try JSONDecoder().decode(
        BuildConfiguration.self, from: Data(contentsOf: file(configuration)))
      let graphs = try args.positionals.dropFirst().flatMap {
        try SymbolGraphInput.load(
          file($0), sourceRoot: args.one("source-root").map(file),
          languageView: args.one("language") ?? "swift")
      }
      try emit(
        SymbolGraphNormalizer.normalize(
          graphs, configuration: config, scope: scope, expectedModules: args.many("module")))
    case "merge":
      guard args.positionals.count > 1 else {
        throw DistillerError(.usage, "Merge requires snapshots")
      }
      try emit(
        EvidenceSnapshot.merge(
          args.positionals.dropFirst().map { try EvidenceSnapshot.read(file($0)) }))
    case "render":
      let snapshot = try EvidenceSnapshot.read(file(position(1)))
      let parts = try MarkdownRenderer.render(
        snapshot, byteBudget: args.integer("byte-budget"), view: view, docs: docs)
      if let directory = args.one("output-dir") {
        let root = file(directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for part in parts {
          try Data(part.markdown.utf8).write(
            to: root.appendingPathComponent(part.name), options: .atomic)
        }
        try emit(parts.map { ["name": $0.name, "bytes": String($0.markdown.utf8.count)] })
      } else {
        try emit(parts)
      }
    case "query", "slice":
      let query = try SnapshotQuery(
        EvidenceSnapshot.read(file(position(1))), configuration: args.one("configuration-id"))
      let sliceCommand = args.positionals[0] == "slice"
      let kind = try sliceCommand ? "slice" : position(2)
      let selectorIndex = sliceCommand ? 2 : 3
      let selector = try position(selectorIndex)
      let maximumSymbols = try args.integer("max-symbols")
      let maximumBytes = try args.integer("max-bytes")
      func write(_ result: SliceResult) throws {
        let data = try query.encode(result, format: format, docs: docs)
        if let output = args.one("output") {
          try data.write(to: file(output), options: .atomic)
        } else {
          FileHandle.standardOutput.write(data)
        }
      }
      func show(_ result: QueryResult) throws {
        if format == .json && maximumSymbols == nil && maximumBytes == nil {
          try emit(result)
        } else {
          try write(
            query.bounded(
              result, maximumSymbols: maximumSymbols, maximumBytes: maximumBytes, format: format,
              docs: docs))
        }
      }
      switch kind {
      case "lookup": try show(query.lookup(selector))
      case "members": try show(query.members(of: selector))
      case "conformers": try show(query.observedConformers(to: selector))
      case "initializers": try show(query.initializers(of: selector))
      case "returning": try show(query.returning(selector))
      case "slice":
        try write(
          query.slice(
            roots: Array(args.positionals.dropFirst(selectorIndex)),
            maximumSymbols: maximumSymbols, maximumBytes: maximumBytes, format: format, docs: docs))
      default: throw DistillerError(.usage, "Unknown query kind")
      }
    case "compare":
      let difference = try SnapshotComparator.compare(
        EvidenceSnapshot.read(file(position(1))), EvidenceSnapshot.read(file(position(2))))
      try emit(difference)
      return difference.equal ? 0 : 1
    case "baseline":
      let mode = try position(1)
      let snapshot = try EvidenceSnapshot.read(file(position(2)))
      let target = try file(position(3))
      if mode == "write" {
        try BaselineStore.write(snapshot, to: target)
        try emit(["snapshot": try snapshot.identity(), "written": "true"])
      } else if mode == "check" {
        let diff = try BaselineStore.check(snapshot, against: target)
        try emit(diff)
        return diff.equal ? 0 : 1
      } else {
        throw DistillerError(.usage, "Unknown baseline mode")
      }
    case "coverage":
      try emit(
        EvidenceSnapshot.read(file(position(1))).configurations.map(DocumentationCoverage.measure))
    case "diagnose":
      let cache =
        args.one("cache").map(file)
        ?? cwd.appendingPathComponent(".build/interface-distiller-diagnostics")
      try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
      if try position(1) == "package" {
        guard let revision = args.one("baseline-ref") else {
          throw DistillerError(.usage, "Package diagnostics require --baseline-ref")
        }
        try emit(
          try await CompilerDiagnostics.package(
            root: file(position(2)), baselineRevision: revision, toolchain: toolchain(),
            cache: cache, runner: runner))
      } else if try position(1) == "digester" {
        guard let baseline = args.one("baseline"), let candidate = args.one("candidate") else {
          throw DistillerError(.usage, "Digester diagnostics require baseline and candidate")
        }
        try emit(
          try await CompilerDiagnostics.digester(
            baseline: file(baseline), candidate: file(candidate),
            executable: args.one("digester") ?? "swift-api-digester", cache: cache, runner: runner))
      } else {
        throw DistillerError(.usage, "Unknown diagnostic mode")
      }
    default: throw DistillerError(.usage, "Unknown command")
    }
    return 0
  }
}

private struct Arguments {
  let positionals: [String]
  let options: [String: [String]]
  static let switches: Set<String> = ["include-spi", "source-locations"]
  static let repeated: Set<String> = [
    "module", "include", "exclude", "dependency-module", "search-path", "header",
  ]
  static let valued: Set<String> = [
    "output", "configuration", "source-root", "cache", "report", "timeout", "swift", "clang",
    "sdk-path",
    "configuration-id", "max-symbols", "max-bytes", "byte-budget", "output-dir", "built-with",
    "language", "baseline-ref", "baseline", "candidate", "digester", "view", "docs", "format",
  ]

  init(_ args: [String]) throws {
    var positionals: [String] = []
    var options: [String: [String]] = [:]
    var index = 0
    while index < args.count {
      let value = args[index]
      index += 1
      if value == "--" {
        positionals += args[index...]
        break
      }
      if !value.hasPrefix("--") {
        positionals.append(value)
        continue
      }
      let key = String(value.dropFirst(2))
      guard Self.switches.contains(key) || Self.repeated.contains(key) || Self.valued.contains(key)
      else {
        throw DistillerError(.usage, "Unknown option", context: ["option": value])
      }
      if !Self.repeated.contains(key), options[key] != nil {
        throw DistillerError(.usage, "Option supplied more than once", context: ["option": value])
      }
      if Self.switches.contains(key) {
        options[key] = ["true"]
      } else {
        guard index < args.count else {
          throw DistillerError(.usage, "Missing option value", context: ["option": value])
        }
        options[key, default: []].append(args[index])
        index += 1
      }
    }
    self.positionals = positionals
    self.options = options
  }
  func one(_ key: String) -> String? { options[key]?.first }
  func many(_ key: String) -> [String] { options[key] ?? [] }
  func flag(_ key: String) -> Bool { options[key] != nil }
  func integer(_ key: String) throws -> Int? {
    guard let raw = one(key) else { return nil }
    guard let number = Int(raw), number > 0 else {
      throw DistillerError(.usage, "Expected a positive integer", context: ["option": key])
    }
    return number
  }
  func double(_ key: String) throws -> Double? {
    guard let raw = one(key) else { return nil }
    guard let number = Double(raw), number.isFinite, number > 0 else {
      throw DistillerError(.usage, "Expected a positive duration", context: ["option": key])
    }
    return number
  }
}
