// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

/// A model with compiler-derived decoding support.
public struct Model: Codable {
  public var value: Int
  public init(value: Int) { self.value = value }
  public init(from value: Int) { self.value = value }
}

/// A raw enum with compiler-derived requirements.
public enum Mode: String, Codable, Hashable, CaseIterable {
  case first, second
}

/// Public declarations whose signatures are stated by standard conformances.
public struct Flags: Hashable, RawRepresentable, CaseIterable {
  public var rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(rawValue: Int) { self.rawValue = String(rawValue) }
  public static var allCases: [Self] { [Self(rawValue: "one")] }
  public var hashValue: Int { rawValue.hashValue }
  public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
}

/// A public coding-key declaration is not implied by Codable.
public enum CodingKeys: String, CodingKey {
  case value
}

public protocol DecoderDefaults: Decodable {
  static func make() -> Self
}

extension DecoderDefaults {
  public init(from decoder: any Decoder) throws { self = Self.make() }
}
