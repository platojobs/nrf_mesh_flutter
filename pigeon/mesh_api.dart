// pigeon/mesh_api.dart

import 'package:pigeon/pigeon.dart';

// Pigeon message definitions for nRF Mesh Flutter plugin

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform_interface/pigeon_generated.dart',
  swiftOut: 'ios/Classes/PigeonGenerated.swift',
  kotlinOut: 'android/src/main/kotlin/com/platojobs/nrf_mesh/PigeonGenerated.kt',
  kotlinOptions: KotlinOptions(package: 'com.platojobs.nrf_mesh'),
  dartPackageName: 'platojobs_nrf_mesh',
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
