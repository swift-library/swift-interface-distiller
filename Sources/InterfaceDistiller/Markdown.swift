import Foundation

public struct MarkdownPart: Codable, Sendable {
  public var name: String
  public var markdown: String
}

public enum MarkdownRenderer {
  public static func anchor(configuration: String, symbol: String) -> String {
    "symbol-" + Digest.sha256(Data((configuration + ":" + symbol).utf8))
  }

  /// A budget is strict. An indivisible declaration exceeding it produces a machine-readable error.
  public static func render(_ snapshot: EvidenceSnapshot, byteBudget: Int? = nil) throws
    -> [MarkdownPart]
  {
    try snapshot.validate()
    if let byteBudget, byteBudget < 256 {
      throw DistillerError(.usage, "Markdown budget must be at least 256 bytes")
    }
    let header = "# Interface evidence\n\nSnapshot: `\(try snapshot.identity())`\n\n"
    var blocks: [(String, String)] = []
    var symbolBlocks: [String: (SymbolRecord, ConfigurationEvidence)] = [:]
    for configuration in snapshot.configurations {
      let configText = String(
        decoding: try CanonicalJSON.encode(configuration.configuration), as: UTF8.self
      ).trimmingCharacters(in: .newlines)
      let scopeText = String(decoding: try CanonicalJSON.encode(configuration.scope), as: UTF8.self)
        .trimmingCharacters(in: .newlines)
      blocks.append(
        (
          "configuration:" + configuration.id,
          "## Configuration `\(configuration.id)`\n\n    \(configText)\n\nScope:\n\n    \(scopeText)\n\nExpected modules: \(configuration.expectedModules.map(escape).joined(separator: ", ")).  \nCollected modules: \(configuration.collectedModules.map(escape).joined(separator: ", ")).\n\n"
        ))
      for symbol in configuration.symbols {
        let key = configuration.id + ":" + symbol.id
        blocks.append(
          (key, block(symbol, configuration: configuration, destination: { _ in "part-000001.md" }))
        )
        symbolBlocks[key] = (symbol, configuration)
      }
      for (index, gap) in configuration.gaps.enumerated() {
        blocks.append(
          (
            "gap:\(configuration.id):\(index)",
            "### Collection observation: \(gap.state.rawValue)\n\n\(escape(gap.subject))\n\n\(escape(gap.reason))\n\n"
          ))
      }
      for (index, merge) in configuration.merges.enumerated() {
        blocks.append(
          (
            "merge:\(configuration.id):\(index)",
            "### Merge observation: \(merge.kind)\n\n\(escape(merge.subject))\n\n\(merge.variants.count) retained variants; source graphs: \(merge.sources.joined(separator: ", ")). See canonical JSON for variant fields.\n\n"
          ))
      }
    }
    // Explicit, fixed-width part names keep link byte accounting independent of placement.
    var destinations: [String: String] = [:]
    var index = 1
    var currentBytes = header.utf8.count
    for (key, text) in blocks {
      if let budget = byteBudget, text.utf8.count + header.utf8.count > budget {
        throw DistillerError(
          .usage, "An evidence block exceeds the Markdown byte budget",
          context: ["subject": key, "minimumBytes": String(text.utf8.count + header.utf8.count)])
      }
      if let budget = byteBudget, currentBytes + text.utf8.count > budget {
        index += 1
        currentBytes = header.utf8.count
      }
      guard index <= 999999 else {
        throw DistillerError(.usage, "Markdown requires more than 999999 parts")
      }
      destinations[key] = String(format: "part-%06d.md", index)
      currentBytes += text.utf8.count
    }
    var parts: [String: String] = [:]
    for (key, text) in blocks {
      let content: String
      if let (symbol, configuration) = symbolBlocks[key] {
        content = block(
          symbol, configuration: configuration,
          destination: { id in destinations[configuration.id + ":" + id] ?? "part-000001.md" })
      } else {
        content = text
      }
      parts[destinations[key] ?? "part-000001.md", default: header] += content
    }
    if parts.isEmpty { parts["part-000001.md"] = header + "No configurations were collected.\n" }
    return parts.sorted { $0.key < $1.key }.map { MarkdownPart(name: $0.key, markdown: $0.value) }
  }

  private static func block(
    _ symbol: SymbolRecord, configuration: ConfigurationEvidence,
    destination: (String) -> String
  ) -> String {
    let anchor = anchor(configuration: configuration.id, symbol: symbol.id)
    let declaration =
      symbol.fields["declarationFragments"]?.value.array.compactMap { $0["spelling"].string }
      .joined() ?? ""
    let docs =
      symbol.fields["docComment"]?.value["lines"].array.compactMap { $0["text"].string }.joined(
        separator: "\n") ?? ""
    var text = "<a id=\"\(anchor)\"></a>\n\n## \(escape(symbol.module)).\(escape(symbol.name))\n\n"
    text +=
      "Configuration: `\(configuration.id)`  \nCompiler identifier: `\(symbol.preciseIdentifier)`\n\n"
    // Indented code preserves arbitrary declaration text, including backtick operators.
    text +=
      declaration.components(separatedBy: "\n").map { "    " + $0 }.joined(separator: "\n") + "\n\n"
    if !docs.isEmpty { text += docs + "\n\n" }
    let references = configuration.symbols.filter {
      symbol.references.contains($0.preciseIdentifier)
    }
    if !references.isEmpty {
      text +=
        "References: "
        + references.map {
          "[\(escape($0.name))](\(destination($0.id))#\(self.anchor(configuration: configuration.id, symbol: $0.id)))"
        }.joined(separator: ", ") + "\n\n"
    }
    return text
  }

  private static func escape(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "[", with: "\\[")
      .replacingOccurrences(of: "]", with: "\\]").replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}
