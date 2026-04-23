// pigeon/mesh_api.dart

import 'package:pigeon/pigeon.dart';

// Pigeon message definitions for nRF Mesh Flutter plugin

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform_interface/pigeon_generated.dart',
  swiftOut: 'ios/Classes/PigeonGenerated.swift',
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
    UnprovisionedDevice device,
    ProvisioningParameters params,
  );

  // Message sending
  void sendMessage(MeshMessage message);

  // Node management
  List<ProvisionedNode> getNodes();
  void removeNode(String nodeId);

  // Group management
  MeshGroup createGroup(String name);
  List<MeshGroup> getGroups();
  void addNodeToGroup(String nodeId, String groupId);

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
  void onDeviceDiscovered(UnprovisionedDevice device);
  void onMessageReceived(MeshMessage message);
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

class UnprovisionedDevice {
  String? deviceId;
  String? name;
  int? rssi;
  List<int>? uuid;
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

class ProvisioningParameters {
  String? deviceName;
  int? oobMethod;
  String? oobData;
  bool? enablePrivacy;
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
