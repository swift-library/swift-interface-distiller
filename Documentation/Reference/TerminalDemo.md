# Terminal demonstration

The README records collect, then query, using the released 0.2.0 executable and
the swift-semver revision in the published measurement record. Complete standard
output and exit codes live in `Documentation/Assets/Demo-record.json`; its
provenance file records the executable, input archive and snapshot digests.
Build diagnostics remain under `.build/demo-session`.

From the repository root:

```sh
swift build --build-system native -c release
mkdir -p .build
git clone https://github.com/swift-library/swift-semver.git .build/demo-source
python3 Scripts/record-demo.py --package .build/demo-source
Scripts/check-demo
```

The recording script archives the fixed input revision into the ignored session
directory. It does not copy a checkout or Git directory. Query byte budgets cover
the chosen payload; snapshot context and omission diagnostics remain visible
outside the budget. The complete slice contract is in [Commands](../Commands.md).

The full SHA in `.github/presentation.json` pins the shared renderer and DESIGN.md.
`Scripts/check-demo` fetches those public files into `.build/presentation/shared`
and checks both terminal SVG variants. To regenerate, run the fetched renderer
with the same design, record and output directory, omitting `--check`.
