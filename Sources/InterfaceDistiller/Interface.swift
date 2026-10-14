// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

/// Documentation included in a readable view. Summary keeps the first prose paragraph.
public enum DocumentationStyle: String, Sendable { case summary, full, none }

/// Output encodings for snapshot queries. JSON preserves the evidence contract.
public enum QueryFormat: String, Sendable { case json, swift, markdown }

/// Projects compiler observations into a readable interface without changing evidence.
public enum InterfaceRenderer {
  /// Link destinations for every symbol. Members share their containing top-level block's anchor.
  /// Colliding top-level paths add an identity digest.
  public static func anchors(in snapshot: EvidenceSnapshot) -> [String: String] {
    var groups: [String: [String]] = [:]
    var owners: [String: String] = [:]
    for c in snapshot.configurations {
      let blockOwners = InterfaceProjection(
        evidence: c, docs: .none, showImplied: true, implied: [:]
      ).blockOwners()
      for (symbol, owner) in blockOwners {
        owners[c.id + ":" + symbol] = c.id + ":" + owner
      }
      for s in c.symbols where blockOwners[s.id] == s.id {
        let path = s.fields["pathComponents"]?.value.strings ?? [s.name]
        var components = Array(path.suffix(2)).map { component in
          slug(String(component.prefix { $0 != "(" }))
        }
        if components.first == slug(s.module) { components.removeFirst() }
        let base = ([slug(s.module)] + components).joined(separator: "-")
        groups[base, default: []].append(c.id + ":" + s.id)
      }
    }
    var result: [String: String] = [:]
    for (base, group) in groups {
      let keys = Array(Set(group)).sorted()
      if keys.count == 1 {
        result[keys[0]] = base
        continue
      }
      let symbols = Dictionary(grouping: keys, by: { String($0.dropFirst(65)) })
      let digests = Dictionary(
        uniqueKeysWithValues: keys.map { key in
          let symbol = String(key.dropFirst(65))
          return (key, Digest.sha256(Data(((symbols[symbol]?.count ?? 0) > 1 ? key : symbol).utf8)))
        })
      var counts: [Int: [String: Int]] = [:]
      for key in keys {
        let digest = digests[key]!
        var length = 8
        while true {
          if counts[length] == nil {
            counts[length] = Dictionary(grouping: digests.values, by: { String($0.prefix(length)) })
              .mapValues(\.count)
          }
          let suffix = String(digest.prefix(length))
          if groups[base + "-" + suffix] == nil && counts[length]?[suffix] == 1 {
            result[key] = base + "-" + suffix
            break
          }
          length += 1
        }
      }
    }
    return owners.mapValues { result[$0]! }
  }

  public static func render(
    _ snapshot: EvidenceSnapshot, byteBudget: Int? = nil, docs: DocumentationStyle = .summary,
    showImplied: Bool = false
  ) throws -> [MarkdownPart] {
    try snapshot.validate()
    guard byteBudget.map({ $0 > 0 }) ?? true else {
      throw DistillerError(.usage, "Interface budget must be positive")
    }
    let header = header(snapshot, docs: docs, showImplied: showImplied)
    let blocks = blocks(snapshot, docs: docs, showImplied: showImplied)
    return try paginate(blocks, header: header, byteBudget: byteBudget)
  }

  private static func blocks(
    _ snapshot: EvidenceSnapshot, docs: DocumentationStyle, showImplied: Bool
  ) -> [InterfaceBlock] {
    let anchors = anchors(in: snapshot)
    return snapshot.configurations.sorted { $0.id < $1.id }.flatMap {
      let configuration = $0
      return InterfaceProjection(evidence: configuration, docs: docs, showImplied: showImplied)
        .blocks(
          anchors: anchors, markdown: true
        ).map { block in
          guard snapshot.configurations.count > 1 else { return block }
          var block = block
          block.heading =
            block.heading.trimmingCharacters(in: .newlines) + " · " + configuration.id.prefix(12)
            + "\n\n"
          return block
        }
    }
  }

  private static func paginate(
    _ blocks: [InterfaceBlock], header: String, byteBudget: Int?
  ) throws -> [MarkdownPart] {
    var parts: [MarkdownPart] = []
    var current = header
    var section = ""
    for block in blocks {
      let minimum = header.utf8.count + block.heading.utf8.count + block.content.utf8.count
      if let budget = byteBudget, minimum > budget {
        throw DistillerError(
          .usage, "A top-level declaration exceeds the interface byte budget",
          context: ["minimumBytes": String(minimum)])
      }
      let addition = (section == block.heading ? "" : block.heading) + block.content
      if let budget = byteBudget, current.utf8.count + addition.utf8.count > budget {
        parts.append(MarkdownPart(name: partName(parts.count + 1), markdown: current))
        current = header
        section = ""
      }
      current += (section == block.heading ? "" : block.heading) + block.content
      section = block.heading
    }
    if let budget = byteBudget, current.utf8.count > budget {
      throw DistillerError(
        .usage, "Interface header exceeds the byte budget",
        context: ["minimumBytes": String(current.utf8.count)])
    }
    parts.append(MarkdownPart(name: partName(parts.count + 1), markdown: current))
    return parts
  }

  /// Measures the whole unsplit interface, including symbols collapsed by presentation policy.
  public static func measure(
    _ snapshot: EvidenceSnapshot, docs: DocumentationStyle = .summary, showImplied: Bool = false
  ) throws -> InterfaceSizeReport {
    try snapshot.validate()
    let blocks = blocks(snapshot, docs: docs, showImplied: showImplied)
    let total = try paginate(
      blocks, header: header(snapshot, docs: docs, showImplied: showImplied),
      byteBudget: nil
    ).reduce(0) { $0 + $1.markdown.utf8.count }
    var sizes = blocks.flatMap(\.sizes)
    let rendered = Set(sizes.map { $0.configuration + ":" + $0.symbol })
    for evidence in snapshot.configurations {
      let accounting = InterfaceAccounting(
        configuration: evidence.id,
        implied: ImpliedMembers.categories(in: evidence))
      for symbol in evidence.symbols where !rendered.contains(evidence.id + ":" + symbol.id) {
        accounting.add(symbol)
      }
      sizes += accounting.symbols.values
    }
    let symbolBytes = sizes.reduce(0) {
      $0 + $1.declarationBytes + $1.documentationBytes + $1.anchorBytes
    }
    return InterfaceSizeReport(
      totalBytes: total, overheadBytes: total - symbolBytes,
      symbols: sizes.sorted { ($0.configuration, $0.symbol) < ($1.configuration, $1.symbol) })
  }

  /// Splits by module and provides an index without pruning any selected declaration.
  public static func modules(
    _ snapshot: EvidenceSnapshot, byteBudget: Int? = nil, docs: DocumentationStyle = .summary,
    showImplied: Bool = false
  ) throws -> [MarkdownPart] {
    try snapshot.validate()
    guard byteBudget.map({ $0 > 0 }) ?? true else {
      throw DistillerError(.usage, "Interface budget must be positive")
    }
    let all = blocks(snapshot, docs: docs, showImplied: showImplied)
    let names = Set(
      snapshot.configurations.flatMap { $0.collectedModules + $0.symbols.map(\.module) }
    ).sorted()
    if names.isEmpty {
      return try render(snapshot, byteBudget: byteBudget, docs: docs, showImplied: showImplied)
    }
    let header = header(snapshot, docs: docs, showImplied: showImplied)
    var index =
      header
      + "| Module | Reported declarations | Interface bytes | Files |\n| --- | ---: | ---: | --- |\n"
    var output: [MarkdownPart] = []
    for name in names {
      var stem = slug(name)
      if names.filter({ slug($0) == stem }).count > 1 {
        stem += "-" + Digest.sha256(Data(name.utf8)).prefix(8)
      }
      let parts = try paginate(
        all.filter { $0.module == name }, header: header, byteBudget: byteBudget
      )
      .map { MarkdownPart(name: "module-" + stem + "-" + $0.name, markdown: $0.markdown) }
      let count = snapshot.configurations.flatMap(\.symbols).filter { $0.module == name }.count
      let links = parts.enumerated().map { "[\($0.offset + 1)](\($0.element.name))" }.joined(
        separator: ", ")
      index +=
        "| \(name) | \(count) | \(parts.reduce(0) { $0 + $1.markdown.utf8.count }) | \(links) |\n"
      output += parts
    }
    if let budget = byteBudget, index.utf8.count > budget {
      throw DistillerError(
        .usage, "Module index exceeds the interface byte budget",
        context: ["minimumBytes": String(index.utf8.count)])
    }
    return [MarkdownPart(name: "index.md", markdown: index)] + output
  }

  static func body(
    _ symbols: [SymbolRecord], evidence: ConfigurationEvidence, format: QueryFormat,
    docs: DocumentationStyle, showImplied: Bool = false
  ) throws -> String {
    var selected = evidence
    var included = Dictionary(uniqueKeysWithValues: symbols.map { ($0.id, $0) })
    let parents = DeclarationNesting.parents(in: evidence)
    let byPrecise = Dictionary(grouping: evidence.symbols, by: \.preciseIdentifier)
    var pending = symbols
    while let child = pending.popLast() {
      for precise in parents[child.id] ?? [] {
        for parent in byPrecise[precise] ?? []
        where parent.module == child.module && included[parent.id] == nil {
          included[parent.id] = parent
          pending.append(parent)
        }
      }
    }
    selected.symbols = Array(included.values)
    let snapshot = try EvidenceSnapshot(
      configurations: [evidence],
      schemaVersion: evidence.scope.includeSynthesized != nil && evidence.externalReferences != nil
        ? "2.0" : "1.0")
    var section = ""
    return InterfaceProjection(
      evidence: selected, docs: docs, showImplied: showImplied,
      implied: ImpliedMembers.categories(in: evidence), targets: evidence.symbols
    ).blocks(
      anchors: anchors(in: snapshot), markdown: format == .markdown
    ).map { block in
      let text = (section == block.heading ? "" : block.heading) + block.content
      section = block.heading
      return text
    }.joined()
  }

  static func header(
    _ snapshot: EvidenceSnapshot, docs: DocumentationStyle = .summary, showImplied: Bool = false
  ) -> String {
    let modules = Set(snapshot.configurations.flatMap(\.collectedModules)).sorted()
    var lines = ["# Swift interface", "", "Modules: " + modules.joined(separator: ", ")]
    let impliedCount = snapshot.configurations.reduce(0) {
      $0 + ImpliedMembers.categories(in: $1).count
    }
    lines.append(
      "View: \(docs.rawValue) docs; \(impliedCount) conformance-implied members "
        + (showImplied ? "expanded" : "collapsed"))
    for c in snapshot.configurations.sorted(by: { $0.id < $1.id }) {
      let scope = c.scope
      let selection =
        scope.modules.isEmpty ? "library products" : scope.modules.joined(separator: ", ")
      var scopeText = "public/open; " + selection + (scope.includeSPI ? "; SPI included" : "")
      if !scope.include.isEmpty {
        scopeText += "; include " + scope.include.sorted().joined(separator: ", ")
      }
      if !scope.exclude.isEmpty {
        scopeText += "; exclude " + scope.exclude.sorted().joined(separator: ", ")
      }
      if scope.sourceLocations { scopeText += "; source locations" }
      scopeText +=
        scope.includeSynthesized == false
        ? "; synthesized excluded by policy" : "; synthesized included"
      lines += [
        "Extractor: \(c.configuration.extractorVersion) · Configuration: \(c.id.prefix(12))",
        "Toolchain: " + oneLine(c.configuration.toolchain),
        "Scope: " + oneLine(scopeText),
        "Completeness: " + completeness(c),
      ]
    }
    return lines.joined(separator: "\n") + "\n\n"
  }

  private static func completeness(_ c: ConfigurationEvidence) -> String {
    let legacyExternalReasons: Set<String> = [
      "Relationship source was not collected", "Relationship target is outside collected symbols",
      "Referenced compiler identifier is outside collected symbols",
    ]
    let observations = c.gaps.filter {
      c.externalReferences != nil || !legacyExternalReasons.contains($0.reason)
    }
    var gaps = Dictionary(grouping: observations, by: { $0.state.rawValue }).sorted {
      $0.key < $1.key
    }
    .map { state, values in
      "\(values.count) \(state): "
        + Set(values.map { oneLine($0.reason) }).sorted().joined(separator: "; ")
    }
    let missing = Set(c.expectedModules).subtracting(c.collectedModules).sorted()
    if !missing.isEmpty { gaps.append("\(missing.count) missing modules") }
    let conflicts = c.merges.filter { $0.kind == "conflict" }.map(\.subject).sorted()
    if !conflicts.isEmpty { gaps.append("\(conflicts.count) conflicts") }
    let collected = Set(c.symbols.map(\.preciseIdentifier))
    let externalCount =
      c.externalReferences?.count
      ?? Set(
        c.symbols.flatMap(\.references) + c.relationships.flatMap { [$0.source, $0.target] }
      ).subtracting(collected).count
    return
      "\(c.collectedModules.count)/\(c.expectedModules.count) modules; \(c.symbols.count) declarations; \(externalCount) external references; "
      + (gaps.isEmpty ? "no recorded gaps" : gaps.joined(separator: "; "))
  }

  private static func partName(_ index: Int) -> String { String(format: "part-%06d.md", index) }
  static func oneLine(_ text: String) -> String {
    text.components(separatedBy: .newlines).joined(separator: " ")
  }
  private static func slug(_ text: String) -> String {
    let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
    return words.isEmpty ? "symbol" : words.joined(separator: "-")
  }
}

private struct InterfaceBlock {
  var module: String
  var heading: String
  var content: String
  var sizes: [InterfaceSymbolSize]
}

private struct InterfaceProjection {
  let evidence: ConfigurationEvidence
  let docs: DocumentationStyle
  let showImplied: Bool
  let implied: [String: String]
  let edgesBySource: [String: [Relationship]]
  let symbolsByPrecise: [String: [SymbolRecord]]
  let targetsByPrecise: [String: [SymbolRecord]]

  init(
    evidence: ConfigurationEvidence, docs: DocumentationStyle, showImplied: Bool,
    implied: [String: String]? = nil, targets: [SymbolRecord]? = nil
  ) {
    self.evidence = evidence
    self.docs = docs
    self.showImplied = showImplied
    self.implied = implied ?? ImpliedMembers.categories(in: evidence)
    self.edgesBySource = Dictionary(grouping: evidence.relationships, by: \.source)
    self.symbolsByPrecise = Dictionary(grouping: evidence.symbols, by: \.preciseIdentifier)
    self.targetsByPrecise = Dictionary(
      grouping: targets ?? evidence.symbols, by: \.preciseIdentifier)
  }

  private let containers: Set<String> = [
    "swift.struct", "swift.class", "swift.actor", "swift.enum", "swift.protocol", "swift.extension",
  ]

  private func kind(_ s: SymbolRecord) -> String {
    s.fields["kind"]?.value["identifier"].string ?? ""
  }
  private func path(_ s: SymbolRecord) -> String {
    (s.fields["pathComponents"]?.value.strings ?? [s.name]).joined(separator: ".")
  }
  private func order(_ a: SymbolRecord, _ b: SymbolRecord) -> Bool {
    (a.module, path(a), a.id) < (b.module, path(b), b.id)
  }

  private func parents() -> [String: String] {
    let symbols = evidence.symbols.sorted(by: order)
    let byPrecise = symbolsByPrecise
    var parent: [String: String] = [:]
    let ownership = DeclarationNesting.parents(in: evidence)
    for s in symbols {
      let candidates = (ownership[s.id] ?? []).flatMap { byPrecise[$0] ?? [] }.filter {
        $0.module == s.module && containers.contains(kind($0)) && $0.id != s.id
      }
      if let p = candidates.sorted(by: order).first { parent[s.id] = p.id }
    }
    // Malformed relationship cycles stay visible as roots rather than disappearing.
    for s in symbols {
      var visited: Set<String> = [s.id]
      var next = parent[s.id]
      while let id = next {
        if !visited.insert(id).inserted {
          parent.removeValue(forKey: s.id)
          break
        }
        next = parent[id]
      }
    }
    return parent
  }

  func blockOwners() -> [String: String] {
    let parent = parents()
    return Dictionary(
      uniqueKeysWithValues: evidence.symbols.map { symbol in
        var owner = symbol.id
        while let next = parent[owner] { owner = next }
        return (symbol.id, owner)
      })
  }

  func blocks(anchors: [String: String], markdown: Bool) -> [InterfaceBlock] {
    let symbols = evidence.symbols.filter { showImplied || implied[$0.id] == nil }.sorted(by: order)
    let parent = parents()
    let children = Dictionary(
      grouping: symbols.filter { parent[$0.id] != nil }, by: { parent[$0.id]! })
    let roots = symbols.filter { parent[$0.id] == nil }
    var result: [InterfaceBlock] = []
    for module in Set(roots.map(\.module)).sorted() {
      for external in [false, true] {
        let group = roots.filter { $0.module == module && isExternal($0) == external }
        for root in group {
          var extensions: [String] = []
          let accounting = InterfaceAccounting(configuration: evidence.id, implied: implied)
          let declaration = declarationTree(
            root, children: children, level: 0, extensions: &extensions, accounting: accounting)
          let source = declaration + extensions.joined()
          if markdown {
            let anchor = anchors[evidence.id + ":" + root.id]!
            let id = "<a id=\"\(anchor)\"></a>"
            accounting.add(root, anchor: id.utf8.count + 1)
            let heading = "## " + module + (external ? " — External extensions" : "") + "\n\n"
            // A fence longer than any reported run preserves arbitrary documentation and operators.
            let fence = String(repeating: "`", count: max(3, longestBackticks(source) + 1))
            result.append(
              InterfaceBlock(
                module: module, heading: heading,
                content: id + "\n\n" + fence + root.language + "\n" + source + fence + "\n\n",
                sizes: Array(accounting.symbols.values)))
          } else {
            result.append(
              InterfaceBlock(
                module: module,
                heading: "// Module: " + module + (external ? " — External extensions" : "") + "\n",
                content: source + "\n", sizes: Array(accounting.symbols.values)))
          }
        }
      }
    }
    return result
  }

  private func isExternal(_ s: SymbolRecord) -> Bool {
    guard kind(s) == "swift.extension" else { return false }
    return s.fields["swiftExtension"]?.value["extendedModule"].string != s.module
  }

  private func declarationTree(
    _ s: SymbolRecord, children: [String: [SymbolRecord]], level: Int,
    extensions deferred: inout [String], accounting: InterfaceAccounting
  )
    -> String
  {
    let indent = String(repeating: "  ", count: level)
    let docs = documentation(s)
    var lines = docs + availability(s)
    let docBytes = docs.flatMap { $0.components(separatedBy: "\n") }
      .map { indent + $0 + "\n" }.joined().utf8.count
    let declaration = declaration(s)
    guard containers.contains(kind(s)) else {
      lines.append(declaration)
      let text =
        lines.flatMap { $0.components(separatedBy: "\n") }.map { indent + $0 }.joined(
          separator: "\n") + "\n"
      accounting.add(
        s, declaration: text.utf8.count - docBytes, documentation: docBytes,
        indentation: indent.utf8.count)
      return text
    }
    lines.append(declaration + " {")
    var text = lines.map { indent + $0 }.joined(separator: "\n") + "\n"
    accounting.add(
      s, declaration: text.utf8.count - docBytes + (indent + "}\n").utf8.count,
      documentation: docBytes, indentation: indent.utf8.count)
    let all = children[s.id] ?? []
    let extensions = all.filter { needsExtension($0, parent: s) }
    for child in all where !needsExtension(child, parent: s) {
      text += declarationTree(
        child, children: children, level: level + 1, extensions: &deferred, accounting: accounting)
    }
    text += indent + "}\n"
    let grouped = Dictionary(
      grouping: extensions,
      by: { constraints($0.fields["swiftExtension"]?.value["constraints"] ?? .null) })
    for condition in grouped.keys.sorted() {
      var extensionText =
        "\nextension " + path(s) + (condition.isEmpty ? "" : " where " + condition) + " {\n"
      accounting.add(s, declaration: extensionText.utf8.count + "}\n".utf8.count)
      for child in grouped[condition] ?? [] {
        extensionText += declarationTree(
          child, children: children, level: 1, extensions: &deferred, accounting: accounting)
      }
      extensionText += "}\n"
      deferred.append(extensionText)
    }
    // Conditional conformances must not be promoted to unconditional inheritance.
    let conditional = conformanceEdges(s).filter {
      !constraints($0.fields["swiftConstraints"]?.value ?? .null).isEmpty
    }
    for edge in conditional {
      let text =
        "\nextension " + path(s) + ": " + targetName(edge) + " where "
        + constraints(edge.fields["swiftConstraints"]?.value ?? .null) + " {}\n"
      accounting.add(s, declaration: text.utf8.count)
      deferred.append(text)
    }
    return text
  }

  private func needsExtension(_ child: SymbolRecord, parent: SymbolRecord) -> Bool {
    let context = child.fields["swiftExtension"]?.value ?? .null
    return kind(parent) != "swift.extension"
      && (!constraints(context["constraints"]).isEmpty
        || (kind(parent) == "swift.protocol"
          && (context != .null
            || (edgesBySource[child.preciseIdentifier] ?? []).contains {
              $0.kind == "defaultImplementationOf"
            })))
  }

  private func declaration(_ s: SymbolRecord) -> String {
    let fragments = s.fields["declarationFragments"]?.value.array ?? []
    var text = fragments.compactMap { $0["spelling"].string }.joined()
    if text.isEmpty { return "// Declaration not collected: " + InterfaceRenderer.oneLine(s.name) }
    if s.language == "swift", kind(s) != "swift.extension", kind(s) != "swift.enum.case",
      let access = s.fields["accessLevel"]?.value.string,
      !fragments.contains(where: {
        $0["kind"].string == "keyword" && $0["spelling"].string == access
      })
    {
      let insertion = fragments.firstIndex { $0["kind"].string == "keyword" } ?? 0
      let prefix = fragments.prefix(insertion).compactMap { $0["spelling"].string }.joined()
      text =
        prefix + access + " "
        + fragments.dropFirst(insertion).compactMap { $0["spelling"].string }.joined()
    }
    if containers.contains(kind(s)) {
      let inherited = conformanceEdges(s).filter {
        constraints($0.fields["swiftConstraints"]?.value ?? .null).isEmpty
      }
      var reported: Set<String> = []
      var genericDepth = 0
      var inheritance = false
      for fragment in fragments {
        if fragment["kind"].string == "keyword", fragment["spelling"].string == "where" { break }
        if inheritance, let precise = fragment["preciseIdentifier"].string {
          reported.insert(precise)
        }
        for character in fragment["spelling"].string ?? "" {
          if character == "<" { genericDepth += 1 }
          if character == ">" { genericDepth -= 1 }
          if character == ":", genericDepth == 0 { inheritance = true }
        }
      }
      let names = Set(inherited.filter { !reported.contains($0.target) }.map(targetName)).sorted()
      if !names.isEmpty {
        let whereRange = text.range(of: " where ")
        var head = whereRange.map { String(text[..<$0.lowerBound]) } ?? text
        let tail = whereRange.map { String(text[$0.lowerBound...]) } ?? ""
        // Only a colon outside generic angle brackets introduces inheritance.
        var depth = 0
        var hasInheritance = false
        for char in head {
          if char == "<" { depth += 1 }
          if char == ">" { depth -= 1 }
          if char == ":" && depth == 0 { hasInheritance = true }
        }
        head += (hasInheritance ? ", " : ": ") + names.joined(separator: ", ")
        text = head + tail
      }
    }
    return text
  }

  private func conformanceEdges(_ s: SymbolRecord) -> [Relationship] {
    (edgesBySource[s.preciseIdentifier] ?? []).filter {
      ["conformsTo", "inheritsFrom"].contains($0.kind) && $0.source == s.preciseIdentifier
        && $0.module == s.module
        && ![
          "s:s8CopyableP", "s:s9EscapableP", "s:s16SendableMetatypeP",
        ].contains($0.target)
    }.sorted {
      ($0.target, constraints($0.fields["swiftConstraints"]?.value ?? .null)) < (
        $1.target, constraints($1.fields["swiftConstraints"]?.value ?? .null)
      )
    }
  }

  private func targetName(_ edge: Relationship) -> String {
    if let target = targetsByPrecise[edge.target]?.sorted(by: order).first {
      return path(target)
    }
    if let fallback = edge.fields["targetFallback"]?.value.string {
      return fallback.hasPrefix("Swift.") ? String(fallback.dropFirst(6)) : fallback
    }
    return "/* type name not reported */"
  }

  private func constraints(_ value: JSONValue) -> String {
    value.array.map { constraint in
      let relation = constraint["kind"].string == "sameType" ? " == " : ": "
      return (constraint["lhs"].string ?? "?") + relation + (constraint["rhs"].string ?? "?")
    }.sorted().joined(separator: ", ")
  }

  private func documentation(_ s: SymbolRecord) -> [String] {
    guard docs != .none else { return [] }
    var lines = s.fields["docComment"]?.value["lines"].array.compactMap { $0["text"].string } ?? []
    while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
      lines.removeFirst()
    }
    if docs == .summary {
      lines = Array(lines.prefix { !startsDocumentationBlock($0) })
    }
    return lines.map { "///" + ($0.isEmpty ? "" : " " + $0) }
  }

  private func startsDocumentationBlock(_ line: String) -> Bool {
    let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty || line.hasPrefix("    ") || line.hasPrefix("\t") { return true }
    return text.range(
      of: #"^(?:[-+*]\s|\d+[.)]\s|#{1,6}(?:\s|$)|>|`{3,}|~{3,}|(?:-{3,}|_{3,}|\*{3,})\s*$)"#,
      options: .regularExpression) != nil
  }

  private func availability(_ s: SymbolRecord) -> [String] {
    (s.fields["availability"]?.value.array ?? []).compactMap { item in
      var arguments = [item["domain"].string ?? "*"]
      for key in ["introduced", "deprecated", "obsoleted"] {
        let version = item[key]
        if version != .null {
          let numbers = ["major", "minor", "patch"].compactMap {
            versionNumber(version[$0])
          }
          if !numbers.isEmpty { arguments.append(key + ": " + numbers.joined(separator: ".")) }
        }
      }
      if item["isUnconditionallyDeprecated"] == .bool(true) { arguments.append("deprecated") }
      if item["isUnconditionallyUnavailable"] == .bool(true) { arguments.append("unavailable") }
      for key in ["renamed", "message"] {
        if let value = item[key].string {
          let quoted = String(
            decoding: (try? CanonicalJSON.encode(JSONValue.string(value))) ?? Data(), as: UTF8.self
          ).trimmingCharacters(in: .newlines)
          arguments.append(key + ": " + quoted)
        }
      }
      return arguments.count > 1 ? "@available(" + arguments.joined(separator: ", ") + ")" : nil
    }.sorted()
  }

  private func versionNumber(_ value: JSONValue) -> String? {
    guard case .number(let number) = value else { return nil }
    return NSDecimalNumber(decimal: number).stringValue
  }

  private func longestBackticks(_ text: String) -> Int {
    var longest = 0
    var current = 0
    for c in text {
      current = c == "`" ? current + 1 : 0
      longest = max(longest, current)
    }
    return longest
  }
}
