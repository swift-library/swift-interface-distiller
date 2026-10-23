// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu and the swift-library project authors

/// An immutable version requirement containing alternatives of comparison groups.
///
/// Comparisons in each group must all match; any matching group satisfies the
/// requirement. Equality and hashing compare the stored groups, including their
/// order, rather than proving equivalence between different expressions.
public struct VersionRequirement: Hashable, Sendable {
  /// A comparison against a complete semantic version.
  public enum Comparator: Hashable, Sendable {
    /// Equal version precedence, ignoring build metadata.
    case exact(Version)
    /// At least the given version.
    case atLeast(Version)
    /// Greater than the given version.
    case greaterThan(Version)
    /// At most the given version.
    case atMost(Version)
    /// Less than the given version.
    case lessThan(Version)
    /// Caret compatibility: keep the leftmost nonzero core component fixed.
    case compatibleWith(Version)
    /// At least the given version, keeping its major and minor components fixed.
    case upToNextMinor(Version)

    var version: Version {
      switch self {
      case .exact(let version), .atLeast(let version), .greaterThan(let version),
        .atMost(let version), .lessThan(let version), .compatibleWith(let version),
        .upToNextMinor(let version):
        return version
      }
    }

    func matches(_ candidate: Version) -> Bool {
      switch self {
      case .exact(let version):
        return candidate == version
      case .atLeast(let version):
        return candidate >= version
      case .greaterThan(let version):
        return candidate > version
      case .atMost(let version):
        return candidate <= version
      case .lessThan(let version):
        return candidate < version
      case .compatibleWith(let version):
        guard candidate >= version, candidate.major == version.major else { return false }
        if version.major > 0 { return true }
        guard candidate.minor == version.minor else { return false }
        return version.minor > 0 || candidate.patch == version.patch
      case .upToNextMinor(let version):
        return candidate >= version && candidate.major == version.major
          && candidate.minor == version.minor
      }
    }
  }

  let alternatives: [[Comparator]]

  /// Matches every release version; prereleases require an explicit matching option.
  public static let any = VersionRequirement(all: [])

  /// Matches no version, including when prerelease matching is enabled.
  public static let empty = VersionRequirement(any: [])

  /// Creates a conjunction of comparisons. An empty group matches any release version.
  public init(all comparators: [Comparator]) {
    alternatives = [comparators]
  }

  /// Creates alternatives of comparison groups.
  ///
  /// An empty list matches no version. Empty groups match any release version.
  public init(any alternatives: [[Comparator]]) {
    self.alternatives = alternatives
  }

  /// Creates a requirement from an inclusive lower and exclusive upper bound.
  public init(_ range: Range<Version>) {
    self.init(all: [.atLeast(range.lowerBound), .lessThan(range.upperBound)])
  }

  /// Creates a requirement from inclusive bounds.
  public init(_ range: ClosedRange<Version>) {
    self.init(all: [.atLeast(range.lowerBound), .atMost(range.upperBound)])
  }

  /// Checks version precedence and prerelease eligibility within each comparison group.
  ///
  /// By default, a group accepts prereleases only if one of its comparison versions
  /// is a prerelease. A release-valued exclusive upper bound also excludes that
  /// core's prereleases. These rules match SwiftPM's half-open range behavior.
  /// Set includingPrereleases to true to apply only the comparisons.
  public func contains(_ version: Version, includingPrereleases: Bool = false) -> Bool {
    alternatives.contains { comparators in
      guard comparators.allSatisfy({ $0.matches(version) }) else { return false }
      guard version.isPrerelease && !includingPrereleases else { return true }
      guard comparators.contains(where: { $0.version.isPrerelease }) else { return false }
      return !comparators.contains { comparator in
        guard case .lessThan(let upper) = comparator, !upper.isPrerelease else { return false }
        return version.major == upper.major && version.minor == upper.minor
          && version.patch == upper.patch
      }
    }
  }
}

extension VersionRequirement.Comparator: CustomStringConvertible {
  /// A comparison expression that preserves the bound's build metadata.
  public var description: String {
    switch self {
    case .exact(let version): return "=\(version)"
    case .atLeast(let version): return ">=\(version)"
    case .greaterThan(let version): return ">\(version)"
    case .atMost(let version): return "<=\(version)"
    case .lessThan(let version): return "<\(version)"
    case .compatibleWith(let version): return "^\(version)"
    case .upToNextMinor(let version): return "~\(version)"
    }
  }
}
