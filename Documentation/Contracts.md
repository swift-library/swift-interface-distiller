# Evidence contracts

## Inputs and reproducibility

“Same input” means identical source bytes, including uncommitted and untracked
files; identical resolved dependency content, versions and revisions; identical
compiler build, SDK identity, target triple and deployment target; identical
language/build modes, conditional definitions, enabled traits and declared
build environment; identical extraction version and collection scope. Package
identity is distinct from its display name, origin and resolved version.

Package collection hashes regular files recursively, excluding `.git`, `.build`
and `.swiftpm`, which own VCS, compilation and package-manager state. Source
symlinks must resolve inside the package root. File links contribute their lexical
path, resolved relative target and content; directory links contribute their lexical
path and resolved target, whose files are enumerated at their real path. Links are
never recursively followed, so internal cycles have finite identity. Collection
normalizes execution paths consistently before invoking SwiftPM to avoid duplicate
compiler-cache identities for filesystem aliases. The
manifest and resolved dependencies are interrogated through SwiftPM's public
commands; no SwiftPM implementation library is linked. Binary inputs additionally
hash their explicitly supplied content roots. Header inputs hash their declared
source root. SDK identity is the SDK build on macOS and system distribution/libc
identity on Linux. Custom SDK users must supply its identity and path together.

Normalization determinism is a guarantee about identical recorded observations,
not a claim that arbitrary build scripts, environment-sensitive manifests,
network services or compiler plugins are reproducible. Package collection records
source content and explicit build inputs; callers own undeclared external inputs.
Only configurations supplied by callers are collected. Conditions are never
inferred from source, and no build matrix is scheduled.

The run report owns timestamps, duration, cache hit state, executable arguments
and absolute execution paths. It is an operational artifact, separate from
portable evidence. Store evidence, run reports and caches under `.build/`.

## Format and provenance

Product version and schema version are independent. New evidence uses schema `2.0`, described in
[Evidence.schema.json](Schema/Evidence.schema.json). Readers accept unknown object
keys in the same major schema and ignore them; consumers needing round-trip
preservation should retain the original JSON. Unknown major schemas, unknown
required enum values, invalid identities and malformed required fields fail.
New optional fields are minor schema additions; changed meanings, removed fields,
new required fields or enum cases require a major version.

Schema 2 requires `scope.includeSynthesized` and `externalReferences` on every
configuration. These fields record a deliberate collection policy and distinguish
out-of-scope references from missing observations. This is a major schema change
because the fields are required and completeness semantics changed. Readers also
accept schema 1.x snapshots with their recorded scope and gaps intact; a missing
synthesized policy means the legacy collector included copies. Its evidence view
remains unchanged. The [schema 1.0 contract](https://github.com/swift-library/swift-interface-distiller/blob/v0.1.2/Documentation/Schema/Evidence.schema.json)
remains available at the immutable release tag.

Compiler symbol fields retain unknown mixins as JSON values. Declaration
fragments are ordered, raw documentation text is retained, and compiler precise
identifiers are never demangled into replacement identity. Access and SPI have
separate fields. Missing compiler fields are `notCollected`, not `false`.
`reportedConcurrency` parses reported attribute fragments and concurrency
keywords. It preserves those tokens without interpreting an absent token as
negative isolation, Sendable conformance, or a witness-selection claim.

Each symbol and relationship field has provenance, observation state and source
graph identities. `compilerReported` means a compiler field, `parsed` means a
structured projection of a report, `derived` means an explicit calculation, and
`policy` means a caller-selected scope or presentation choice. The provenance
applies recursively within that field. Package structure is parsed from SwiftPM;
source digests and semantic identities are derived. Configuration and scope are
caller declarations, checked against the executing compiler for collection.
Graph IDs are derived from portable, sorted graph content. Graph format versions,
generator strings and language identities are compiler reports. Header module
names are caller-supplied labels because Clang can emit an empty module name.

Optional locations are relative to an explicit source root. Locations outside
that root are unresolved. Disabling source locations also removes documentation
URI/range metadata, retaining each raw comment line's text. This keeps line-number
and checkout-location differences out of location-free observations.

## Identity and merging

A symbol is identified by module, interface language and compiler precise
identifier within a configuration. Its key length-prefixes each component, so
separators inside a compiler identifier are unambiguous. Configuration identity
is a SHA-256 digest of canonical build configuration. It includes the extractor
version; comparing different compilers/configurations is explicitly incomparable.

Main and extension graph files contribute to the same module. Identical graphs
and identical symbols have duplicate records; identical symbol fields combine
source graph references. Conflicting variants are retained in a conflict record
and excluded from the resolved symbol set. No observation wins by file order.
Snapshots can merge only within one schema major and when each configuration identity has identical
observations. Distinct configurations remain distinct; an overlapping identity
with different observations is an error.

JSON uses UTF-8, sorted object keys, stable set ordering and one terminal newline.
Numbers use Foundation Decimal representation. Numeric spelling is normalized;
unbounded numeric precision is not an evidence contract. Ordered sequences
(declaration fragments, parameters, comment lines) keep order.
Symbols and configurations are sorted by identity. Graph and relationship sets
are canonicalized before their content identities are computed.

## Completeness and selection

States distinguish `present`, `absent`, `notCollected`, `unsupported`, `failed`,
`filtered` and `unresolved`. `absent` requires an observation such as an explicitly
unconditional dependency; omitted producer fields are never inferred absent.
Expected and collected modules are separate lists. Compiler identifiers outside
the collected scope are listed in `externalReferences`, a derived sorted set of
missing declaration references and relationship endpoints. They are external
observations, not unresolved collection gaps. Conflicts and missing expected
modules remain gaps.
Binary and system targets are retained as structure; explicit binary/header
collection selects their language view. An operation failure yields an error,
not a success-shaped empty snapshot.

The default package scope is public/open interfaces of library products and their
reachable Swift library targets. Libraries with only whitespace and comments and no build-tool plugin,
and packages with no library products, produce an empty default scope without a
build; no claim is made about executable behavior. Other sources and plugin-generated library targets require compiler
collection, even if their API eventually proves empty. Macro implementations,
plugins and executable build tools remain package structure. C dependencies supply module maps and header
search paths for Swift imports; collecting their C language view requires explicit
header collection. Explicit module selection replaces the default; explicit
dependency module selection adds modules from the actual resolved graph. Symbol include/exclude patterns match the
compiler ID, name or `Module.name`. `*` matches any sequence and `?` one character.
An empty include set includes all candidates. Exclusion wins over inclusion.
SPI remains a separate opt-in dimension. Synthesized symbol-graph copies are
excluded by default through `-skip-synthesized-members`; graph normalization
applies the same rule to `::SYNTHESIZED::` identities and their relationships.
`includeSynthesized: true` opts in. Original protocol-extension declarations and
conformances remain, including defaults from package-owned protocols. Exclusion
is the recorded policy, not a completeness gap. Graph identities use the policy's
projected graph content, so excluded copies do not affect comparison provenance.

Detected package configurations use `languageMode: "package"`, honoring each
manifest's Swift language mode, including dependency and generator packages.
An explicit numeric language mode applies a global compiler override. Apple
platform developer framework and library search paths accompany package extraction,
matching SwiftPM's access to Testing and its Foundation overlay.

Filtering is recorded and does not make
out-of-scope declarations evidence of removal in a differently scoped comparison.

## Queries, views and comparison

Queries bind to one snapshot digest and one configuration. Lookup accepts semantic
ID, compiler ID, displayed name or joined path components; ambiguous names return
all observations. Members, observed conformers and initializer candidates follow
reported relationships. Returns-a-type candidates contain that compiler type ID
in return fragments; they are candidates, not a type-inference result.

A slice follows declaration references, outgoing relationships and contained
members/requirements until closure. Cycles terminate by identity. Roots must
resolve within the snapshot. `omittedReferences` contains only in-snapshot symbols
excluded by a byte or symbol-count budget; `externalReferences` lists out-of-scope
compiler identifiers separately. A slice is `complete` when every in-snapshot
reference is selected. `truncated` means a budget omitted in-snapshot symbols.
Collection gaps remain visible independently of selection completeness. Symbol-count and
byte budgets constrain the selected symbol payload in the requested format, not
the snapshot header or diagnostic envelope. JSON retains its sum of independently
encoded symbol records; Swift and Markdown measure the rendered UTF-8 payload,
including declaration context, documentation, fences and anchors. `symbolBytes`
reports that payload size. Text views include ancestor declarations as context
for member queries; those context declarations also count toward their budget.
A consumer must inspect both the state and omitted references.

The default Markdown interface view projects the collected evidence. One snapshot
header records modules, extractor, toolchain, 12-character configuration IDs,
scope, declaration and external-reference counts, and every recorded gap category.
The header and query diagnostics use counts; compiler identifier lists remain in
JSON and the evidence view. Short IDs
are display labels; canonical JSON retains the authoritative full identities.
Declarations preserve the compiler's ordered fragments (including generic parameters,
where clauses, isolation and signatures), add reported access and availability,
and join observed inheritance and conformance relationships. These are reported
interfaces, not compilable source replacements: bodies, unreported default arguments,
uncollected attributes and witness selection cannot be recovered. Missing declaration
fragments are labelled explicitly. C and Objective-C blocks keep their language view.

Members follow `memberOf`, `requirementOf` and `optionalRequirementOf`. A protocol
default with a `defaultImplementationOf` edge uses its reported declaring path
to identify the containing protocol; queries and views share this derivation.
The declaring protocol may inherit the implemented requirement from another protocol. It does
not select a conformance witness. Protocol
extension members and constrained members retain extension contexts. Conditional
conformances keep their conditions; external extensions form a separate group.
Documentation uses `///` lines, with the leading prose paragraph by default.
Lists, headings, quotes and code blocks end that paragraph; list-only comments have
no summary. `full` and `none` select other projections. Readable views collapse
standard requirement shapes stated by observed Decodable, Encodable, Equatable,
Hashable, RawRepresentable and CaseIterable conformances. Matching uses standard
compiler protocol identifiers, reported signatures and declaration ownership;
extra overloads, unknown signatures and original protocol-extension declarations
remain. An unfiltered enum's single failable raw-value initializer is an
unambiguous RawRepresentable presentation candidate. This is a presentation
policy, not a claim about compiler synthesis or conformance witness selection.
`--show-implied` expands these collected declarations; JSON and the evidence
view retain them. Public CodingKeys declarations remain visible because Codable
does not require that named type. Implicit Copyable, Escapable and SendableMetatype
conformance relationships are omitted from the interface projection; JSON and
`--view evidence` retain them. Reported declaration fragments, including explicit
constraints, remain authoritative.

Interface views emit one anchor immediately before each top-level declaration block,
including external extension groups with their own blocks. Nested types, members
and constrained extensions within that block share its anchor. `InterfaceRenderer.anchors(in:)`
maps every symbol to this containing block's destination; multiple symbols can
therefore return the same anchor. Evidence views retain one SHA-256 anchor per symbol.
Top-level anchors use lowercase module, immediate owner and declaration name,
joining alphanumeric runs with hyphens. Parameter-label lists are excluded and
an all-punctuation name becomes `symbol`. Collisions add a deterministic prefix
of the top-level symbol identity's SHA-256; repeated blocks in multiple configurations
also include configuration identity. Adding documentation, moving checkouts or
changing input order does not change anchors. Collisions can change an otherwise
unsuffixed anchor. The mapping is computed from the whole snapshot, including
for subset queries. Members neither create anchor IDs nor participate in collisions.

`--by-module` produces a module index and linked interface parts without excluding
any selected API. Reported declaration counts include collapsed requirements.
`InterfaceRenderer.measure` and `render --report` account for UTF-8 bytes in the
whole unsplit interface. Each symbol owns its declaration, documentation and
anchor bytes when it owns a top-level block; members have zero anchor bytes.
Header, headings, fences and remaining spacing are overhead.
Collapsed symbols have zero rendered bytes and retain their standard-requirement
category. Reports describe presentation, separately from canonical evidence.

Splitting keeps a top-level declaration, all nested members and its constrained
extensions together. Every part includes snapshot and module context, and the
byte budget includes that context. An indivisible declaration that cannot fit
produces an error with the minimum required size. `--view evidence` retains the
full metadata, SHA-256 anchors, explicit cross-part links and per-evidence-block
splitting of the evidence view; documentation selection affects only interface views.

Comparison reports added/removed symbols and JSON-pointer field changes in
interface, documentation, availability and provenance categories. Different
configuration identities are incomparable. Different scopes produce a provenance
change without claiming interface additions/removals. Compiler API diagnostics
are a separate artifact with producer, input identities, status and normalized
stdout/stderr. Neither comparison chooses a version nor decides a release gate.

Documentation coverage counts collected non-extension symbols once. Its denominator
follows the recorded synthesized-member policy. A nonblank raw comment line marks a symbol
documented. Excluded symbols and conflicted variants are outside the denominator.
An empty denominator yields a null fraction, never a manufactured 100 percent.

## Failures, caching and baseline safety

The CLI emits command data only on stdout; errors are JSON on stderr with code,
message and context. Child compiler streams are captured, not interleaved into
contract data. Exit codes: 0 success/equal; 1 observed difference; 2 usage, input,
schema or I/O failure; 3 process failure/timeout; 4 incomplete baseline; 130
cancellation. Diagnostic commands return 0 when the diagnostic artifact was
collected, preserving the compiler's own status inside it.

Subprocesses run in dedicated process groups with null stdin, concurrently drained
stdout/stderr, bounded output, timeout and task cancellation. A cancellation or
timeout kills the process group, including children holding pipe descriptors.

Collected and normalized caches are content-keyed separately. SwiftPM owns
compilation incrementality. A file lock serializes package collection sharing a
cache, and completed evidence is written atomically. Cache hits validate the
snapshot schema and identities. A cache is a disposable trusted local derivative.

Baseline write validates before atomic replacement. Missing expected modules,
failed/unsupported collection and conflicts cannot replace a valid baseline.
External references remain explicit and may exist in a valid scoped baseline.
Baseline check never writes the baseline.
