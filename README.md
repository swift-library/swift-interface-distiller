<div align="center">

<p align="center">
  <a href="https://github.com/swift-library/swift-interface-distiller"><img src="Documentation/Assets/Logo.svg" width="160" alt="swift-interface-distiller logo"></a>
</p>

<h1 align="center">swift-interface-distiller</h1>

<p align="center">
  Distill a Swift package to its public API: a compact interface to read, snapshots to query and diff.
</p>

<p align="center">
  <a href="https://github.com/swift-library/swift-interface-distiller/actions/workflows/ci.yml"><img src="https://github.com/swift-library/swift-interface-distiller/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI"></a>
  <img src="https://img.shields.io/badge/Swift-6.3%2B-F05138?style=flat" alt="Swift 6.3+">
  <img src="https://img.shields.io/badge/platforms-macOS%2015%2B%20%7C%20Linux-lightgrey?style=flat" alt="Platforms: macOS 15+ | Linux">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-Apache--2.0-blue?style=flat" alt="License: Apache-2.0 WITH Swift-exception"></a>
</p>

<p align="center">
  <a href="#overview">Overview</a> ·
  <a href="#quick-look">Quick look</a> ·
  <a href="#install">Install</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#requirements">Requirements</a> ·
  <a href="#documentation">Documentation</a> ·
  <a href="#contributing">Contributing</a> ·
  <a href="#license">License</a>
</p>

</div>

## Overview

Read public declarations reported by the compiler without walking a package’s implementation. Markdown serves people and JSON serves machines, with explicit gaps and deterministic normalization for identical observations. See the [interface guide](Documentation/ReadingInterfaces.md) for measured sizes, budgets, collection scope, and limits.

## Quick look

Collect swift-semver, then query its incrementing declaration within a byte budget:

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/terminal/terminal-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset=".github/assets/terminal/terminal-light.svg">
    <img src=".github/assets/terminal/terminal-light.svg" alt="Terminal: collect swift-semver and query its incrementing declaration in Swift format within a byte budget.">
  </picture>
</p>

## Install

Add the package and the `InterfaceDistiller` product to `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/swift-library/swift-interface-distiller.git",
    .upToNextMinor(from: "0.4.0")
  ),
],
targets: [
  .target(
    name: "YourTarget",
    dependencies: [
      .product(name: "InterfaceDistiller", package: "swift-interface-distiller"),
    ]
  ),
]
```

Install the command-line tool with Homebrew:

```sh
brew install swift-library/tap/swift-interface-distiller
```

On macOS, the formula requires macOS 15 or later and Xcode 26.6 or later with
Swift 6.3 or later selected. See the [tap requirements](https://github.com/swift-library/homebrew-tap/blob/master/Documentation/Tools.md).

Build the executable from a checkout with
`swift build --build-system native -c release`; it is written to
`.build/release/interface-distiller`.

> [!NOTE]
> swift-interface-distiller is pre-1.0. Minor releases may include source-breaking
> changes, so depend on it with `.upToNextMinor(from:)`.

## Usage

Choose the package, modules, configuration, and optional scope explicitly. Query or slice a snapshot as JSON, Swift, or Markdown, then compare it with a release snapshot; the [interface guide](Documentation/ReadingInterfaces.md) explains the workflow and [commands](Documentation/Commands.md) lists the complete grammar.

## Requirements

- Swift 6.3 or later; macOS 15 or later, or Linux. The library and bundled
  command-line tool share the macOS deployment floor.
- A matching compiler, SDK and target configuration for collection. Consuming
  existing snapshots through the library does not run a compiler.
- Clang ExtractAPI for C and Objective-C headers.

The shared CI compiler matrix selects only the latest stable Xcode, currently
Xcode 26.6 on macOS 26. Linux tests use Swift 6.3.3 on Ubuntu 24.04. Older macOS
generations are covered by compile-time availability checking against the latest
SDK. The [capability matrix](Documentation/Capabilities.md) records tested combinations and
compiler/SDK limits. The [validation configuration](.github/swift-package.json)
declares the compiler matrix, formatting paths, Linux image, DocC target, terminal
demo and repository checks. See [Contributing](CONTRIBUTING.md) for local validation.
Temporary output belongs in `.build/`.

## Documentation

- [Reading public interfaces](Documentation/ReadingInterfaces.md): measured sizes, queries, budgets, and boundaries.

- [Usage guide](Documentation/Reference/Usage.md): examples, behavior, and limits.
- [InterfaceDistiller module](Sources/InterfaceDistiller/InterfaceDistiller.docc/InterfaceDistiller.md)
- [Contracts](Documentation/Contracts.md) and [JSON schema](Documentation/Schema/InterfaceSnapshot.schema.json)
- [Commands](Documentation/Commands.md) and [capabilities](Documentation/Capabilities.md)
- [Extension proposals](Documentation/Proposals/Extensions.md)
- [Development sources](Documentation/DevelopmentSources.md) and [changelog](CHANGELOG.md)
- [Versioning and release policy](https://github.com/swift-library/.github/blob/master/VERSIONING.md)
- [Release configuration](Documentation/Reference/Release.md) and [terminal demo](Documentation/Reference/TerminalDemo.md)

## Contributing

Read the [contributing guide](CONTRIBUTING.md) and run its local checks before
submitting a pull request. Report vulnerabilities
through the private route in the [security policy](https://github.com/swift-library/.github/blob/master/SECURITY.md).
This project follows the [code of conduct](https://github.com/swift-library/.github/blob/master/CODE_OF_CONDUCT.md).

## License

swift-interface-distiller is available under the Apache License 2.0 with the Swift
Runtime Library Exception. See [LICENSE.txt](LICENSE.txt) and [NOTICE](NOTICE).
