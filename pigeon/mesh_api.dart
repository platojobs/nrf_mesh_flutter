// pigeon/mesh_api.dart

import 'package:pigeon/pigeon.dart';

// Pigeon message definitions for nRF Mesh Flutter plugin

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform_interface/pigeon_generated.dart',
    swiftOut: 'ios/Classes/PigeonGenerated.swift',
    objcHeaderOut: 'ios/Classes/PigeonGenerated.h',
    objcSourceOut: 'ios/Classes/PigeonGenerated.m',
    kotlinOut:
        'android/src/main/kotlin/com/platojobs/nrf_mesh/PigeonGenerated.kt',
    kotlinOptions: KotlinOptions(package: 'com.platojobs.nrf_mesh'),
    dartPackageName: 'nrf_mesh_flutter',
  ),
)
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

  // M3: virtual label groups + configuration to virtual address
  //
  // [labelUuid] is always 16 bytes (MSB..LSB of the 128-bit Label UUID).
  MeshGroup createVirtualGroup(String name, List<int> labelUuid);
  bool removeGroup(String groupId);
  bool addSubscriptionVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
  );
  bool removeSubscriptionVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
  );
  bool setPublicationVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
    int appKeyIndex, {
    int? ttl,
  });

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

  /// Set the Default TTL on a node.
  bool setNodeDefaultTtl(int destination, int ttl);

  /// Enable/disable Relay on a node.
  bool setNodeRelay(
    int destination,
    bool enabled,
    int retransmitCount,
    int retransmitIntervalMs,
  );

  /// Enable/disable GATT Proxy on a node.
  bool setNodeGattProxy(int destination, bool enabled);

  /// Enable/disable Friend on a node.
  bool setNodeFriend(int destination, bool enabled);

  /// Enable/disable Secure Network Beacon on a node.
  bool setNodeBeacon(int destination, bool enabled);

  /// Set Network Transmit parameters on a node.
  bool setNodeNetworkTransmit(int destination, int count, int intervalMs);

  /// Trigger a remote Node Reset.
  bool nodeReset(int destination);

  /// Export a configuration bundle to a file path.
  ///
  /// This is intended to include:
  /// - Standard Mesh DB export (Configuration Database Profile 1.0.1)
  /// - Plugin secure state when applicable (e.g. Android secure properties)
  bool exportConfigurationBundle(String path);

  /// Import a configuration bundle from a file path.
  bool importConfigurationBundle(String path);

  // M2 (closeout): remote key management + key refresh

  /// Remove a network key on a **remote** node (Config NetKey Delete).
  ///
  /// [destination] is the unicast address of the element with the Configuration Server (usually primary).
  bool removeNetworkKeyRemote(int destination, int netKeyIndex);

  /// Remove an application key on a **remote** node (Config App Key Delete).
  ///
  /// [boundNetKeyIndex] is the NetKey that the AppKey is bound to.
  bool removeAppKeyRemote(
    int destination,
    int appKeyIndex,
    int boundNetKeyIndex,
  );

  /// Read Key Refresh phase for [netKeyIndex] on a node (Config Key Refresh Phase Get).
  ///
  /// Returns `0` = normal, `1` = key distribution, `2` = using new keys, or `-1` if unavailable.
  int getKeyRefreshPhase(int destination, int netKeyIndex);

  /// Set Key Refresh phase transition (Config Key Refresh Phase Set).
  ///
  /// [transition] uses Nordic / Mesh values: `2` = use new keys, `3` = revoke old keys.
  bool setKeyRefreshPhaseTransition(
    int destination,
    int netKeyIndex,
    int transition,
  );

  /// Clears the loaded mesh, persisted plugin storage, and secure state (Android) so the app can
  /// [createNetwork] or [import] a fresh database.
  bool resetLocalMeshState();

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

  /// Whether inbound **Application Key index** can be populated on receive paths
  /// (future `RxAccessMessage` / `MeshMessage.appKeyIndex` parity — Phase 1.4).
  ///
  /// Currently **false** on Android and iOS until Nordic stacks expose it consistently.
  bool supportsRxAppKeyIndex();

  /// Whether **Bluetooth Mesh Proxy Filter** controls can be driven from Flutter (**Phase 3.2**).
  ///
  /// Currently **false** — Nordic bearer defaults apply; explicit Proxy Filter APIs are not wired yet.
  bool supportsProxyFilter();

  /// Whether the native SDK already manages Proxy Filter automatically even
  /// though Flutter cannot configure it directly.
  ///
  /// This maps to stacks such as iOS nRF Mesh where automatic proxy filter
  /// management exists before explicit Proxy Configuration APIs are bridged.
  bool supportsAutomaticProxyFilter();

  /// Sets the explicit Proxy Filter type on the connected Proxy Node.
  ///
  /// [type] uses `0 = whitelist`, `1 = blacklist`.
  bool setProxyFilterType(int type);

  /// Adds addresses to the explicit Proxy Filter list on the connected Proxy Node.
  bool addProxyFilterAddresses(List<int> addresses);

  /// Removes addresses from the explicit Proxy Filter list on the connected Proxy Node.
  bool removeProxyFilterAddresses(List<int> addresses);

  /// Clear persisted secure mesh state used for stable Access message sending.
  ///
  /// Intended for debugging and recovery (e.g. when switching Mesh DBs).
  void clearSecureStorage();

  /// **Deprecated (Phase 1.3).** Prefer Kotlin Mesh **1.0+** `networkEvents` /
  /// `MeshMessageReceived`, which populate source without reflection.
  ///
  /// When enabled, Android may use internal APIs (via reflection) for RX metadata.
  /// Fragile across Nordic releases; logs a warning when toggled on.
  ///
  /// On iOS this is a no-op.
  @Deprecated('Phase 1.3: use default public API path on Android')
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

  /// Best-effort signal that the native mesh configuration database changed.
  ///
  /// Android (Kotlin Mesh): typically emitted on ``NetworkEvent.NetworkUpdated``.
  /// iOS: emitted after successful Nordic ``MeshNetworkManager.save()`` (and related loads).
  /// Apps should treat this as a hint to refresh `getNodes()` / `getGroups()` / keys—debounce if needed.
  void onMeshNetworkUpdated();
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

  /// 16-byte Label UUID (MSB..LSB) when this is a virtual group, otherwise null/empty.
  List<int>? labelUuid;
}

class MeshMessage {
  int? opcode;
  int? address;
  int? appKeyIndex;
  Map<String, Object?>? parameters;
}

enum RxMetadataStatus { available, unavailable }

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

/// Lifecycle stages reported during PB-GATT provisioning.
enum ProvisioningEventType {
  /// Provisioning session started for the device.
  started,

  /// Device capabilities received from the provisionee.
  capabilitiesReceived,

  /// App must supply input OOB data (user-entered).
  oobInputRequested,

  /// Device is displaying output OOB data (user reads and confirms).
  oobOutputRequested,

  /// Device successfully joined the network.
  provisioningCompleted,

  /// Session ended with an error (see [ProvisioningEvent.message]).
  failed,
}

/// One provisioning lifecycle update for a single device.
///
/// Consumed from [MeshFlutterApi.onProvisioningEvent] / Dart-side provisioning streams.
class ProvisioningEvent {
  /// Native device identifier (typically BLE peripheral UUID string).
  String? deviceId;

  /// Which phase this event represents.
  ProvisioningEventType? type;

  /// Human-readable detail or error text from native code.
  String? message;

  /// Best-effort progress percent (0–100), when provided.
  int? progress;

  /// Attention timer value when relevant for the provisioning UI flow.
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
