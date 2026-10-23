// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu and the swift-library project authors

extension Version {
  /// The reason a string could not be parsed as a semantic version.
  ///
  /// Core component indexes identify major (0), minor (1) and patch (2).
  /// Prerelease and build metadata indexes are zero-based within their own lists.
  public enum ParseError: Error, Equatable, Sendable {
    /// The input contains a character outside the ASCII range.
    case nonASCII
    /// The input has a different number of core components than the required three.
    case invalidCoreComponentCount(Int)
    /// A core component is empty or contains a character other than an ASCII digit.
    case invalidCoreComponent(index: Int, value: String)
    /// A core component has more than one digit and starts with zero.
    case leadingZeroInCoreComponent(index: Int, value: String)
    /// A numeric core component cannot be represented by a nonnegative Int.
    case coreComponentOverflow(index: Int, value: String)
    /// A prerelease identifier is empty or contains a character outside its allowed set.
    case invalidPrereleaseIdentifier(index: Int, value: String)
    /// A numeric prerelease identifier has more than one digit and starts with zero.
    case leadingZeroInPrereleaseIdentifier(index: Int, value: String)
    /// A build metadata identifier is empty or contains a character outside its allowed set.
    case invalidBuildMetadataIdentifier(index: Int, value: String)
  }
}

extension Version.ParseError: CustomStringConvertible {
  /// A diagnostic that includes the invalid value and its component index when available.
  public var description: String {
    switch self {
    case .nonASCII:
      return "A semantic version must contain only ASCII characters."
    case .invalidCoreComponentCount(let count):
      return "A semantic version requires three core components; received \(count)."
    case .invalidCoreComponent(let index, let value):
      return "Core component \(index) must contain ASCII digits; received '\(value)'."
    case .leadingZeroInCoreComponent(let index, let value):
      return "Core component \(index) has a leading zero: '\(value)'."
    case .coreComponentOverflow(let index, let value):
      return "Core component \(index) exceeds Int.max: '\(value)'."
    case .invalidPrereleaseIdentifier(let index, let value):
      return "Invalid prerelease identifier \(index): '\(value)'."
    case .leadingZeroInPrereleaseIdentifier(let index, let value):
      return "Prerelease identifier \(index) has a leading zero: '\(value)'."
    case .invalidBuildMetadataIdentifier(let index, let value):
      return "Invalid build metadata identifier \(index): '\(value)'."
    }
  }
}
