# Library consumer

This independent package resolves `InterfaceDistiller` at version 0.1.1 and uses
only its public API. After the release is published, run:

```sh
swift run --package-path Examples/Consumer --build-system native Consumer
```

The result is a canonical empty-module observation. Lookup and documentation
coverage exercise consumption without compiler collection. Package-manager state
and builds remain under the example's ignored `.swiftpm/` and `.build/` paths.
