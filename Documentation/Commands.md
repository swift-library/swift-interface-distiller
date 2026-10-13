# Commands

The examples use `.build/` for generated files. `--help` lists the command grammar;
`--version` prints the product version. Errors are JSON on stderr. Command data is
JSON on stdout unless `--output` writes it atomically to a file.

```sh
interface-distiller configuration --output .build/configuration.json
interface-distiller collect package . --output .build/api.json --report .build/run.json
interface-distiller query .build/api.json lookup MyType
interface-distiller query .build/api.json members MyType
interface-distiller query .build/api.json conformers MyProtocol
interface-distiller query .build/api.json initializers MyType
interface-distiller query .build/api.json returning MyType
interface-distiller query .build/api.json slice MyType --max-symbols 100 --max-bytes 60000
interface-distiller coverage .build/api.json
interface-distiller render .build/api.json --output-dir .build/markdown --byte-budget 12000
interface-distiller baseline write .build/api.json .build/baseline.json
interface-distiller baseline check .build/api.json .build/baseline.json
interface-distiller compare .build/baseline.json .build/api.json
```

For custom builds, edit the configuration JSON explicitly, then supply
`--configuration .build/configuration.json`. Compiler builds must match the
executing `--swift` tool; the SDK path is `--sdk-path`. The target triple carries
the actual deployment floor; `deploymentTarget` records and must match its version
(or `notApplicable` on Linux). Build mode, language mode, conditions, traits and
declared environment live in that configuration. No matrix is inferred.

Package collection defaults to library products. Select `--module ModuleName`
(repeatable) to replace that set. Add an explicitly resolved dependency with
`--dependency-module DependencyModule`. Use `--include` and `--exclude` for
symbol globs; exclusion wins. `--include-spi` and `--source-locations` are opt-ins.

Pre-generated graphs require their producer's configuration:

```sh
interface-distiller normalize .build/graphs --configuration .build/configuration.json \
  --source-root . --source-locations --output .build/api.json
interface-distiller merge .build/macos.json .build/linux.json --output .build/combined.json
interface-distiller query .build/combined.json lookup MyType --configuration-id CONFIGURATION_ID
```

Binary collection requires its exact producer configuration and explicit content
roots, including any imported module search paths. The executing toolchain must
match. A compiler's import failure is an error, never an empty success.

```sh
interface-distiller collect module Example --search-path .build/modules \
  --built-with .build/producer.json --configuration .build/producer.json \
  --output .build/binary-api.json
interface-distiller collect headers Geometry --header include/Geometry.h \
  --source-root include --language c --output .build/c-api.json
interface-distiller collect headers Widgets --header include/Widgets.h \
  --source-root include --language objective-c --output .build/objc-api.json
```

Header collection records the Clang build and C/Objective-C language view. It does
not substitute an inferred Swift imported view. Header paths are explicit;
compiler system headers follow the configured target and SDK.

Compiler diagnostics are separate artifacts. The package mode compares a Git
revision through SwiftPM; the digester mode accepts existing digester dumps.

```sh
interface-distiller diagnose package . --baseline-ref v0.1.0 \
  --output .build/compiler-diagnostics.json
interface-distiller diagnose digester --baseline .build/old-sdk.json \
  --candidate .build/new-sdk.json --output .build/digester-diagnostics.json
```

`--cache` chooses a producer-owned cache directory, normally below `.build/`.
`--timeout` sets each subprocess timeout in seconds (default 600). SIGINT and
SIGTERM cancel active subprocess groups. See [Contracts](Contracts.md) for schema,
completeness, comparison semantics, budgets and stable exit codes.
