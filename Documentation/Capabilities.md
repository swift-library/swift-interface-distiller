# Platform and toolchain capabilities

Collection uses installed tools. Evidence consumption needs only the library.
These configurations have local execution coverage:

| Configuration | Package/graphs | Matching binary modules | C and Objective-C | API diagnostics |
| --- | --- | --- | --- | --- |
| macOS 27, Apple Swift 6.4, SDK build 26A425 | Tested | Tested | Apple Clang 21, tested | SwiftPM and digester tested |
| Ubuntu 24.04 aarch64, Swift 6.3.1 | Tested | Tested | Toolchain Clang, tested | SwiftPM and digester tested |

CI declares Swift 6.3 on Ubuntu 24.04 and selects Xcode 26.6 on macOS 26
(`macos-26-swift-6.3`). Each job records its actual compiler version in the
validation evidence. The package tools floor is 6.3; the
macOS deployment floor is 12. Newer compilers and SDKs are not assumed equivalent.
In particular, the installed Swift 6.3.1 compiler cannot import Foundation from
the macOS 27 SDK; that pairing is not a supported validation configuration.

The compiler controls which attributes and relationships appear. The model retains
reported declarations, nesting, extensions, conformances, generic constraints,
requirements/default implementation relationships, availability, rename metadata,
macro declarations, concurrency tokens, raw comments, locations and precise IDs.
Missing observations remain explicit. Binary and system SwiftPM targets are
structure-only until an explicit binary or header input is selected. Neither
Objective-C extraction nor macro declaration extraction implies macro expansion,
Swift imported API parity, runtime behavior or witness inference.

All dependencies of the shipped package are owned local targets. No branch or
revision package dependency, compiler library, SymbolKit, source index or syntax
parser is linked. DocC runs directly against compiler-produced library graphs.
