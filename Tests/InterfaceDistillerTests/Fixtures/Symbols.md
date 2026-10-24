# Interface symbols

Snapshot: `91ed0e82415c958a38c57f6851c995673b89422d9c139c83537ad8e0c0ff9351`

## Configuration `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`

    {"buildMode":"debug","conditions":[],"deploymentTarget":"fixture-floor","environment":{},"extractorVersion":"0.1.2","languageMode":"6","sdk":"fixture-sdk","toolchain":"fixture compiler","traits":[],"triple":"fixture-target"}

Scope:

    {"exclude":[],"include":[],"includeSPI":true,"modules":[],"sourceLocations":false}

Expected modules: SnapshotExample.\
Collected modules: SnapshotExample.

<a id="symbol-c3cb109e5ae50e9c50f1db00179f9fa8b4eecb70c827b3a25d59ae98214b9457"></a>

## SnapshotExample.Item

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample4ItemV`

    struct Item

A named value.

<a id="symbol-7113bb4854ee636808d6f735f73efae9cca7f8b2412bf98c3c06b53d5edb18fc"></a>

## SnapshotExample.Named

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5NamedP`

    protocol Named : Sendable

A value that can supply its display name.

<a id="symbol-5e9db876db61f4a23874642b71e048a4e555e727e07d196363e8304f1d10939c"></a>

## SnapshotExample.Shelf

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5ShelfV`

    struct Shelf<T> where T : Named

A generic collection.

References: [Named](part-000001.md#symbol-7113bb4854ee636808d6f735f73efae9cca7f8b2412bf98c3c06b53d5edb18fc)

<a id="symbol-0daf095e9140b8788ffa473818e010a6e509e8f5b5c37733c10b32919ac31dd3"></a>

## SnapshotExample.Store

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5StoreC`

    @MainActor final class Store

<a id="symbol-b864b1068e485f0f1594e373834083035f9b10afc4ecd20e430e0bf357e0879c"></a>

## SnapshotExample.OldItem

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample7OldItema`

    typealias OldItem = Item

References: [Item](part-000001.md#symbol-c3cb109e5ae50e9c50f1db00179f9fa8b4eecb70c827b3a25d59ae98214b9457)

<a id="symbol-638f3304a9a7f2184c4445a3972f3ef53c1fe59852358b6929bc22f582b26067"></a>

## SnapshotExample.inspect()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample7inspectSSyF`

    func inspect() -> String

<a id="symbol-119896d538c629d1625089d60f6585efe0359c19ddced166c65078ad3a30ca19"></a>

## SnapshotExample.init()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5StoreCACycfc`

    @MainActor init()

<a id="symbol-8b1f9c934ede89982385f77bce7306ac47f07de4ca32191048a27a4271fa9073"></a>

## SnapshotExample.name

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample4ItemV4nameSSvp`

    let name: String

The display name.

<a id="symbol-91af88e30615b28f7161b44705d0f1caf0aa7953665a06d041a5a75f2045580f"></a>

## SnapshotExample.item

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5ShelfV4itemxvp`

    var item: T

<a id="symbol-bdc7a2c1a7784620e1f6f85b83938058346ba3186b8fbb68fddabc992385d474"></a>

## SnapshotExample.make()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample4ItemV4makeACyFZ`

    static func make() -> Item

References: [Item](part-000001.md#symbol-c3cb109e5ae50e9c50f1db00179f9fa8b4eecb70c827b3a25d59ae98214b9457)

<a id="symbol-431d317b90c6ebb963cd14f161f17b42df4d0b88c3886a21f96a7f8dc8ec3aa0"></a>

## SnapshotExample.name

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5NamedP4nameSSvp`

    var name: String { get }

The display name.

<a id="symbol-9bf17cd72b86212ef981bc18a6bf9eeeaadecec45fe2d1715a2b489a7ba6e653"></a>

## SnapshotExample.init(_:)

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5ShelfVyACyxGxcfc`

    init(_ item: T)

References: [Named](part-000001.md#symbol-7113bb4854ee636808d6f735f73efae9cca7f8b2412bf98c3c06b53d5edb18fc)

<a id="symbol-a1e7ae502ee27b9b738275bc5846aea155c71703f3c899440e6fa767699b8d2a"></a>

## SnapshotExample.init(name:)

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample4ItemV4nameACSS_tcfc`

    init(name: String)

<a id="symbol-c4e3bfc883f100eb9ebbcc0b00876a933429c51c0c4036b0c63953de164a57dc"></a>

## SnapshotExample.label

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5NamedPAAE5labelSSvp`

    var label: String { get }

A default label.

<a id="symbol-a748bdf27e03f7d7826562cfc155ff1beef6448403f94e2c9fa9ebc73977b218"></a>

## SnapshotExample.load()

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5StoreC4loadAA4ItemVyYaKF`

    @MainActor func load() async throws -> Item

References: [Item](part-000001.md#symbol-c3cb109e5ae50e9c50f1db00179f9fa8b4eecb70c827b3a25d59ae98214b9457)

<a id="symbol-33d206c0e8210586a2e66945becf1ee33d61e4b250e47126c767f16490a893f2"></a>

## SnapshotExample.names

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:Sa15SnapshotExampleAA4ItemVRszlE5namesSaySSGvp`

    var names: [String] { get }

References: [Item](part-000001.md#symbol-c3cb109e5ae50e9c50f1db00179f9fa8b4eecb70c827b3a25d59ae98214b9457)

<a id="symbol-c3c8212246b744da75fd9add12f39bb9686635db4531adaf14ac8aa054828b27"></a>

## SnapshotExample.Array

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:e:s:Sa15SnapshotExampleAA4ItemVRszlE5namesSaySSGvp`

    extension Array where Element == Item

References: [Item](part-000001.md#symbol-c3cb109e5ae50e9c50f1db00179f9fa8b4eecb70c827b3a25d59ae98214b9457)

<a id="symbol-82d30489801a2bddc4eed19696bd6291be29b1b2073972b5fc4638f03e5956dc"></a>

## SnapshotExample.firstName

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5ShelfVA2A4ItemVRszrlE9firstNameSSvp`

    var firstName: String { get }

References: [Item](part-000001.md#symbol-c3cb109e5ae50e9c50f1db00179f9fa8b4eecb70c827b3a25d59ae98214b9457)

<a id="symbol-a566b2c3022527912ba2bcdb18719455d41052aabfa35301b9569331386ae7dc"></a>

## SnapshotExample.label

Configuration: `0e1abf758760d6207f10aba38227a76627d334098304d73969a0ed4652606e26`\
Compiler identifier: `s:15SnapshotExample5NamedPAAE5labelSSvp::SYNTHESIZED::s:15SnapshotExample4ItemV`

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
