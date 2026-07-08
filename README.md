# nRF Mesh Flutter Plugin

A Flutter plugin for Bluetooth Mesh networking, based on Nordic Semiconductor's nRF Mesh libraries ([iOS](https://github.com/NordicSemiconductor/IOS-nRF-Mesh-Library) / Android Kotlin Mesh).

## Features

- **Network Management**: Create, load, save, export, and import mesh networks
- **Device Provisioning**: Provision unprovisioned devices into the mesh network
- **Device Scanning**: Scan for nearby unprovisioned BLE devices
- **Message Communication**: Send and receive mesh messages
- **Node Management**: Manage provisioned nodes in the network
- **Group Management**: Create and manage mesh groups
- **Standard Models**: Support for Generic On/Off, Light, and other standard BLE Mesh models

## Supported Platforms

- **iOS**: 13.0+
- **Android**: API 24+ (Android 7.0 Nougat)

## Installation

Add `nrf_mesh_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  nrf_mesh_flutter: ^6.10.1
```

## Release notes language

Release notes in `CHANGELOG.md` are maintained in **English only**.

## Dependency policy

**Avoid adding new third-party Dart dependencies** unless they are strictly required for Bluetooth Mesh interoperability or the Flutter plugin contract.

- **Prefer** the Dart / Flutter SDK (`dart:*`, `package:flutter/...`) and small **in-repo** utilities (for example **`debounceMeshNetworkUpdates`** uses only **`dart:async`**).
- **Runtime** packages today (`convert`, `crypto`, `pointycastle`, `plugin_platform_interface`, `meta`) exist for encoding/hashing/AES-CMAC and platform abstraction; expanding this set should include a **CHANGELOG rationale** and stay minimal.
- **Development** dependencies are intentionally narrow: **`flutter_test`**, **`flutter_lints`**, and **`pigeon`** — do not pull in extra pub packages for tests or tooling convenience.

## Recommended: sending raw Access messages

If you need to send vendor/custom messages (or want to avoid the implicit `parameters['bytes']` convention), prefer `sendAccess(...)`:

```dart
await PlatoJobsNrfMeshManager.instance.sendAccess(
  opCode: 0x8202, // example: Generic OnOff Set (ack)
  parameters: const [0x01, 0x01], // payload bytes
  address: 0x0003, // destination (unicast/group/virtual)
  appKeyIndex: 0,
);
```

### Incoming messages (Phase 0 baseline)

Incoming Access PDUs are surfaced on:

| Stream | Model | Typical contents |
|--------|--------|------------------|
| `messageStream` | `MeshMessage` | `opcode`, `parameters['bytes']`, `address` (**source** unicast when known) |
| `rxAccessMessageStream` | `RxAccessMessage` | `opcode`, `parameters`, `source`, `destination`, `metadataStatus` |

#### Receive path inventory (Phase 0.1)

| Surface | Opcode / payload | Source | Destination | RX AppKey index | Network TTL | Platform notes |
|---------|------------------|--------|-------------|-----------------|-------------|----------------|
| `messageStream` | `opcode` + `parameters['bytes']` | `MeshMessage.address` (incoming) | — | always **`null` today** | not exposed | Matches Access payload after decode |
| `rxAccessMessageStream` | `opcode` + `parameters` | `RxAccessMessage.source` | `RxAccessMessage.destination` | always **`null` today** (Phase **1.4**) | not exposed | Use `metadataStatus` when fields absent |
| `provisioningEventStream` | `ProvisioningEventType` + text fields | `deviceId` | — | — | — | **Not** Access-layer RX |
| `meshNetworkUpdatedStream` | monotonic `int` sequence | — | — | — | — | DB lifecycle hint, not a mesh PDU |

#### Platform gaps (Phase 0.2)

- **Inbound Application Key index** on receive: **not** forwarded on Android or iOS today → tracked as **Phase 1.4** (nullable + docs / capability when stacks align). Query **`supportsRxAppKeyIndex()`** — it returns **`false`** until native metadata is wired.
- **Network / relay TTL** on inbound PDUs: **not** exposed on either bridge path.
- **Android reflection RX path**: **`setExperimentalRxMetadataEnabled(true)`** is **deprecated** (Phase **1.3**); default Kotlin Mesh **`MeshMessageReceived`** path should be used.
- **Bluetooth Mesh Proxy Filter** driven from Flutter: **Android** now bridges the Nordic Kotlin Mesh explicit Proxy Filter controls. Query **`supportsProxyFilter()`** or **`getCapabilities()`** to detect explicit support, and query **`supportsAutomaticProxyFilter()`** to detect stacks like **iOS** where the native SDK already manages Proxy Filter automatically.

#### Phase 0.3: Guaranteed vs best-effort

This plugin aims for **the same Dart API** on Android and iOS: method names, parameter meaning, and whether a call **succeeds or throws** should match unless this README says otherwise.

| Class | Meaning |
|-------|---------|
| **Guaranteed** | **Wire contract**: Pigeon methods and stream types are stable; documented behaviors (e.g. **`supportsRxSourceAddress()`** meaning, deprecation of experimental Android RX) are intentional. |
| **Best-effort** | **RX field completeness**: source / destination / opcode bytes may be absent when the Nordic stack or bearer does not supply them — treat **`RxMetadataStatus`** and nullability as authoritative. |
| **Best-effort** | **Topology snapshots**: `getNodes()` / `getGroups()` reflect the **native mesh DB** at query time; live RF state can diverge until you reconnect or reprovision. Use **`meshNetworkUpdatedStream`** (+ optional **`debounceMeshNetworkUpdates`**) to refresh caches after DB edits. |

Cross-platform mapping (Nordic stacks):

| Field | Android (Kotlin Mesh **1.0+**, GATT proxy session) | iOS (`nRFMeshProvision`, `MeshNetworkDelegate`) |
|-------|------------------------------------------------------|-----------------------------------------------|
| Payload | `message.parameters` | `message.parameters` |
| Source → `MeshMessage.address` / `RxAccessMessage.source` | `NetworkEvent.MeshMessageReceived.source` | `didReceiveMessage ... sentFrom source` |
| `RxAccessMessage.destination` | `MeshMessageReceived.destination` (`MeshAddress`) | Delegate `to destination` |

**Portable Dart code**: keep **null-safe** handling for `address`, `source`, and `destination` (legacy paths, bearers, or transient states may omit them).

**Android**: `supportsRxSourceAddress()` reflects whether the active bridge populates source for incoming traffic (public `networkEvents` path on Kotlin Mesh 1.0+). Legacy reflection tuning via `setExperimentalRxMetadataEnabled` is **deprecated** (Phase 1.3); enabling it logs **`Log.w`** on Android.

**iOS**: `supportsRxSourceAddress()` is `true` when the mesh delegate delivers `sentFrom`.

Optional inbound metadata (**AppKey index** on receive, richer TTL/network fields, etc.) belongs to **Phase 1.4** in the [Roadmap (planning checklist)](#roadmap-planning-checklist)—implemented only when Nordic stacks expose it consistently or documented as platform-specific.

### Mesh DB change hints (Phase 2)

When the native mesh configuration database may have changed (nodes, groups, keys, provisioning saves, etc.), the plugin emits on **`meshNetworkUpdatedStream`**. Each event is a monotonically increasing **`int`** sequence number—apps typically debounce and then refresh `getNodes()` / `getGroups()` / key APIs as needed. For a dependency-free debounce, use **`debounceMeshNetworkUpdates`** from this package (Phase **2.2** helper).

| Platform | Typical trigger |
|----------|-----------------|
| Android (Kotlin Mesh) | `NetworkEvent.NetworkUpdated` from `networkEvents` |
| iOS (`nRFMeshProvision`) | After successful `MeshNetworkManager.save()` and after loads / imports that affect the DB |

### Roadmap (planning checklist)

Product parity work is tracked **by phase 0–5** below (not by release tags). The technical sections [Incoming messages (Phase 0 baseline)](#incoming-messages-phase-0-baseline) and [Mesh DB change hints (Phase 2)](#mesh-db-change-hints-phase-2) are **part of** those phases.

#### Acceptance principles

1. **Same Dart API semantics on Android and iOS**: success vs failure, parameter meaning, and **stream field meanings** must align unless explicitly documented otherwise.
2. **When parity is impossible**: call it out in docs and/or **`RxMetadataStatus`** / a dedicated enum—**no silent behavioral forks** between platforms.
3. **Each milestone** should ship **Pigeon changes** (when applicable), an **example page or integration test**, and a **CHANGELOG** entry.

#### Phase 0 — Baseline & documentation (~1–2 days)

| ID | Item | Deliverable |
|----|------|-------------|
| **0.1** | Inventory receive/uplink paths: `messageStream`, `rxAccessMessageStream`, provisioning callbacks | Comparison table (opcode, bytes, source, destination, appKey, TTL, …) |
| **0.2** | Check whether iOS can achieve **Android `MeshMessageReceived`-grade** source/destination | Written gap list |
| **0.3** | README «platform differences»: what is **guaranteed** vs **best-effort** | [Phase 0.3: Guaranteed vs best-effort](#phase-03-guaranteed-vs-best-effort) — overlaps inventory tables; extend when stacks change |

#### Phase 1 — Receive-path parity (high priority, ~1–2 weeks)

| ID | Item | Android | iOS | Acceptance |
|----|------|---------|-----|------------|
| **1.1** | Align **`MeshMessage.address`** with **`RxAccessMessage.source` / `destination`** semantics | Uses `NetworkEvent.MeshMessageReceived` source & destination on Kotlin Mesh 1.0+ | `MeshNetworkDelegate` path supplies source & destination | Same opcode fixture → same reported source in integration/unit coverage where feasible |
| **1.2** | **`supportsRxSourceAddress()`** matches reality | `true` on default `networkEvents` receive path | `true` when delegate delivers `sentFrom` | Tests or assertions on representative builds |
| **1.3** | Deprecate / demote Android **reflection experimental** RX path | **`setExperimentalRxMetadataEnabled` deprecated** + **`Log.w`** when enabled (6.9.4); default public API | N/A | Default CI build **without** reflection dependency |
| **1.4** | **Inbound `appKeyIndex`** (optional) | Evaluate Kotlin Mesh / security APIs | Evaluate delegate/callback surface | **`supportsRxAppKeyIndex()`** reflects capability; **same semantics if filled**; otherwise document + nullable fields |

#### Phase 2 — Network lifecycle (~1–2 weeks, medium priority)

| ID | Item | Android | iOS | Acceptance |
|----|------|---------|-----|------------|
| **2.1** | **`NetworkUpdated`-class signal** to Flutter | `networkEvents` → `NetworkUpdated` | Save/load/import/reset-driven notify (current bridge) | **`meshNetworkUpdatedStream`** (today: monotonic `int` seq); optional future: reasons / `Stream<void>` |
| **2.2** | **Debounce & merge** (avoid event storms) | App/plugin policy | Same | Example + **`debounceMeshNetworkUpdates`**: debounced refresh drives `getNodes()` / `getGroups()` consistently |

**Current plugin note:** **2.1** is implemented end-to-end; **2.2** ships **`debounceMeshNetworkUpdates`** and the example uses it; **centralized coalescing inside the plugin** remains optional follow-up.

#### Phase 3 — Proxy & connection strategy (~2–3 weeks, medium priority, as needed)

| ID | Item | Notes |
|----|------|------|
| **3.1** | Abstract **proxy / bearer state machine** | Align Kotlin Mesh bearer vs iOS GATT proxy states → unified Dart model (`disconnected` / `connecting` / `proxyReady` / `provisioning`, …) |
| **3.2** | **Proxy Filter** (advanced subset) | **Android** exposes Nordic Kotlin Mesh explicit Proxy Filter controls; **iOS** currently reports automatic-only management |
| **3.3** | **Auto-reconnect** (optional) | Configurable policy aligned with Nordic guidance; example toggle + compliance/power warnings |

**Current plugin note:** **3.1** (partial) — **`MeshBearerSnapshot`** / **`getMeshBearerSnapshot()`** combine native **`isProxyConnected`** + **`isProvisioningConnected`** with Dart-side in-flight connect tracking into **`MeshBearerPhase`** (`disconnected` / **`proxyConnecting`** / **`proxyReady`** / **`provisioningConnecting`** / **`provisioning`**). Native Nordic probes still expose only connected / disconnected; the **connecting** phases are derived locally while connect calls are pending.

**3.2** — **Android** now reports explicit Proxy Filter support through **`supportsProxyFilter()`** / **`getCapabilities()`** (`MeshProxyFilterCapability.explicitControl`), while **iOS** continues to report **automatic** Proxy Filter management through **`supportsAutomaticProxyFilter()`** / **`getCapabilities()`** (`MeshProxyFilterCapability.automaticOnly`).

On **iOS 4.8.0**, the official library source includes `ProxyFilter`, `SetFilterType`, `AddAddressesToFilter`, and `RemoveAddressesFromFilter`, but the mutation entry points are not public across the `NordicMesh` module boundary. In practice this plugin can reliably expose **automatic-only** Proxy Filter behavior on iOS unless the upstream SDK surface changes.

#### Phase 4 — Provisioning parity (Mesh 1.1 / enhanced) (~2–4 weeks, business-driven)

| ID | Item | Notes |
|----|------|------|
| **4.1** | **Capabilities → Flutter** (OOB list, etc.) | Structured Pigeon types; Kotlin ↔ iOS symmetry |
| **4.2** | **Enhanced provisioning / Mesh 1.1** params | Follow Nordic API deltas on both stacks + capability probes |
| **4.3** | **Static / output OOB state machine** parity | Callback naming & ordering aligned; E2E provisioning tests |

#### Phase 5 — Dependencies & health (ongoing)

| ID | Item |
|----|------|
| **5.1** | Android: Kotlin Mesh + **kotlin-ble** aligned with Nordic’s recommended matrix (BOM / sample versions) |
| **5.2** | iOS: **`nRFMeshProvision`** patch bumps + Swift/Xcode compatibility; note in CHANGELOG |
| **5.3** | Dart: dependency constraints + pub health (`dart pub outdated`, dry-run before release) |

#### Suggested sequencing (shortest path to «dual-stack consistent»)

1. **Phase 1** (receive metadata + `supportsRxSourceAddress`) — highest user-visible impact.  
2. **Phase 0** docs & matrices — avoids ambiguity during Phase 1 reviews.  
3. **Phase 2** — better refresh model & power (partially delivered).  
4. **Phase 4** — only if Mesh 1.1 / advanced provisioning is required.  
5. **Phase 3** & **Phase 5** — parallel or interleaved with the above.

#### Engineering hygiene (all phases)

- Follow the **[Dependency policy](#dependency-policy)** — no new optional third-party Dart deps without strong justification.  
- Regenerate **Pigeon** / CocoaPods when `pigeon/mesh_api.dart` or native versioning changes.  
- Keep **example** pages aligned with new APIs.  
- Run **`dart pub publish --dry-run`** / **`pana`** before release.

### iOS Configuration

Add the following to your `ios/Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!
```

### Android Configuration

Add Bluetooth permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

## Quick Start

```dart
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the mesh manager
  await PlatoJobsNrfMeshManager.instance.initialize();

  runApp(const MyApp());
}
```

## Provisioning Flow (High Level)

```mermaid
flowchart TD
  A[initialize()] --> B[loadNetwork()]
  B -->|null / empty| C[createNetwork()]
  B -->|exists| D[scanForDevices()]
  C --> D
  D --> E[provisionDevice()]
  E --> F[sendMessage()]
  F --> G[messageStream]
```

## Mocking (No Hardware Needed)

For UI development without real Mesh hardware you can inject a fake bridge:

```dart
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

final fake = FakePlatoJobsMeshBridge(
  scenario: FakeMeshScenario()
      .add(
        FakeMeshScenarioStep.discoveredDevice(
          UnprovisionedDevice(
            deviceId: 'dev-1',
            name: 'Demo',
            serviceUuid: '',
            rssi: -40,
            serviceData: const <int>[1, 2, 3],
          ),
        ),
      )
      .add(
        FakeMeshScenarioStep.incomingMessage(GenericOnOffSet(state: true)),
      ),
);
PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
await PlatoJobsNrfMeshManager.instance.initialize();
```

Notes:
- Call `scanForDevices()` to start the scripted scenario (it runs once per fake instance).
- You can still push events manually with `emitDiscoveredDevice(...)` / `emitIncomingMessage(...)`.

## Usage

### Network Management

```dart
// Create a new mesh network
final network = await PlatoJobsNrfMeshManager.instance.createNetwork('My Mesh Network');

// Load an existing network
final loadedNetwork = await PlatoJobsNrfMeshManager.instance.loadNetwork();

// Save the current network
await PlatoJobsNrfMeshManager.instance.saveNetwork();

// Export network to a file
await PlatoJobsNrfMeshManager.instance.exportNetwork('/path/to/export.json');

// Import network from a file
await PlatoJobsNrfMeshManager.instance.importNetwork('/path/to/import.json');
```

### Device Scanning

```dart
// Start scanning for unprovisioned devices
StreamSubscription<UnprovisionedDevice> subscription =
    PlatoJobsNrfMeshManager.instance.scanForDevices().listen((device) {
  print('Discovered: ${device.name} (${device.deviceId})');
});

// Stop scanning
await PlatoJobsNrfMeshManager.instance.stopScan();

// Cancel subscription when done
await subscription.cancel();
```

### Device Provisioning

```dart
// Provision a device
final node = await PlatoJobsNrfMeshManager.instance.provisionDevice(
  device,
  ProvisioningParameters(
    deviceName: 'My Device',
    oobMethod: 0,
    enablePrivacy: false,
  ),
);
```

### Sending Messages

```dart
// Send a Generic On/Off message
await PlatoJobsNrfMeshManager.instance.sendMessage(
  GenericOnOffSet(
    state: true,
    transitionTime: 0,
    delay: 0,
    address: 0xC000, // e.g. group address or node unicast
    appKeyIndex: 0,
  ),
);

// Listen for incoming messages
PlatoJobsNrfMeshManager.instance.messageStream.listen((message) {
  print('Received message: ${message.opcode}');
});
```

### Node Management

```dart
// Get all provisioned nodes
final nodes = await PlatoJobsNrfMeshManager.instance.getNodes();

// Remove a node
await PlatoJobsNrfMeshManager.instance.removeNode(nodeId);
```

### Group Management

```dart
// Create a new group
final group = await PlatoJobsNrfMeshManager.instance.createGroup('Living Room');

// Get all groups
final groups = await PlatoJobsNrfMeshManager.instance.getGroups();

// Add a node to a group
await PlatoJobsNrfMeshManager.instance.addNodeToGroup(nodeId, groupId);
```

## API Reference

### Core Class

#### `PlatoJobsNrfMeshManager`

The main entry point for the plugin. Uses singleton pattern.

**Singleton Access:**
```dart
PlatoJobsNrfMeshManager.instance
```

**Methods:**

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize the mesh manager |
| `createNetwork(name)` | Create a new mesh network |
| `loadNetwork()` | Load an existing mesh network |
| `saveNetwork()` | Save the current mesh network |
| `exportNetwork(path)` | Export network to a JSON file |
| `importNetwork(path)` | Import network from a JSON file |
| `scanForDevices()` | Start scanning for unprovisioned devices |
| `stopScan()` | Stop scanning |
| `provisionDevice(device, params)` | Provision a device |
| `sendMessage(message)` | Send a mesh message |
| `getNodes()` | Get all provisioned nodes |
| `removeNode(nodeId)` | Remove a node |
| `createGroup(name)` | Create a new group |
| `getGroups()` | Get all groups |
| `addNodeToGroup(nodeId, groupId)` | Add a node to a group |
| `supportsRxSourceAddress()` | Whether inbound messages can include a reliable source address |
| `supportsRxAppKeyIndex()` | Whether inbound metadata can include Application Key index (**Phase 1.4**; **`false`** until native wiring) |
| `getMeshBearerSnapshot()` | Phase **3.1**: **`MeshBearerPhase`** from native proxy vs provisioning connection flags |
| `supportsProxyFilter()` | Phase **3.2**: whether explicit Proxy Filter controls are available (**Android**: yes, **iOS**: no) |
| `supportsAutomaticProxyFilter()` | Whether the native SDK already manages Proxy Filter automatically |
| `setProxyFilterType(type)` | Phase **3.2**: set explicit Proxy Filter type (`whitelist` / `blacklist`) |
| `addProxyFilterAddresses(addresses)` | Phase **3.2**: add addresses to the explicit Proxy Filter list |
| `removeProxyFilterAddresses(addresses)` | Phase **3.2**: remove addresses from the explicit Proxy Filter list |
| `getCapabilities()` | Aggregated feature snapshot: RX source, RX AppKey index, and Proxy Filter support level (`unsupported` / `automaticOnly` / `explicitControl`) |

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `messageStream` | `Stream<MeshMessage>` | Stream of received mesh messages |
| `meshNetworkUpdatedStream` | `Stream<int>` | Hint when native mesh DB may have changed (refresh topology caches) |

### Data Models

#### `MeshBearerSnapshot` / `MeshBearerPhase` (Phase 3.1)

Portable snapshot of **mesh-proxy vs PB-GATT provisioning** bearer activity. Built by querying native **`isProxyConnected`** and **`isProvisioningConnected`** together, then overlaying local pending connect state so apps can render **connecting** UX without forking Android vs iOS logic.

#### `MeshNetwork`

Represents a Bluetooth Mesh network.

**Properties:**
- `networkId`: Unique network identifier
- `name`: Network name
- `networkKeys`: List of network keys
- `appKeys`: List of application keys
- `nodes`: List of provisioned nodes
- `groups`: List of mesh groups
- `provisioner`: Network provisioner info

#### `ProvisionedNode`

Represents a provisioned mesh node.

**Properties:**
- `uuid`: Node UUID
- `unicastAddress`: Node unicast address
- `elements`: List of elements
- `networkKeys`: List of network keys
- `appKeys`: List of application keys
- `features`: Node features (relay, proxy, friend, low power)

#### `UnprovisionedDevice`

Represents a discovered unprovisioned device.

**Properties:**
- `deviceId`: Device identifier
- `name`: Device name
- `serviceUuid`: Service UUID
- `rssi`: Signal strength
- `serviceData`: Service data from advertising packets

#### `MeshGroup`

Represents a mesh group.

**Properties:**
- `groupId`: Group identifier
- `name`: Group name
- `address`: Group address
- `nodeIds`: List of node IDs in the group

#### `MeshMessage`

Base class for mesh messages.

**Properties:**
- `opcode`: Message opcode
- `parameters`: Message parameters

## Architecture

The plugin follows a layered architecture:

```
┌─────────────────────────────────┐
│         Dart Layer              │
│  (PlatoJobsNrfMeshManager)      │
├─────────────────────────────────┤
│     Platform Interface          │
│  (PlatoJobsMeshPlatform)        │
├─────────────────────────────────┤
│   Pigeon Generated Code          │
│  (Auto-generated codec)          │
├─────────────────────────────────┤
│     Native Layer                 │
│  (Swift / Kotlin)                │
├─────────────────────────────────┤
│   Nordic nRF Mesh Library        │
│  (iOS / Android)                │
└─────────────────────────────────┘
```

## Dependencies

### Flutter Dependencies

- `plugin_platform_interface: ^2.1.8` - Platform interface support
- `convert: ^3.1.2` - JSON/codecs helpers
- `crypto: ^3.0.7` - Cryptographic hashing helpers
- `meta: ^1.17.0` - Annotations
- `pointycastle: ^4.0.0` - AES-CMAC support for Bluetooth Mesh virtual addresses

### Native Dependencies

- **iOS**: `nRFMeshProvision ~> 4.8.0`
- **Android**: Nordic Kotlin Mesh Library `1.0.0` (`core`, `bearer`, `bearer-gatt`, `bearer-pbgatt`, `bearer-provisioning`, `provisioning`) plus `no.nordicsemi.kotlin.ble:client-android:2.0.0-alpha19`

## Error Handling

All async methods may throw `PlatoJobsMeshException` (a readable wrapper over platform errors, timeouts, and common BLE failures).

```dart
try {
  await PlatoJobsNrfMeshManager.instance.initialize();
} on PlatoJobsMeshException catch (e) {
  // e.g. permission / connection / timeout / invalid state
  print('Mesh error: $e');
}
```

## Android 12+ / 14+ Notes

- Android 12+ needs runtime permissions: `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`.
- Android 13+ may require `POST_NOTIFICATIONS` if your app shows connection status in notifications (your app decides whether this is needed).
- Android 14+ background scan/connection restrictions are stricter: keep provisioning/proxy connection in a user-visible flow, and implement retry + timeouts.

## iOS 13+ / 17+ Notes

- Add Bluetooth usage descriptions to `Info.plist` (e.g. `NSBluetoothAlwaysUsageDescription`).
- iOS 17+ is more sensitive about background operations: keep mesh actions in the foreground flow where possible.

## Examples

See the `example` directory for a complete demo application demonstrating all features.

## License

MIT License - see LICENSE file for details.

## Author

**PlatoJobs**

- GitHub: [https://github.com/platojobs](https://github.com/platojobs)
- Project: [https://github.com/platojobs/nrf_mesh_flutter](https://github.com/platojobs/nrf_mesh_flutter)

## Changelog

For the full history, see [`CHANGELOG.md`](CHANGELOG.md).

### Latest

See `CHANGELOG.md` for the full history and the latest release notes.
