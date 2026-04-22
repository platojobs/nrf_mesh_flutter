# nRF Mesh Flutter Plugin

A Flutter plugin for Bluetooth Mesh networking, based on Nordic Semiconductor's nRF Mesh libraries ([iOS](https://github.com/NordicSemiconductor/IOS-nRF-Mesh-Library) / [Android](https://github.com/NordicSemiconductor/Android-nRF-Mesh-Library)).

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
- **Android**: API 21+ (Android 5.0 Lollipop)

## Installation

Add `nrf_mesh_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  nrf_mesh_flutter: ^2.0.2
```

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

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `messageStream` | `Stream<MeshMessage>` | Stream of received mesh messages |

### Data Models

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

- `plugin_platform_interface: ^2.0.2` - Platform interface support
- `convert: ^3.1.1` - JSON conversion
- `crypto: ^3.0.3` - Cryptographic functions
- `meta: ^1.10.0` - Annotations

### Native Dependencies

- **iOS**: `nRFMeshProvision ~> 4.8.0`
- **Android**: Nordic Android nRF Mesh Library

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
- Android 13+ 如果要在通知中提示连接状态，可能需要 `POST_NOTIFICATIONS`（由你的 App 决定是否需要）。
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

- **1.1.1**: Improve mocking with scripted scenarios (devices/messages) + failure injection.
- **1.1.0**: DX improvements (mock bridge + tests + permissions/background notes).
- **1.0.4**: Fix changelog ordering (latest first).
