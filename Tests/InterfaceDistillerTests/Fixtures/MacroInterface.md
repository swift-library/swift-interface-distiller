# Swift interface

Modules: MacroExample
View: summary docs; 0 conformance-implied members collapsed
Extractor: 0.2.0 · Configuration: 9cc03895807a
Toolchain: fixture compiler
Scope: public/open; library products; synthesized excluded by policy
Completeness: 1/1 modules; 10 declarations; 3 external references; no recorded gaps

## MacroExample

<a id="macroexample-childcounter"></a>
<a id="macroexample-childcounter-value"></a>

```swift
/// A protocol with an inherited requirement.
public protocol ChildCounter : ParentCounter {
}

extension ChildCounter {
  /// Supplies the inherited requirement's default.
  public func value() -> Int
}
```

<a id="macroexample-counter"></a>
<a id="macroexample-counter-count-96ce1e02"></a>
<a id="macroexample-counter-count-a2ef3c31"></a>

```swift
/// A counter value.
public protocol Counter {
  /// The default count.
  public var count: Int { get }
}

extension Counter {
  /// The default count.
  public var count: Int { get }
}
```

<a id="macroexample-defaultcounter"></a>
<a id="macroexample-defaultcounter-init"></a>

```swift
/// A value using the counter default.
public struct DefaultCounter: Counter {
  public init()
}
```

<a id="macroexample-parentcounter"></a>
<a id="macroexample-parentcounter-value"></a>

```swift
/// A protocol requirement inherited by a child.
public protocol ParentCounter {
  public func value() -> Int
}
```

<a id="macroexample-answer"></a>

```swift
/// Reports an integer expression.
@freestanding(expression) public macro answer() -> Int
```

