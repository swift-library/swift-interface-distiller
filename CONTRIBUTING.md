# Contributing

Follow the shared [contributing guide](https://github.com/swift-library/.github/blob/master/CONTRIBUTING.md).
Use signed Conventional Commits and reviewed pull requests.

The package requires Swift 6.3 or later and targets macOS 15 or later, or Linux.
The shared CI compiler matrix uses the latest stable Xcode only: Xcode 26.6 on
macOS 26. Linux tests use the separately configured Swift 6.3.3 image. Older
macOS generations are checked for API availability at compile time against the
latest SDK.

Run these checks from the repository root:

```sh
swift build
swift test
swift build -c release
xcrun swift-format lint --strict --configuration .swift-format --recursive Package.swift Sources Tests
python3 scripts/check-cli.py
python3 scripts/check-interface-size.py --check
actionlint
```

The CLI check builds the release executable with SwiftPM's native build system
and checks its streams, schema, queries, rendering and baseline behavior. The
interface-size check compares the documentation with its recorded measurements.
Keep temporary outputs in `.build/`.

[`.github/swift-package.json`](.github/swift-package.json) declares shared
validation, including Linux tests, the `InterfaceDistiller` DocC catalog and the
[terminal demo](Documentation/Reference/TerminalDemo.md). The required checks are
`policy / policy` and `validate / result`. Release inputs and the publication
entry point are documented in the [release reference](Documentation/Reference/Release.md).
