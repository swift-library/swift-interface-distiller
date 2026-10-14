// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

/// UTF-8 byte accounting for a declaration in an unsplit Markdown interface.
public struct InterfaceSymbolSize: Codable, Sendable {
  public var configuration: String
  public var symbol: String
  public var module: String
  public var kind: String
  /// A standard requirement stated by an observed conformance, independent of implementation origin.
  public var impliedBy: String?
  public var indentation: Int
  public var declarationBytes: Int
  public var documentationBytes: Int
  public var anchorBytes: Int
}

/// Per-symbol accounting plus header, fences, headings and blank-line overhead.
public struct InterfaceSizeReport: Codable, Sendable {
  public var totalBytes: Int
  public var overheadBytes: Int
  public var symbols: [InterfaceSymbolSize]
}

final class InterfaceAccounting {
  var symbols: [String: InterfaceSymbolSize] = [:]
  let configuration: String
  let implied: [String: String]

  init(configuration: String, implied: [String: String]) {
    self.configuration = configuration
    self.implied = implied
  }

  func add(
    _ symbol: SymbolRecord, declaration: Int = 0, documentation: Int = 0,
    anchor: Int = 0, indentation: Int = 0
  ) {
    var size =
      symbols[symbol.id]
      ?? InterfaceSymbolSize(
        configuration: configuration, symbol: symbol.id, module: symbol.module,
        kind: symbol.fields["kind"]?.value["identifier"].string ?? "unknown",
        impliedBy: implied[symbol.id], indentation: indentation,
        declarationBytes: 0, documentationBytes: 0, anchorBytes: 0)
    size.declarationBytes += declaration
    size.documentationBytes += documentation
    size.anchorBytes += anchor
    symbols[symbol.id] = size
  }
}
