# Interface evidence

Snapshot: `40f3bc887f4d72ce91d00dd84c2d9324675b37d2208601f4e87ca2e5b759c8de`

## Configuration `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`

    {"buildMode":"debug","conditions":[],"deploymentTarget":"fixture-floor","environment":{},"extractorVersion":"0.1.2","languageMode":"6","sdk":"fixture-sdk","toolchain":"fixture compiler","traits":[],"triple":"fixture-target"}

Scope:

    {"exclude":[],"include":[],"includeSPI":true,"modules":[],"sourceLocations":false}

Expected modules: EvidenceExample.  
Collected modules: EvidenceExample.

<a id="symbol-fc7312365108697d309d32b5e940577caf7d553a08ee7bfa85d5faec9a0562ea"></a>

## EvidenceExample.Item

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample4ItemV`

    struct Item

A named value.

<a id="symbol-4125d3284570c1703c66db398e7d955f37e65061d83b1a4480496f71f6284826"></a>

## EvidenceExample.Named

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5NamedP`

    protocol Named : Sendable

A value that can supply its display name.

<a id="symbol-bc3d4f144b3a1422c353e3af71f0387041206275ff02314dceded19003e4367a"></a>

## EvidenceExample.Shelf

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5ShelfV`

    struct Shelf<T> where T : Named

A generic collection.

References: [Named](part-000001.md#symbol-4125d3284570c1703c66db398e7d955f37e65061d83b1a4480496f71f6284826)

<a id="symbol-f298d72f692cd9308975de5394aa5f7d85a5110108ebbb2ce0e482853238c17f"></a>

## EvidenceExample.Store

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5StoreC`

    @MainActor final class Store

<a id="symbol-ff906746e0c9dc47a1ad5b76c3fad3614c92afe3dfbaa72416c02114fc80dc81"></a>

## EvidenceExample.OldItem

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample7OldItema`

    typealias OldItem = Item

References: [Item](part-000001.md#symbol-fc7312365108697d309d32b5e940577caf7d553a08ee7bfa85d5faec9a0562ea)

<a id="symbol-08ed63505007bc1fde151bc4421059b352d927a958dc507e00ec451d8686889e"></a>

## EvidenceExample.inspect()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample7inspectSSyF`

    func inspect() -> String

<a id="symbol-b9000ed51f1b712d77f1cb556f1255edcc396ac8c70aa9e14f1bdc28a406e37e"></a>

## EvidenceExample.init()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5StoreCACycfc`

    @MainActor init()

<a id="symbol-c96632446a264f5cba598b677bfeb12325b54757fa38b1d63f4a0627dd690541"></a>

## EvidenceExample.name

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample4ItemV4nameSSvp`

    let name: String

The display name.

<a id="symbol-8f0596f4024c9fdfda3e8c1dc2dced2657997e76dca861d611a64682931e0e2a"></a>

## EvidenceExample.item

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5ShelfV4itemxvp`

    var item: T

<a id="symbol-adeb3230963a11a9048d5b27f30a75387a3bfc2618064f926d8b6211245a9c99"></a>

## EvidenceExample.make()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample4ItemV4makeACyFZ`

    static func make() -> Item

References: [Item](part-000001.md#symbol-fc7312365108697d309d32b5e940577caf7d553a08ee7bfa85d5faec9a0562ea)

<a id="symbol-fbd80763ba058e4515912705c406005e6dd57bb965ac25c57e2d0e264b04e1d6"></a>

## EvidenceExample.name

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5NamedP4nameSSvp`

    var name: String { get }

The display name.

<a id="symbol-4ed5a63c3fcf7d6631abb7dd1bda3d916f68204c086fb1977052156a3bbaf5c2"></a>

## EvidenceExample.init(_:)

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5ShelfVyACyxGxcfc`

    init(_ item: T)

References: [Named](part-000001.md#symbol-4125d3284570c1703c66db398e7d955f37e65061d83b1a4480496f71f6284826)

<a id="symbol-4eb2b3bee4cfe6fa8b38c2109fbeb6466172b14958637c2c47a4b4bec9322c16"></a>

## EvidenceExample.init(name:)

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample4ItemV4nameACSS_tcfc`

    init(name: String)

<a id="symbol-6272d4e4e74f552f8d0e4780d86cf3ef66d6268d2d08023d6a85501db98328ea"></a>

## EvidenceExample.label

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5NamedPAAE5labelSSvp`

    var label: String { get }

A default label.

<a id="symbol-47cbb2a55bb977d195ee45193b6de0ace85057e8706e5e904539d7cef67f24d8"></a>

## EvidenceExample.load()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5StoreC4loadAA4ItemVyYaKF`

    @MainActor func load() async throws -> Item

References: [Item](part-000001.md#symbol-fc7312365108697d309d32b5e940577caf7d553a08ee7bfa85d5faec9a0562ea)

<a id="symbol-2afb765f35ab0c9b233a00f6db09957ab0f5cc31566c8017d8412ce9372a74ad"></a>

## EvidenceExample.names

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:Sa15EvidenceExampleAA4ItemVRszlE5namesSaySSGvp`

    var names: [String] { get }

References: [Item](part-000001.md#symbol-fc7312365108697d309d32b5e940577caf7d553a08ee7bfa85d5faec9a0562ea)

<a id="symbol-401b1d082380bb4ef6090a876d9cf50391a25cd897f5ff9859227ae8edaf66af"></a>

## EvidenceExample.Array

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:e:s:Sa15EvidenceExampleAA4ItemVRszlE5namesSaySSGvp`

    extension Array where Element == Item

References: [Item](part-000001.md#symbol-fc7312365108697d309d32b5e940577caf7d553a08ee7bfa85d5faec9a0562ea)

<a id="symbol-e66f89f10edf83cf535d969035377382ff372a309fc56bc6a47f2840639e532f"></a>

## EvidenceExample.firstName

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5ShelfVA2A4ItemVRszrlE9firstNameSSvp`

    var firstName: String { get }

References: [Item](part-000001.md#symbol-fc7312365108697d309d32b5e940577caf7d553a08ee7bfa85d5faec9a0562ea)

<a id="symbol-61476fcb9539e2ab0bf3c26684165778571abb4b4814bfca6204d26197f28d2d"></a>

## EvidenceExample.label

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`  
Compiler identifier: `s:15EvidenceExample5NamedPAAE5labelSSvp::SYNTHESIZED::s:15EvidenceExample4ItemV`

    var label: String { get }

A default label.

### Collection observation: unresolved

s:SS

Referenced compiler identifier is outside collected symbols

### Collection observation: unresolved

s:Sa

Referenced compiler identifier is outside collected symbols

### Collection observation: unresolved

s:ScM

Referenced compiler identifier is outside collected symbols

### Collection observation: unresolved

s:s8SendableP

Referenced compiler identifier is outside collected symbols

### Collection observation: unresolved

s:Sa

Relationship target is outside collected symbols

### Collection observation: unresolved

s:s16SendableMetatypeP

Relationship target is outside collected symbols

### Collection observation: unresolved

s:s8SendableP

Relationship target is outside collected symbols

