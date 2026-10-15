## Unreleased

## 0.3.1

- Validate terminal recordings against their captured extractor provenance and
  package revision, independently of the renderer and measurement input versions.
- Ship the 0.3.0 top-level interface anchor behavior: member links target their
  containing block. Update links to removed member IDs to that block's anchor;
  evidence views keep per-symbol anchors and JSON stays at schema 2.0.

## 0.3.0

Publication did not complete because the recording checker required a single
measurement extractor version. The immutable tag is superseded by 0.3.1.

- Emit interface anchors only for top-level declaration blocks and standalone
  extension groups. Member links returned by `InterfaceRenderer.anchors(in:)`
  target their containing block, and repeated values are expected. Update links
  that targeted member IDs to use the containing top-level anchor. The evidence
  view retains per-symbol anchors; canonical JSON stays at schema 2.0.
- Publish complete interface size and density measurements with block-level
  anchors for all 13 organization packages.

## 0.2.0

- Render a compact Swift interface by default: nested members, reported attributes,
  access, signatures, generics and observed conformances, summary documentation,
  readable anchors, and splitting only between top-level declarations.
- Collapse standard conformance requirements in readable views; `--show-implied`
  expands them while JSON and evidence retain every collected declaration.
  Summary docs stop at Markdown block boundaries, including parameter lists.
- Use compact owner/name anchors and add `--by-module` indexed rendering and
  `render --report` UTF-8 byte accounting for large interfaces.
- Keep the previous rendering and content through `render --view evidence`.
  Scripts that depend on the previous default Markdown must select that view.
- Add `--docs summary|full|none`, query and slice `--format json|swift|markdown`,
  and a `slice` command alias. Query budgets count the selected format's payload.
- Collect package interfaces without synthesized per-conformer copies by default;
  use `--include-synthesized` to opt in. Original protocol extensions and conformances
  remain. Hide implicit marker conformances in the interface view.
- Distinguish external references from collection gaps and budget omissions. A slice
  containing its in-snapshot closure is complete; text headers show reference counts.
- Emit evidence schema 2.0 with required synthesized policy and external-reference
  fields. Update schema consumers before reading new evidence. Schema 1.x reading and
  its evidence rendering remain supported; JSON remains the default query format.
- Accept internal directory symlinks, normalize compiler execution paths, honor
  package language modes, expose toolchain Testing modules during extraction, and
  return empty default scopes for declaration-free libraries and executable packages.
- Include both captured compiler streams in process-failure diagnostics.

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
