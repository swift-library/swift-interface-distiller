<p align="center">
  <img src="Documentation/Assets/Logo.svg" width="160" alt="Interface Distiller logo">
</p>

# swift-interface-distiller

A public-interface evidence engine for Swift packages, symbol graphs, importable
modules and C or Objective-C headers. Evidence records its build configuration,
collection scope, provenance and gaps. Queries operate on one immutable snapshot.

The `InterfaceDistiller` library and `interface-distiller` executable share the
same model. JSON is canonical; Markdown is a view. Comparison reports observations
and compiler diagnostics without deciding release policy.

See [contracts](Documentation/Contracts.md), [commands](Documentation/Commands.md),
[capabilities](Documentation/Capabilities.md), and [development sources](Documentation/DevelopmentSources.md).

Build with Swift 6.3 or later using `swift build`. Run `Scripts/check` for validation.
Temporary output belongs in `.build/`.

## Installation

```swift
.package(url: "https://github.com/swift-library/swift-interface-distiller.git", from: "0.1.0")
```

See [the versioned consumer](Examples/Consumer) for a complete downstream package.
Run `Scripts/check-consumer` after publishing to verify version resolution and the
public library from a separate package. The executable is
`interface-distiller`; build it with `swift build -c release`.

[Contributing](https://github.com/swift-library/.github/blob/master/CONTRIBUTING.md) ·
[Security](https://github.com/swift-library/.github/blob/master/SECURITY.md) ·
[Release policy](https://github.com/swift-library/.github/blob/master/VERSIONING.md)
