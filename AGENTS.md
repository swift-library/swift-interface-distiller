# Interface Distiller

Read README.md and Documentation/Contracts.md before changing behavior.
The library owns snapshots, collection, queries, rendering and comparison. The
executable owns argument handling and streams. Release policy belongs to the
organization's shared standards.

The Swift tools minimum is 6.3. The library and bundled executable share the
macOS 15 deployment floor. Shared CI uses one compiler entry: Xcode 26.6 on
macOS 26, with older deployment targets covered by compile-time availability
checking against the latest SDK. Linux validation is declared separately.

Run the local checks in CONTRIBUTING.md before pushing. Validation is declared
in `.github/swift-package.json`; required checks are `policy / policy` and
`validate / result`. Keep repository-specific automation in lowercase `scripts/`
and temporary output in `.build/`.
Use signed Conventional Commits and reviewed pull requests. Published tags are
immutable. Preserve compiler identifiers and distinguish missing observations
from negative facts. Every derived fact needs a documented derivation.

Changes to the snapshot format require schema compatibility review and fixture tests.
Never substitute a partial result for a complete baseline. Keep execution paths,
timing and cache state in run reports, outside canonical snapshots.
