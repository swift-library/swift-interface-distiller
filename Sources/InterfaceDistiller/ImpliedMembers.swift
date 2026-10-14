// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

/// Presentation categories for standard requirements already stated by a conformance.
/// This does not identify a synthesized implementation or select a witness.
enum ImpliedMembers {
  static func categories(in evidence: ConfigurationEvidence) -> [String: String] {
    let parents = DeclarationNesting.parents(in: evidence)
    let symbols = Dictionary(grouping: evidence.symbols, by: \.preciseIdentifier)
    let conformances = Dictionary(
      grouping: evidence.relationships.filter { $0.kind == "conformsTo" }, by: \.source)
    let members = Dictionary(
      grouping: evidence.symbols.flatMap { symbol in
        (parents[symbol.id] ?? []).map { (parent: $0, symbol: symbol) }
      }, by: \.parent
    ).mapValues { $0.map(\.symbol) }
    var result: [String: String] = [:]
    for symbol in evidence.symbols where symbol.language == "swift" {
      for parentID in parents[symbol.id] ?? [] {
        for parent in symbols[parentID] ?? [] where parent.module == symbol.module {
          let kind = parent.fields["kind"]?.value["identifier"].string
          guard
            ["swift.struct", "swift.enum", "swift.class", "swift.actor", "swift.extension"]
              .contains(kind)
          else { continue }
          let requirements = (conformances[parentID] ?? []).filter { edge in
            guard edge.module == symbol.module else { return false }
            let memberConditions = symbol.fields["swiftExtension"]?.value["constraints"].array ?? []
            let conformanceConditions = edge.fields["swiftConstraints"]?.value.array ?? []
            return memberConditions.isEmpty || memberConditions == conformanceConditions
          }
          let protocols = Set(requirements.map(\.target))
          if let category = category(
            symbol, parent: parent, members: members[parentID] ?? [], protocols: protocols,
            unfiltered: evidence.scope.include.isEmpty && evidence.scope.exclude.isEmpty)
          {
            result[symbol.id] = category
          }
        }
      }
    }
    return result
  }

  private static func category(
    _ symbol: SymbolRecord, parent: SymbolRecord, members: [SymbolRecord], protocols: Set<String>,
    unfiltered: Bool
  ) -> String? {
    let kind = symbol.fields["kind"]?.value["identifier"].string ?? ""
    let signature = symbol.fields["functionSignature"]?.value ?? .null
    let parameters = signature["parameters"].array
    let fragments = symbol.fields["declarationFragments"]?.value.array ?? []
    let declaration = fragments.compactMap { $0["spelling"].string }.joined()
    // Method-generic overloads and additional requirements are not stated by the conformance.
    guard !declaration.contains(" where "), !declaration.contains(" async"),
      !declaration.contains("init<"), !declaration.contains("encode<"),
      !declaration.contains("hash<"), !declaration.contains("==<"),
      !fragments.contains(where: { $0["kind"].string == "attribute" }),
      !["nonisolated", "isolated"].contains(where: { declaration.contains($0) })
    else { return nil }
    let parameterTypes = parameters.map {
      SymbolGraphNormalizer.references(in: $0["declarationFragments"])
    }
    switch (kind, symbol.name) {
    case ("swift.init", "init(from:)"):
      if protocols.contains("s:Se"), parameterTypes == [["s:s7DecoderP"]],
        ["Decoder", "any Decoder"].contains(
          typeSpelling(parameters[0]["declarationFragments"]) ?? "")
      {
        return "Decodable"
      }
    case ("swift.method", "encode(to:)"):
      if protocols.contains("s:SE"), parameterTypes == [["s:s7EncoderP"]],
        returnsVoid(signature),
        ["Encoder", "any Encoder"].contains(
          typeSpelling(parameters[0]["declarationFragments"]) ?? "")
      {
        return "Encodable"
      }
    case ("swift.type.method", "==(_:_:)"), ("swift.func.op", "==(_:_:)"):
      let returns = SymbolGraphNormalizer.references(in: signature["returns"])
      if !protocols.isDisjoint(with: ["s:SQ", "s:SH"]), parameters.count == 2,
        returns == ["s:Sb"],
        parameters.allSatisfy({ parameter in
          let types = parameter["declarationFragments"].array.filter {
            $0["kind"].string == "typeIdentifier"
          }
          let type = typeSpelling(parameter["declarationFragments"]) ?? ""
          let path =
            parent.fields["pathComponents"]?.value.strings.joined(separator: ".") ?? parent.name
          return types.count == 1
            && ["Self", parent.name, path, parent.module + "." + path].contains(type)
            && (types[0]["preciseIdentifier"].string == parent.preciseIdentifier
              || types[0]["spelling"].string == "Self")
        })
      {
        return "Equatable"
      }
    case ("swift.method", "hash(into:)"):
      if protocols.contains("s:SH"), parameterTypes == [["s:s6HasherV"]],
        returnsVoid(signature),
        typeSpelling(parameters[0]["declarationFragments"]) == "Hasher",
        declaration.contains("inout Hasher)")
      {
        return "Hashable"
      }
    case ("swift.property", "hashValue"):
      if protocols.contains("s:SH"),
        SymbolGraphNormalizer.references(in: symbol.fields["declarationFragments"]?.value ?? .null)
          == ["s:Si"]
      {
        return "Hashable"
      }
    case ("swift.init", "init(rawValue:)"):
      if protocols.contains("s:SY"), parameters.count == 1 {
        let parameterType = typeSpelling(parameters[0]["declarationFragments"])
        var rawTypes = Set(
          members.filter { $0.name == "rawValue" }.compactMap {
            typeSpelling($0.fields["declarationFragments"]?.value ?? .null)
          })
        if parent.fields["kind"]?.value["identifier"].string == "swift.enum" {
          var depth = 0
          var inheritance = false
          for fragment in parent.fields["declarationFragments"]?.value.array ?? [] {
            if fragment["kind"].string == "keyword", fragment["spelling"].string == "where" {
              break
            }
            if inheritance, fragment["kind"].string == "typeIdentifier",
              let raw = fragment["spelling"].string
            {
              rawTypes.insert(raw)
              break
            }
            for character in fragment["spelling"].string ?? "" {
              if character == "<" { depth += 1 }
              if character == ">" { depth -= 1 }
              if character == ":", depth == 0 { inheritance = true }
            }
          }
          let initializers = members.filter { $0.name == "init(rawValue:)" }
          if unfiltered, rawTypes.isEmpty, initializers.count == 1, declaration.contains("init?("),
            let parameterType
          {
            rawTypes.insert(parameterType)
          }
        }
        if let parameterType, rawTypes.contains(parameterType) { return "RawRepresentable" }
      }
    case ("swift.property", "rawValue"):
      if protocols.contains("s:SY") { return "RawRepresentable" }
    case ("swift.type.property", "allCases"):
      if protocols.contains("s:s12CaseIterableP") { return "CaseIterable" }
    default: break
    }
    return nil
  }

  private static func typeSpelling(_ value: JSONValue) -> String? {
    let text = value.array.compactMap { $0["spelling"].string }.joined()
    guard let colon = text.firstIndex(of: ":") else { return nil }
    return text[text.index(after: colon)...].components(separatedBy: " {").first?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func returnsVoid(_ signature: JSONValue) -> Bool {
    let text = signature["returns"].array.compactMap { $0["spelling"].string }.joined()
    return ["()", "Void", "Swift.Void"].contains(text)
  }
}
