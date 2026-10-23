# Terminal demonstration

The README demonstrates collecting swift-semver and querying its incrementing
declaration within a byte budget. The commands and fixture setup live in
[script.yml](../../.github/assets/terminal/script.yml); complete displayed output
lives in [recording.json](../../.github/assets/terminal/recording.json).
The [fixture](../../.github/assets/terminal/fixture/README.md) identifies its
fixed upstream input.

Build the executable and record from the repository root with Node 24.22.0 and
the shared `github-readme-design` toolchain:

```sh
swift build --build-system native -c release
node <toolchain>/src/cli.ts terminal record \
  --script .github/assets/terminal/script.yml \
  --executable .build/release/interface-distiller \
  --out .github/assets/terminal/recording.json
node <toolchain>/src/cli.ts terminal check --recording-only \
  --assets .github/assets/terminal \
  --executable .build/release/interface-distiller
```

Use the same compiler and SDK as the shared demo job: compiler headers and
snapshot identities are part of the recording. The recorder copies the fixture
into an isolated temporary home and removes it after the commands complete.
Query byte budgets cover the selected payload; snapshot context and omission
diagnostics remain visible outside the budget. See [Commands](../Commands.md).

The `demo` declaration in
[swift-package.json](../../.github/swift-package.json) builds the release product
and checks the recording through the shared workflow. Render `terminal-dark.svg`
and `terminal-light.svg` separately with the organization's current DESIGN and
fonts using the shared toolchain; the README's `<picture>` references those files.
