// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import InterfaceDistiller

let configuration = BuildConfiguration(
  toolchain: "consumer example", sdk: "none", triple: "none", deploymentTarget: "none")
let graph = JSONValue.object([
  "metadata": .object([
    "formatVersion": .object(["major": .number(0), "minor": .number(6), "patch": .number(0)]),
    "generator": .string("consumer example"),
  ]),
  "module": .object(["name": .string("Example")]),
  "symbols": .array([]),
  "relationships": .array([]),
])
let snapshot = try SymbolGraphNormalizer.normalize(
  [.init(value: graph)], configuration: configuration, expectedModules: ["Example"])
let query = try SnapshotQuery(snapshot)
precondition(query.lookup("missing").symbols.isEmpty)
precondition(DocumentationCoverage.measure(query.evidence).eligible == 0)
FileHandle.standardOutput.write(try CanonicalJSON.encode(snapshot))
