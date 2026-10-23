// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu and the swift-library project authors

extension Version {
  /// A numeric component of a semantic version.
  public enum Component: Hashable, Sendable {
    case major
    case minor
    case patch
  }

  /// An increment would exceed the representation of a core component.
  public enum IncrementError: Error, Equatable, Sendable {
    case overflow(Component)
  }

  /// Increments a core component, resetting lower components and clearing identifiers.
  ///
  /// The selected component always increases by one, including for prereleases.
  /// Use ``releasing()`` to promote a prerelease without increasing its core.
  /// - Throws: ``IncrementError/overflow(_:)`` if the selected component is Int.max.
  public func incrementing(_ component: Component) throws(IncrementError) -> Version {
    switch component {
    case .major:
      return Version(try Self.increment(major, component: .major), 0, 0)
    case .minor:
      return Version(major, try Self.increment(minor, component: .minor), 0)
    case .patch:
      return Version(major, minor, try Self.increment(patch, component: .patch))
    }
  }

  /// Advances the rightmost numeric prerelease identifier, clearing build metadata.
  ///
  /// Numeric identifiers have no integer size limit. If a prerelease has no numeric
  /// identifier, appends "0". A release version starts the next patch's prerelease
  /// at "0", so 1.2.3 becomes 1.2.4-0.
  /// - Throws: ``IncrementError/overflow(_:)`` if starting the next patch overflows.
  public func incrementingPrerelease() throws(IncrementError) -> Version {
    guard isPrerelease else {
      let patch = try Self.increment(patch, component: .patch)
      return Version(major, minor, patch, prereleaseIdentifiers: ["0"])
    }

    var identifiers = prereleaseIdentifiers
    if let index = identifiers.lastIndex(where: Self.isNumeric) {
      var digits = Array(identifiers[index].utf8)
      var carried = true
      for index in digits.indices.reversed() {
        if digits[index] < 57 {
          digits[index] += 1
          carried = false
          break
        }
        digits[index] = 48
      }
      if carried { digits.insert(49, at: 0) }
      identifiers[index] = String(decoding: digits, as: UTF8.self)
    } else {
      identifiers.append("0")
    }
    return Version(major, minor, patch, prereleaseIdentifiers: identifiers)
  }

  /// Returns the corresponding release version, clearing prerelease and build identifiers.
  public func releasing() -> Version {
    Version(major, minor, patch)
  }

  private static func increment(_ value: Int, component: Component) throws(IncrementError) -> Int {
    let (result, overflow) = value.addingReportingOverflow(1)
    guard !overflow else { throw .overflow(component) }
    return result
  }
}

extension Version.IncrementError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .overflow(let component):
      return "Incrementing the \(component) component would exceed Int.max."
    }
  }
}
