import 'dart:async';

import '../models/mesh_network.dart' as net_models;
import '../models/provisioned_node.dart' as node_models;
import '../models/unprovisioned_device.dart' as dev_models;
import '../models/mesh_message.dart' as msg_models;
import '../models/mesh_group.dart' as group_models;
import '../models/rx_access_message.dart' as rx_models;
import 'command_queue.dart';
import 'mesh_exceptions.dart';
import '../platform_interface/platojobs_mesh_platform.dart' as platform;
import '../platform_interface/pigeon_generated.dart' as pigeon;

class MeshManagerApi {
  platform.PlatoJobsMeshBridge get _platform => platform.PlatoJobsMeshBridge.instance;
  final PlatoJobsMeshCommandQueue _commandQueue = PlatoJobsMeshCommandQueue();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw platoJobsMeshMapException(e);
    }
  }

  /// Initialize the mesh manager API
  Future<void> initialize() async {
    await _guard(() => _platform.initialize());
  }

  // Network management
  /// Create a new mesh network
  Future<net_models.MeshNetwork> createNetwork(String name) async {
    return await _guard(() => _platform.createNetwork(name));
  }

  /// Load an existing mesh network
  Future<net_models.MeshNetwork> loadNetwork() async {
    return await _guard(() => _platform.loadNetwork());
  }

  /// Save the current mesh network
  Future<bool> saveNetwork() async {
    return await _guard(() => _platform.saveNetwork());
  }

  /// Export the mesh network to a file
  Future<bool> exportNetwork(String path) async {
    return await _guard(() => _platform.exportNetwork(path));
  }

  /// Import a mesh network from a file
  Future<bool> importNetwork(String path) async {
    return await _guard(() => _platform.importNetwork(path));
  }

  // Device scanning
  /// Scan for unprovisioned devices
  Stream<dev_models.UnprovisionedDevice> scanForDevices() {
    return _platform.scanForDevices();
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    return await _guard(() => _platform.stopScan());
  }

  // Provisioning
  /// Provision a device into the mesh network
  Future<node_models.ProvisionedNode> provisionDevice(
    dev_models.UnprovisionedDevice device,
    dynamic params,
  ) async {
    return await _guard(() => _platform.provisionDevice(device, params));
  }

  // Message sending
  /// Send a mesh message
  Future<void> sendMessage(msg_models.MeshMessage message) async {
    return _guard(
      () => _commandQueue.enqueue(
        () => _platform.sendMessage(message),
        debugLabel: 'sendMessage(${message.opcode})',
      ),
    );
  }

  /// Stream of received mesh messages
  Stream<msg_models.MeshMessage> get messageStream {
    return _platform.messageStream;
  }

  /// Stream of received Access messages with best-effort metadata.
  Stream<rx_models.RxAccessMessage> get rxAccessMessageStream {
    return _platform.rxAccessMessageStream;
  }

  Stream<pigeon.ProvisioningEvent> get provisioningEventStream {
    return _platform.provisioningEventStream;
  }

  Future<bool> provideProvisioningOobNumeric(String deviceId, int value) async {
    return await _guard(() => _platform.provideProvisioningOobNumeric(deviceId, value));
  }

  Future<bool> provideProvisioningOobAlphaNumeric(String deviceId, String value) async {
    return await _guard(() => _platform.provideProvisioningOobAlphaNumeric(deviceId, value));
  }

  /// Whether the native side can reliably populate source address for incoming Access messages.
  Future<bool> supportsRxSourceAddress() async {
    return await _guard(() => _platform.supportsRxSourceAddress());
  }

  /// Clear persisted secure mesh state used for stable Access sending.
  Future<void> clearSecureStorage() async {
    return await _guard(() => _platform.clearSecureStorage());
  }

  Future<void> setExperimentalRxMetadataEnabled(bool enabled) async {
    return await _guard(() => _platform.setExperimentalRxMetadataEnabled(enabled));
  }

  // Node management
  /// Get all provisioned nodes
  Future<List<node_models.ProvisionedNode>> getNodes() async {
    return await _guard(() => _platform.getNodes());
  }

  /// Remove a node from the network
  Future<void> removeNode(String nodeId) async {
    return await _guard(() => _platform.removeNode(nodeId));
  }

  // Group management
  /// Create a new mesh group
  Future<group_models.MeshGroup> createGroup(String name) async {
    return await _guard(() => _platform.createGroup(name));
  }

  /// Get all mesh groups
  Future<List<group_models.MeshGroup>> getGroups() async {
    return await _guard(() => _platform.getGroups());
  }

  // M2: Configuration foundation
  Future<bool> fetchCompositionData(int destination, {int page = 0}) async {
    return await _guard(() => _platform.fetchCompositionData(destination, page: page));
  }

  Future<bool> addNetworkKey(int netKeyIndex, String keyHex) async {
    return await _guard(() => _platform.addNetworkKey(netKeyIndex, keyHex));
  }

  Future<bool> addAppKey(int appKeyIndex, String keyHex) async {
    return await _guard(() => _platform.addAppKey(appKeyIndex, keyHex));
  }

  Future<List<net_models.NetworkKey>> getNetworkKeys() async {
    return await _guard(() => _platform.getNetworkKeys());
  }

  Future<List<net_models.AppKey>> getAppKeys() async {
    return await _guard(() => _platform.getAppKeys());
  }

  // M2 acceptance: node config + reset + bundle export/import
  Future<bool> setNodeDefaultTtl(int destination, int ttl) async {
    return await _guard(() => _platform.setNodeDefaultTtl(destination, ttl));
  }

  Future<bool> setNodeRelay(
    int destination,
    bool enabled,
    int retransmitCount,
    int retransmitIntervalMs,
  ) async {
    return await _guard(
      () => _platform.setNodeRelay(
        destination,
        enabled,
        retransmitCount,
        retransmitIntervalMs,
      ),
    );
  }

  Future<bool> setNodeGattProxy(int destination, bool enabled) async {
    return await _guard(() => _platform.setNodeGattProxy(destination, enabled));
  }

  Future<bool> setNodeFriend(int destination, bool enabled) async {
    return await _guard(() => _platform.setNodeFriend(destination, enabled));
  }

  Future<bool> setNodeBeacon(int destination, bool enabled) async {
    return await _guard(() => _platform.setNodeBeacon(destination, enabled));
  }

  Future<bool> setNodeNetworkTransmit(int destination, int count, int intervalMs) async {
    return await _guard(() => _platform.setNodeNetworkTransmit(destination, count, intervalMs));
  }

  Future<bool> nodeReset(int destination) async {
    return await _guard(() => _platform.nodeReset(destination));
  }

  Future<bool> exportConfigurationBundle(String path) async {
    return await _guard(() => _platform.exportConfigurationBundle(path));
  }

  Future<bool> importConfigurationBundle(String path) async {
    return await _guard(() => _platform.importConfigurationBundle(path));
  }

  /// Add a node to a group
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    return await _guard(() => _platform.addNodeToGroup(nodeId, groupId));
  }

  // Configuration (P1 - minimal)
  Future<bool> bindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    return await _guard(() => _platform.bindAppKey(elementAddress, modelId, appKeyIndex));
  }

  Future<bool> unbindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    return await _guard(() => _platform.unbindAppKey(elementAddress, modelId, appKeyIndex));
  }

  Future<bool> addSubscription(int elementAddress, int modelId, int address) async {
    return await _guard(() => _platform.addSubscription(elementAddress, modelId, address));
  }

  Future<bool> removeSubscription(int elementAddress, int modelId, int address) async {
    return await _guard(() => _platform.removeSubscription(elementAddress, modelId, address));
  }

  Future<bool> setPublication(
    int elementAddress,
    int modelId,
    int publishAddress,
    int appKeyIndex, {
    int? ttl,
  }) async {
    return await _guard(
      () => _platform.setPublication(
        elementAddress,
        modelId,
        publishAddress,
        appKeyIndex,
        ttl: ttl,
      ),
    );
  }

  // Proxy (P1 real-transport prerequisite)
  Future<bool> connectProxy(String deviceId, int proxyUnicastAddress) async {
    return await _guard(() => _platform.connectProxy(deviceId, proxyUnicastAddress));
  }

  Future<bool> disconnectProxy() async {
    return await _guard(() => _platform.disconnectProxy());
  }

  Future<bool> isProxyConnected() async {
    return await _guard(() => _platform.isProxyConnected());
  }

  Future<bool> connectProvisioning(String deviceId) async {
    return await _guard(() => _platform.connectProvisioning(deviceId));
  }

  Future<bool> disconnectProvisioning() async {
    return await _guard(() => _platform.disconnectProvisioning());
  }

  Future<bool> isProvisioningConnected() async {
    return await _guard(() => _platform.isProvisioningConnected());
  }
}

/// Provisioning parameters for mesh devices
class ProvisioningParameters {
  final String deviceName;
  final int oobMethod;
  final String? oobData;
  final bool enablePrivacy;

  ProvisioningParameters({
    required this.deviceName,
    int? oobMethod,
    this.oobData,
    this.enablePrivacy = false,
  }) : oobMethod = oobMethod ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'deviceName': deviceName,
      'oobMethod': oobMethod,
      'oobData': oobData,
      'enablePrivacy': enablePrivacy,
    };
  }
}
