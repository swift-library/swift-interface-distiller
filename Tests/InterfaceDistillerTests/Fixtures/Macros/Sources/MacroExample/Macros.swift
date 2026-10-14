// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

/// A counter value.
public protocol Counter { var count: Int { get } }

extension Counter {
  /// The default count.
  public var count: Int { 0 }
}

/// A value using the counter default.
public struct DefaultCounter {
  public init() {}
}

extension DefaultCounter: Counter {}

/// Reports an integer expression.
@freestanding(expression)
public macro answer() -> Int = #externalMacro(module: "FixtureMacros", type: "Answer")

/// A protocol requirement inherited by a child.
public protocol ParentCounter { func value() -> Int }

/// A protocol with an inherited requirement.
public protocol ChildCounter: ParentCounter {}

extension ChildCounter {
  /// Supplies the inherited requirement's default.
  public func value() -> Int { 1 }
}
