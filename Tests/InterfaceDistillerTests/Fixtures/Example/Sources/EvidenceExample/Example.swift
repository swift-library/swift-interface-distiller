/// A value that can supply its display name.
public protocol Named: Sendable {
  /// The display name.
  var name: String { get }
}

extension Named {
  /// A default label.
  public var label: String { name }
}

/// A named value.
public struct Item: Named {
  public let name: String
  public init(name: String) { self.name = name }
  public static func make() -> Item { Item(name: "example") }
}

/// A generic collection.
public struct Shelf<T: Named> {
  public var item: T
  public init(_ item: T) { self.item = item }
}

extension Shelf where T == Item {
  public var firstName: String { item.name }
}

@available(*, deprecated, renamed: "Item")
public typealias OldItem = Item

@MainActor public final class Store {
  public init() {}
  public func load() async throws -> Item { Item.make() }
}

@_spi(Inspection) public func inspect() -> String { "inspection" }

extension Array where Element == Item {
  public var names: [String] { map(\.name) }
}

#if EXTRA
  public struct ExtraItem { public init() {} }
#endif
