## Unreleased

## 0.2.0

- Render a compact Swift interface by default: nested members, reported attributes,
  access, signatures, generics and observed conformances, summary documentation,
  readable anchors, and splitting only between top-level declarations.
- Keep the previous rendering and content through `render --view evidence`.
  Scripts that depend on the previous default Markdown must select that view.
- Add `--docs summary|full|none`, query and slice `--format json|swift|markdown`,
  and a `slice` command alias. Query budgets count the selected format's payload.
- Preserve canonical evidence schema 1.0 and the default JSON query contracts.

## 0.1.2

- Resolve generated and custom C module maps when collecting Swift library interfaces.
- Keep build-time macro implementations out of the default library interface scope.

## 0.1.1

- Collect selected library and dependency modules without extracting unbuilt test
  runners from the package.

## 0.1.0

- Collect portable public-interface evidence from Swift packages, symbol graphs,
  matching binary modules and C or Objective-C headers.
- Query and render configuration-bound snapshots, compare interface observations
  and collect separate compiler API diagnostics.
- Preserve provenance, completeness, duplicate/conflict records and safe baselines.
