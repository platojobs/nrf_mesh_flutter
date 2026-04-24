// pigeon/mesh_api.dart

import 'package:pigeon/pigeon.dart';

// Pigeon message definitions for nRF Mesh Flutter plugin

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform_interface/pigeon_generated.dart',
  swiftOut: 'ios/Classes/PigeonGenerated.swift',
  objcHeaderOut: 'ios/Classes/PigeonGenerated.h',
  objcSourceOut: 'ios/Classes/PigeonGenerated.m',
  kotlinOut: 'android/src/main/kotlin/com/platojobs/nrf_mesh/PigeonGenerated.kt',
  kotlinOptions: KotlinOptions(package: 'com.platojobs.nrf_mesh'),
  dartPackageName: 'nrf_mesh_flutter',
))
@HostApi()
abstract class MeshApi {
  // Network management
  MeshNetwork createNetwork(String name);
  MeshNetwork loadNetwork();
  bool saveNetwork();
  bool exportNetwork(String path);
  bool importNetwork(String path);

  // Device scanning
  void startScan();
  void stopScan();

  // Provisioning
  ProvisionedNode provisionDevice(
    FlutterUnprovisionedDevice device,
    ProvisioningParameters params,
  );

  /// Provide user input required by Output OOB (numeric).
  ///
  /// Used when provisioning emits an OOB input request that requires the user to enter a value
  /// shown on the device.
  bool provideProvisioningOobNumeric(String deviceId, int value);

  /// Provide user input required by Output OOB (alphanumeric).
  bool provideProvisioningOobAlphaNumeric(String deviceId, String value);

  // Message sending
  void sendMessage(MeshMessage message);

  // Node management
  List<ProvisionedNode> getNodes();
  void removeNode(String nodeId);

  // Group management
  MeshGroup createGroup(String name);
  List<MeshGroup> getGroups();
  void addNodeToGroup(String nodeId, String groupId);

  // M2: Configuration foundation
  //
  // These APIs make configuration flows deterministic by ensuring that
  // composition data and keys exist in the Mesh DB before binding/sub/pub.

  /// Fetch Composition Data for a given node and persist it in the Mesh DB.
  ///
  /// - `destination`: the node's unicast address.
  /// - `page`: Composition Data Page (typically 0).
  ///
  /// Returns `true` when the operation completed successfully.
  bool fetchCompositionData(int destination, {int page = 0});

  /// Add (or update) an AppKey in the Mesh DB.
  ///
  /// - `appKeyIndex`: 0..4095
  /// - `keyHex`: 16-byte (128-bit) key in hex (32 chars, case-insensitive).
  bool addAppKey(int appKeyIndex, String keyHex);

  /// Add (or update) a Network Key in the Mesh DB.
  ///
  /// - `netKeyIndex`: 0..4095
  /// - `keyHex`: 16-byte (128-bit) key in hex (32 chars).
  bool addNetworkKey(int netKeyIndex, String keyHex);

  /// Return the current network keys as seen by the native Mesh DB.
  List<NetworkKey> getNetworkKeys();

  /// Return the current application keys as seen by the native Mesh DB.
  List<AppKey> getAppKeys();

  // Configuration (P1 - minimal)
  //
  // Note: These APIs are intentionally minimal and model-agnostic.
  // They are designed to map to Config Model operations on native platforms.

  /// Bind an AppKey to a model on a given element address.
  bool bindAppKey(int elementAddress, int modelId, int appKeyIndex);

  /// Unbind an AppKey from a model on a given element address.
  bool unbindAppKey(int elementAddress, int modelId, int appKeyIndex);

  /// Add a subscription address to a model on a given element address.
  bool addSubscription(int elementAddress, int modelId, int address);

  /// Remove a subscription address from a model on a given element address.
  bool removeSubscription(int elementAddress, int modelId, int address);

  /// Set publication for a model on a given element address.
  bool setPublication(
    int elementAddress,
    int modelId,
    int publishAddress,
    int appKeyIndex, {
    int? ttl,
  });

  // Proxy (P1 real-transport prerequisite)
  bool connectProxy(String deviceId, int proxyUnicastAddress);
  bool disconnectProxy();
  bool isProxyConnected();

  // Provisioning bearer (PB-GATT) connection (foundation for full provisioning).
  bool connectProvisioning(String deviceId);
  bool disconnectProvisioning();
  bool isProvisioningConnected();

  /// Whether the native implementation can reliably populate `MeshMessage.address`
  /// (source address) for incoming Access messages.
  bool supportsRxSourceAddress();

  /// Clear persisted secure mesh state used for stable Access message sending.
  ///
  /// Intended for debugging and recovery (e.g. when switching Mesh DBs).
  void clearSecureStorage();

  /// Enable/disable experimental RX metadata extraction on Android.
  ///
  /// When enabled, Android may use internal APIs (via reflection) to extract the
  /// source address for incoming Access messages. When disabled, Android will
  /// use only public APIs and `MeshMessage.address` may be null.
  ///
  /// On iOS this is a no-op.
  void setExperimentalRxMetadataEnabled(bool enabled);
}

@FlutterApi()
abstract class MeshFlutterApi {
  void onDeviceDiscovered(FlutterUnprovisionedDevice device);
  void onMessageReceived(MeshMessage message);

  /// A richer, forward-compatible RX event that carries best-effort metadata.
  ///
  /// This stream is controlled by this plugin's contract (rather than relying on
  /// internal/native library details) so apps can build stable logging and routing.
  void onRxAccessMessage(RxAccessMessage event);

  /// Provisioning lifecycle events (progress + OOB prompts).
  void onProvisioningEvent(ProvisioningEvent event);
}

// Data models
class MeshNetwork {
  String? networkId;
  String? name;
  List<NetworkKey>? networkKeys;
  List<AppKey>? appKeys;
  List<ProvisionedNode>? nodes;
  List<MeshGroup>? groups;
  Provisioner? provisioner;
}

class NetworkKey {
  String? keyId;
  String? key;
  int? index;
  bool? enabled;
}

class AppKey {
  String? keyId;
  String? key;
  int? index;
  bool? enabled;
}

class Provisioner {
  String? name;
  String? provisionerId;
  List<int>? addressRange;
}

/// Pigeon transport model for unprovisioned devices.
///
/// Named to avoid clashing with Nordic iOS library types.
class FlutterUnprovisionedDevice {
  String? deviceId;
  String? name;
  int? rssi;
  List<int>? uuid;
  String? serviceUuid;
}

class ProvisionedNode {
  String? nodeId;
  String? name;
  int? unicastAddress;
  List<int>? uuid;
  List<Element>? elements;
  bool? provisioned;
}

class Element {
  int? address;
  List<Model>? models;
}

class Model {
  int? modelId;
  String? modelName;
  bool? publishable;
  bool? subscribable;
  List<int>? boundAppKeyIndexes;
  List<int>? subscriptions;
  Publication? publication;
}

class Publication {
  int? address;
  int? appKeyIndex;
  int? ttl;
}

class MeshGroup {
  String? groupId;
  String? name;
  int? address;
  List<String>? nodeIds;
}

class MeshMessage {
  int? opcode;
  int? address;
  int? appKeyIndex;
  Map<String, Object?>? parameters;
}

enum RxMetadataStatus {
  available,
  unavailable,
}

class RxAccessMessage {
  int? opcode;

  /// Access message parameters (raw bytes).
  List<int>? parameters;

  /// Best-effort source address (unicast), if available.
  int? source;

  /// Best-effort destination address, if available.
  int? destination;

  RxMetadataStatus? metadataStatus;
}

class ProvisioningParameters {
  String? deviceName;
  int? oobMethod;
  String? oobData;
  bool? enablePrivacy;
}

enum ProvisioningEventType {
  started,
  capabilitiesReceived,
  oobInputRequested,
  oobOutputRequested,
  provisioningCompleted,
  failed,
}

class ProvisioningEvent {
  String? deviceId;
  ProvisioningEventType? type;
  String? message;
  int? progress; // 0..100 best-effort
  int? attentionTimer;
}

class GenericOnOffSet {
  bool? state;
  int? transitionTime;
  int? delay;
}

class GenericLevelSet {
  int? level;
  int? transitionTime;
  int? delay;
}
