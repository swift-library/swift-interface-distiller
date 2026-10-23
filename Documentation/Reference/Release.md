# Release configuration

The package follows the organization's [versioning](https://github.com/swift-library/.github/blob/master/VERSIONING.md)
and [maintenance](https://github.com/swift-library/.github/blob/master/MAINTENANCE.md)
standards.

[`.github/release.json`](../../.github/release.json) declares the repository,
version source and pattern, changelog, minimum Swift version and supported
platforms. `DistillerVersion.current` in `Sources/InterfaceDistiller/Evidence.swift`
owns the package and executable version; `CHANGELOG.md` owns release notes.
The schema version is a separate compatibility declaration documented in
[Evidence contracts](../Contracts.md).

[`.github/swift-package.json`](../../.github/swift-package.json) declares
validation. Shared policy checks the version declaration, changelog and
Swift tools floor. Shared validation runs formatting, tests and release builds,
plus the declared Linux tests, DocC target, terminal demo and repository commands.
The required checks are `policy / policy` and `validate / result`; run the
[local checks](../../CONTRIBUTING.md) before preparing a release.

Pushing a signed annotated `vX.Y.Z` tag triggers
[the release workflow](../../.github/workflows/release.yml). It validates the
tagged commit with `swift-package.yml`, then calls `swift-package-release.yml`
with that tag and commit. The shared release workflow verifies the tag and
version and publishes changelog notes without attachments. Tag messages use
`swift-interface-distiller X.Y.Z`; published tags are immutable.
