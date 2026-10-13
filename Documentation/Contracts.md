# Evidence contracts

## Inputs and reproducibility

“Same input” means identical source bytes, including uncommitted and untracked
files; identical resolved dependency content, versions and revisions; identical
compiler build, SDK identity, target triple and deployment target; identical
language/build modes, conditional definitions, enabled traits and declared
build environment; identical extraction version and collection scope. Package
identity is distinct from its display name, origin and resolved version.

Package collection hashes regular files recursively, excluding `.git`, `.build`
and `.swiftpm`, which own VCS, compilation and package-manager state. External
source symlinks and directory symlinks are rejected because they do not form a
closed input. Regular source symlinks must resolve inside the package; their lexical path,
resolved relative target and content contribute to input identity. The
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

Product version and schema version are independent. Schema `1.0` is described in
[Evidence.schema.json](Schema/Evidence.schema.json). Readers accept unknown object
keys in the same major schema and ignore them; consumers needing round-trip
preservation should retain the original JSON. Unknown major schemas, unknown
required enum values, invalid identities and malformed required fields fail.
New optional fields are minor schema additions; changed meanings, removed fields,
new required fields or enum cases require a major version.

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
Several snapshots can merge only when each configuration identity has identical
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
Expected and collected modules are separate lists. External type references and
relationship endpoints may remain unresolved even in a successful collection.
Binary and system targets are retained as structure; explicit binary/header
collection selects their language view. An operation failure yields an error,
not a success-shaped empty snapshot.

The default package scope is public/open interfaces of library products. Explicit
module selection replaces that default; explicit dependency module selection adds
modules from the actual resolved graph. Symbol include/exclude patterns match the
compiler ID, name or `Module.name`. `*` matches any sequence and `?` one character.
An empty include set includes all candidates. Exclusion wins over inclusion.
SPI remains a separate opt-in dimension. Filtering is recorded and does not make
out-of-scope declarations evidence of removal in a differently scoped comparison.

## Queries, views and comparison

Queries bind to one snapshot digest and one configuration. Lookup accepts semantic
ID, compiler ID, displayed name or joined path components; ambiguous names return
all observations. Members, observed conformers and initializer candidates follow
reported relationships. Returns-a-type candidates contain that compiler type ID
in return fragments; they are candidates, not a type-inference result.

A slice follows declaration references, outgoing relationships and contained
members/requirements until closure. Cycles terminate by identity. Missing and
budget-omitted references are explicit. Its state is `complete` only if no
reference was omitted; external references produce `truncated`. Symbol-count and
byte budgets constrain the selected symbol payload, not the diagnostic envelope.
A consumer must inspect both the state and omitted references.

Markdown renders this same evidence model. Full SHA-256 anchors are stable for
configuration and symbol identity. Splitting names parts deterministically and
uses explicit cross-part links. A byte budget is strict; an evidence block that
cannot fit alone yields an error reporting the required size.

Comparison reports added/removed symbols and JSON-pointer field changes in
interface, documentation, availability and provenance categories. Different
configuration identities are incomparable. Different scopes produce a provenance
change without claiming interface additions/removals. Compiler API diagnostics
are a separate artifact with producer, input identities, status and normalized
stdout/stderr. Neither comparison chooses a version nor decides a release gate.

Documentation coverage counts collected non-extension symbols once, including
reported synthesized declarations. A nonblank raw comment line marks a symbol
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
Unresolved external references remain explicit and may exist in a valid scoped
baseline. Baseline check never writes the baseline. Shared organization workflows
own comparison targets, release interpretation and baseline governance.
