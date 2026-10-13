// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import InterfaceDistiller

@Test func macroDeclarationsAndDefaultImplementationsAreCompilerEvidence() async throws {
  let root = try testDirectory("macro-declarations")
  try writeExample(to: root)
  let source = root.appendingPathComponent("Sources/EvidenceExample/Example.swift")
  var text = try String(contentsOf: source, encoding: .utf8)
  text += """

    public protocol ValueProvider { func value() -> Int }
    extension ValueProvider { public func value() -> Int { 0 } }
    @freestanding(expression)
    public macro answer() -> Int = #externalMacro(module: "FixtureMacros", type: "Answer")
    """
  try text.write(to: source, atomically: true, encoding: .utf8)
  let toolchain = try await Toolchain.discover(directory: root)
  let result = try await InterfaceCollector().package(at: root, toolchain: toolchain)
  let evidence = result.snapshot.configurations[0]
  #expect(
    evidence.symbols.contains { $0.fields["kind"]?.value["identifier"].string == "swift.macro" })
  #expect(evidence.relationships.contains { $0.kind == "defaultImplementationOf" })
  #expect(evidence.relationships.contains { $0.kind == "requirementOf" })
  #expect(
    evidence.symbols.contains {
      $0.fields["swiftGenerics"]?.value["constraints"].array.isEmpty == false
    })
}

@Test func compilerPackageDiagnosticsStaySeparateFromSnapshots() async throws {
  let root = try testDirectory("package-diagnostics")
  try writeExample(to: root)
  let runner = ProcessRunner()
  for arguments in [
    ["init", "--initial-branch=master"], ["add", "Package.swift", "Sources"],
    [
      "-c", "user.name=Fixture", "-c", "user.email=fixture@example.org", "-c",
      "commit.gpgsign=false", "commit", "-m", "feat: provide fixture",
    ],
  ] { _ = try await runner.checked("git", arguments, directory: root) }
  let revisionOutput = try await runner.checked("git", ["rev-parse", "HEAD"], directory: root)
  let revision = String(decoding: revisionOutput.stdout, as: UTF8.self).trimmingCharacters(
    in: .whitespacesAndNewlines)
  let source = root.appendingPathComponent("Sources/EvidenceExample/Example.swift")
  let before = try String(contentsOf: source, encoding: .utf8)
  let after = before.replacingOccurrences(
    of: "public static func make()", with: "static func make()")
  try after.write(to: source, atomically: true, encoding: .utf8)
  let tools = try await Toolchain.discover(directory: root)
  let diagnostics = try await CompilerDiagnostics.package(
    root: root, baselineRevision: revision, toolchain: tools,
    cache: root.appendingPathComponent(".build/diagnostics"))
  #expect(diagnostics.producer == "swift package diagnose-api-breaking-changes")
  #expect((diagnostics.stdout + diagnostics.stderr).contains("make"))
  #expect(!diagnostics.stdout.contains(root.path))
  #expect(!diagnostics.stderr.contains(root.path))
  let dump = root.appendingPathComponent(
    ".build/diagnostics/baseline/" + revision + "/EvidenceExample.json")
  #if os(macOS)
    let located = try await runner.checked(
      "/usr/bin/xcrun", ["--find", "swift-api-digester"], directory: root)
    let executable = String(decoding: located.stdout, as: UTF8.self).trimmingCharacters(
      in: .whitespacesAndNewlines)
  #else
    let executable = "swift-api-digester"
  #endif
  let identical = try await CompilerDiagnostics.digester(
    baseline: dump, candidate: dump, executable: executable,
    cache: root.appendingPathComponent(".build/diagnostics"))
  #expect(identical.status == 0)
  #expect(identical.baseline == identical.candidate)
}
