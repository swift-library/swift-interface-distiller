// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu and the swift-library project authors

extension VersionRequirement {
  /// A malformed requirement expression, with zero-based whitespace/operator token indexes.
  public enum ParseError: Error, Equatable, Sendable {
    case emptyInput
    case nonASCII
    case unexpectedToken(index: Int, value: String)
    case missingVersion(index: Int)
    case invalidOperator(index: Int, value: String)
    case invalidVersion(index: Int, error: Version.ParseError)
  }
}

extension VersionRequirement: LosslessStringConvertible {
  /// Parses comparisons, caret or tilde bounds, *, conjunctions and alternatives.
  ///
  /// Versions must use complete SemVer syntax. Whitespace or && joins comparisons;
  /// || separates alternatives. Operators may be attached to or separated from a version.
  public init?(_ requirement: String) {
    do {
      try self.init(parsing: requirement)
    } catch {
      return nil
    }
  }

  /// Parses a requirement, reporting syntax errors or the underlying invalid version.
  public init(parsing requirement: String) throws(ParseError) {
    let tokens = try Self.tokenize(requirement)
    guard !tokens.isEmpty else { throw .emptyInput }
    if tokens == ["empty"] {
      self = .empty
      return
    }
    var alternatives: [[Comparator]] = []
    var comparisons: [Comparator] = []
    var hasTerm = false
    var needsTerm = false
    var index = 0
    while index < tokens.count {
      let token = tokens[index]
      if token == "||" || token == "&&" {
        guard hasTerm && !needsTerm else {
          throw .unexpectedToken(index: index, value: token)
        }
        if token == "||" {
          alternatives.append(comparisons)
          comparisons = []
          hasTerm = false
        }
        needsTerm = true
        index += 1
        continue
      }
      if token == "*" {
        hasTerm = true
        needsTerm = false
        index += 1
        continue
      }

      let comparisonIndex = index
      let prefix = String(token.prefix { "<>=^~!".contains($0) })
      let operation = prefix.isEmpty ? "=" : prefix
      let comparison: (Version) -> Comparator
      switch operation {
      case "=", "==": comparison = Comparator.exact
      case ">=": comparison = Comparator.atLeast
      case ">": comparison = Comparator.greaterThan
      case "<=": comparison = Comparator.atMost
      case "<": comparison = Comparator.lessThan
      case "^": comparison = Comparator.compatibleWith
      case "~": comparison = Comparator.upToNextMinor
      default: throw .invalidOperator(index: index, value: prefix)
      }
      var versionText = String(token.dropFirst(prefix.count))
      if versionText.isEmpty {
        index += 1
        guard index < tokens.count, tokens[index] != "&&", tokens[index] != "||" else {
          throw .missingVersion(index: comparisonIndex)
        }
        versionText = tokens[index]
      }
      let version: Version
      do {
        version = try Version(parsing: versionText)
      } catch {
        throw .invalidVersion(index: index, error: error)
      }
      comparisons.append(comparison(version))
      hasTerm = true
      needsTerm = false
      index += 1
    }
    guard hasTerm && !needsTerm else {
      throw .unexpectedToken(index: tokens.count, value: "<end>")
    }
    alternatives.append(comparisons)
    self.init(any: alternatives)
  }

  /// A canonical expression, with && between comparisons and || between alternatives.
  public var description: String {
    if alternatives.isEmpty { return "empty" }
    return alternatives.map { comparisons in
      comparisons.isEmpty ? "*" : comparisons.map(\.description).joined(separator: " && ")
    }.joined(separator: " || ")
  }

  private static func tokenize(_ text: String) throws(ParseError) -> [String] {
    guard text.allSatisfy(\.isASCII) else { throw .nonASCII }
    let characters = Array(text)
    var tokens: [String] = []
    var index = 0
    while index < characters.count {
      let character = characters[index]
      if character.isWhitespace {
        index += 1
        continue
      }
      if character == "&" || character == "|" {
        guard index + 1 < characters.count, characters[index + 1] == character else {
          throw .unexpectedToken(index: tokens.count, value: String(character))
        }
        tokens.append(String([character, character]))
        index += 2
        continue
      }
      let start = index
      while index < characters.count, !characters[index].isWhitespace,
        characters[index] != "&", characters[index] != "|"
      {
        index += 1
      }
      tokens.append(String(characters[start..<index]))
    }
    return tokens
  }
}

extension VersionRequirement: Codable {
  /// Encodes the canonical requirement expression as a string.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  /// Decodes a requirement string, preserving parsing diagnostics on failure.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    do {
      self = try Self(parsing: text)
    } catch {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: container.codingPath, debugDescription: error.description,
          underlyingError: error))
    }
  }
}

extension VersionRequirement.ParseError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .emptyInput:
      return "A version requirement cannot be empty."
    case .nonASCII:
      return "A version requirement must contain only ASCII characters."
    case .unexpectedToken(let index, let value):
      return "Unexpected requirement token '\(value)' at index \(index)."
    case .missingVersion(let index):
      return "The comparison at token index \(index) needs a version."
    case .invalidOperator(let index, let value):
      return "Invalid comparison operator '\(value)' at token index \(index)."
    case .invalidVersion(let index, let error):
      return "Invalid version at token index \(index): \(error)"
    }
  }
}
