# Release configuration

The package follows the organization's [versioning](https://github.com/swift-library/.github/blob/master/VERSIONING.md)
and [maintenance](https://github.com/swift-library/.github/blob/master/MAINTENANCE.md)
standards.

[`.github/release.json`](../../.github/release.json) declares the repository,
version source and pattern, changelog, minimum Swift version and supported
platforms. `DistillerVersion.current` in `Sources/InterfaceDistiller/InterfaceSnapshot.swift`
owns the package and executable version; `CHANGELOG.md` owns release notes.
The schema version is a separate compatibility declaration documented in
[Contracts](../Contracts.md).

The Swift tools minimum is 6.3. The library and bundled executable support the
three macOS generations 15, 26 and 27, with a deployment floor of macOS 15.
Linux validation targets Ubuntu 24.04.

[`.github/swift-package.json`](../../.github/swift-package.json) declares
validation. Shared policy checks the version declaration, changelog and
Swift tools floor. The shared compiler matrix uses only the latest stable Xcode,
currently Xcode 26.6 on macOS 26; older macOS targets are covered by compile-time
availability checking against the latest SDK. Shared validation runs formatting,
tests and release builds, plus the declared Linux tests, DocC target, terminal demo
and repository commands.
The required checks are `policy / policy` and `validate / result`; run the
[local checks](../../CONTRIBUTING.md) before preparing a release.

Pushing a signed annotated `vX.Y.Z` tag triggers
[the release workflow](../../.github/workflows/release.yml). It validates the
tagged commit with `swift-package.yml`, then calls `swift-package-release.yml`
with that tag and commit. The shared release workflow verifies the tag and
version and publishes changelog notes without attachments. Tag messages use
`swift-interface-distiller X.Y.Z`; published tags are immutable.
