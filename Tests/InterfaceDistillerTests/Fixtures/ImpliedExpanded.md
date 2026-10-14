# Swift interface

Modules: ImpliedExample
View: summary docs; 9 conformance-implied members expanded
Extractor: 0.2.0 · Configuration: 9cc03895807a
Toolchain: fixture compiler
Scope: public/open; library products; synthesized excluded by policy
Completeness: 1/1 modules; 25 declarations; 17 external references; no recorded gaps

## ImpliedExample

<a id="impliedexample-codingkeys"></a>
<a id="impliedexample-codingkeys-init-c17e8fa1"></a>
<a id="impliedexample-codingkeys-init-44e46c5b"></a>
<a id="impliedexample-codingkeys-init-2a9a731b"></a>
<a id="impliedexample-codingkeys-value"></a>

```swift
/// A public coding-key declaration is not implied by Codable.
public enum CodingKeys: CodingKey, CustomDebugStringConvertible, CustomStringConvertible, Equatable, Hashable, RawRepresentable, Sendable {
  /// Creates a new instance from the specified integer.
  public init?(intValue: Int)
  /// Creates a new instance with the specified raw value.
  public init?(rawValue: String)
  /// Creates a new instance from the given string.
  public init?(stringValue: String)
  case value
}
```

<a id="impliedexample-decoderdefaults"></a>
<a id="impliedexample-decoderdefaults-init"></a>
<a id="impliedexample-decoderdefaults-make"></a>

```swift
public protocol DecoderDefaults : Decodable {
  public static func make() -> Self
}

extension DecoderDefaults {
  /// Creates a new instance by decoding from the given decoder.
  public init(from decoder: any Decoder) throws
}
```

<a id="impliedexample-flags"></a>
<a id="impliedexample-flags-symbol"></a>
<a id="impliedexample-flags-allcases"></a>
<a id="impliedexample-flags-hash"></a>
<a id="impliedexample-flags-hashvalue"></a>
<a id="impliedexample-flags-init-89854a40"></a>
<a id="impliedexample-flags-init-f1fda54e"></a>
<a id="impliedexample-flags-rawvalue"></a>

```swift
/// Public declarations whose signatures are stated by standard conformances.
public struct Flags: CaseIterable, Equatable, Hashable, RawRepresentable {
  /// Returns a Boolean value indicating whether two values are equal.
  public static func == (lhs: Flags, rhs: Flags) -> Bool
  /// A collection of all values of this type.
  public static var allCases: [Flags] { get }
  /// Hashes the essential components of this value by feeding them into the
  /// given hasher.
  public func hash(into hasher: inout Hasher)
  /// The hash value.
  public var hashValue: Int { get }
  /// Creates a new instance with the specified raw value.
  public init(rawValue: String)
  public init(rawValue: Int)
  /// The corresponding value of the raw type.
  public var rawValue: String
}
```

<a id="impliedexample-mode"></a>
<a id="impliedexample-mode-first"></a>
<a id="impliedexample-mode-init"></a>
<a id="impliedexample-mode-second"></a>

```swift
/// A raw enum with compiler-derived requirements.
public enum Mode: CaseIterable, Decodable, Encodable, Equatable, Hashable, RawRepresentable {
  case first
  /// Creates a new instance with the specified raw value.
  public init?(rawValue: String)
  case second
}
```

<a id="impliedexample-model"></a>
<a id="impliedexample-model-init-1c3a8fb5"></a>
<a id="impliedexample-model-init-5b849846"></a>
<a id="impliedexample-model-init-f5c2afc1"></a>
<a id="impliedexample-model-value"></a>

```swift
/// A model with compiler-derived decoding support.
public struct Model: Decodable, Encodable {
  public init(from value: Int)
  /// Creates a new instance by decoding from the given decoder.
  public init(from decoder: any Decoder) throws
  public init(value: Int)
  public var value: Int
}
```

