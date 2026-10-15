# Swift interface

Modules: EvidenceExample
View: summary docs; 0 conformance-implied members collapsed
Extractor: 0.2.0 · Configuration: 9cc03895807a
Toolchain: fixture compiler
Scope: public/open; library products; SPI included; synthesized excluded by policy
Completeness: 1/1 modules; 18 declarations; 5 external references; no recorded gaps

## EvidenceExample

<a id="evidenceexample-item"></a>

```swift
/// A named value.
public struct Item: Named, Sendable {
  public init(name: String)
  public static func make() -> Item
  /// The display name.
  public let name: String
}
```

<a id="evidenceexample-named"></a>

```swift
/// A value that can supply its display name.
public protocol Named : Sendable {
  /// The display name.
  public var name: String { get }
}

extension Named {
  /// A default label.
  public var label: String { get }
}
```

<a id="evidenceexample-olditem"></a>

```swift
@available(*, deprecated, renamed: "Item")
public typealias OldItem = Item
```

<a id="evidenceexample-shelf"></a>

```swift
/// A generic collection.
public struct Shelf<T> where T : Named {
  public init(_ item: T)
  public var item: T
}

extension Shelf where T == Item {
  public var firstName: String { get }
}
```

<a id="evidenceexample-store"></a>

```swift
@MainActor public final class Store: Sendable {
  @MainActor public init()
  @MainActor public func load() async throws -> Item
}
```

<a id="evidenceexample-inspect"></a>

```swift
public func inspect() -> String
```

## EvidenceExample — External extensions

<a id="evidenceexample-array"></a>

```swift
extension Array where Element == Item {
  public var names: [String] { get }
}
```

