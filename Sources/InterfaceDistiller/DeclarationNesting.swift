// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

/// Reported declaration ownership, including a protocol default's declaring path.
/// These paths identify extension context, not a selected conformance witness.
enum DeclarationNesting {
  static let kinds: Set<String> = ["memberOf", "requirementOf", "optionalRequirementOf"]

  static func parents(in evidence: ConfigurationEvidence) -> [String: [String]] {
    let edges = Dictionary(grouping: evidence.relationships, by: \.source)
    let protocols = Dictionary(
      grouping: evidence.symbols.filter {
        $0.fields["kind"]?.value["identifier"].string == "swift.protocol"
      }
    ) { [$0.module, $0.language] + ($0.fields["pathComponents"]?.value.strings ?? []) }
    var result: [String: [String]] = [:]
    for symbol in evidence.symbols {
      let outgoing = (edges[symbol.preciseIdentifier] ?? []).filter {
        $0.module == symbol.module && $0.language == symbol.language
      }
      var parents = Set(outgoing.filter { kinds.contains($0.kind) }.map(\.target))
      if outgoing.contains(where: { $0.kind == "defaultImplementationOf" }),
        let path = symbol.fields["pathComponents"]?.value.strings, !path.isEmpty
      {
        let owner = [symbol.module, symbol.language] + Array(path.dropLast())
        parents.formUnion((protocols[owner] ?? []).map(\.preciseIdentifier))
      }
      result[symbol.id] = parents.sorted()
    }
    return result
  }
}
