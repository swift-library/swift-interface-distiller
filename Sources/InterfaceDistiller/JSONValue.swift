// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

/// A structural container for compiler fields the schema does not interpret.
public enum JSONValue: Codable, Sendable, Equatable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Decimal)
  case bool(Bool)
  case null

  public init(from decoder: any Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
    } else if let v = try? c.decode(Bool.self) {
      self = .bool(v)
    } else if let v = try? c.decode(String.self) {
      self = .string(v)
    } else if let v = try? c.decode([String: JSONValue].self) {
      self = .object(v)
    } else if let v = try? c.decode([JSONValue].self) {
      self = .array(v)
    } else {
      self = .number(try c.decode(Decimal.self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .object(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .string(let v): try c.encode(v)
    case .number(let v): try c.encode(v)
    case .bool(let v): try c.encode(v)
    case .null: try c.encodeNil()
    }
  }

  public subscript(_ key: String) -> JSONValue {
    if case .object(let v) = self { return v[key] ?? .null }
    return .null
  }
  public var string: String? {
    if case .string(let v) = self { return v }
    return nil
  }
  public var object: [String: JSONValue] {
    if case .object(let v) = self { return v }
    return [:]
  }
  public var array: [JSONValue] {
    if case .array(let v) = self { return v }
    return []
  }
  public var strings: [String] { array.compactMap(\.string) }
  public var boolean: Bool? {
    if case .bool(let v) = self { return v }
    return nil
  }

  public static func read(_ url: URL) throws -> JSONValue {
    try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }
}

/// Stable UTF-8 JSON with sorted object keys and exactly one terminal newline.
public enum CanonicalJSON {
  public static func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(10)
    return data
  }

  public static func value<T: Encodable>(_ value: T) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: encode(value))
  }

  public static func key<T: Encodable>(_ value: T) throws -> String {
    Digest.sha256(try encode(value))
  }

  public static func write<T: Encodable>(_ value: T, to url: URL) throws {
    let data = try encode(value)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }
}

/// SHA-256 content identity, independent of process-local hash randomization.
public enum Digest {
  public static func sha256(_ data: Data) -> String {
    let constants: [UInt32] = [
      0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5, 0x3956_c25b, 0x59f1_11f1, 0x923f_82a4,
      0xab1c_5ed5,
      0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3, 0x72be_5d74, 0x80de_b1fe, 0x9bdc_06a7,
      0xc19b_f174,
      0xe49b_69c1, 0xefbe_4786, 0x0fc1_9dc6, 0x240c_a1cc, 0x2de9_2c6f, 0x4a74_84aa, 0x5cb0_a9dc,
      0x76f9_88da,
      0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7, 0xc6e0_0bf3, 0xd5a7_9147, 0x06ca_6351,
      0x1429_2967,
      0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc, 0x5338_0d13, 0x650a_7354, 0x766a_0abb, 0x81c2_c92e,
      0x9272_2c85,
      0xa2bf_e8a1, 0xa81a_664b, 0xc24b_8b70, 0xc76c_51a3, 0xd192_e819, 0xd699_0624, 0xf40e_3585,
      0x106a_a070,
      0x19a4_c116, 0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5, 0x391c_0cb3, 0x4ed8_aa4a, 0x5b9c_ca4f,
      0x682e_6ff3,
      0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208, 0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7,
      0xc671_78f2,
    ]
    var bytes = [UInt8](data)
    let bitCount = UInt64(bytes.count) * 8
    bytes.append(0x80)
    while bytes.count % 64 != 56 { bytes.append(0) }
    bytes += (0..<8).reversed().map { UInt8(truncatingIfNeeded: bitCount >> ($0 * 8)) }
    var hash: [UInt32] = [
      0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a, 0x510e_527f, 0x9b05_688c, 0x1f83_d9ab,
      0x5be0_cd19,
    ]
    func rotate(_ v: UInt32, _ n: UInt32) -> UInt32 { (v >> n) | (v << (32 - n)) }
    for offset in stride(from: 0, to: bytes.count, by: 64) {
      var w = [UInt32](repeating: 0, count: 64)
      for i in 0..<16 {
        for j in 0..<4 { w[i] = (w[i] << 8) | UInt32(bytes[offset + i * 4 + j]) }
      }
      for i in 16..<64 {
        let a = w[i - 15]
        let b = w[i - 2]
        w[i] =
          w[i - 16] &+ (rotate(a, 7) ^ rotate(a, 18) ^ (a >> 3)) &+ w[i - 7]
          &+ (rotate(b, 17) ^ rotate(b, 19) ^ (b >> 10))
      }
      var s = hash
      for i in 0..<64 {
        let t =
          s[7] &+ (rotate(s[4], 6) ^ rotate(s[4], 11) ^ rotate(s[4], 25))
          &+ ((s[4] & s[5]) ^ (~s[4] & s[6])) &+ constants[i] &+ w[i]
        let u =
          (rotate(s[0], 2) ^ rotate(s[0], 13) ^ rotate(s[0], 22))
          &+ ((s[0] & s[1]) ^ (s[0] & s[2]) ^ (s[1] & s[2]))
        s = [t &+ u, s[0], s[1], s[2], s[3] &+ t, s[4], s[5], s[6]]
      }
      for i in 0..<8 { hash[i] = hash[i] &+ s[i] }
    }
    return hash.map { String(format: "%08x", $0) }.joined()
  }
}
