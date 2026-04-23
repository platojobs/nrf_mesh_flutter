import 'dart:async';

import '../models/mesh_network.dart' as models;
import '../models/provisioned_node.dart' as models;
import '../models/unprovisioned_device.dart' as models;
import '../models/mesh_message.dart' as models;
import '../models/mesh_group.dart' as models;
import 'command_queue.dart';
import 'mesh_exceptions.dart';
import '../platform_interface/platojobs_mesh_platform.dart' as platform;

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
  Future<models.MeshNetwork> createNetwork(String name) async {
    return await _guard(() => _platform.createNetwork(name));
  }

  /// Load an existing mesh network
  Future<models.MeshNetwork> loadNetwork() async {
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
  Stream<models.UnprovisionedDevice> scanForDevices() {
    return _platform.scanForDevices();
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    return await _guard(() => _platform.stopScan());
  }

  // Provisioning
  /// Provision a device into the mesh network
  Future<models.ProvisionedNode> provisionDevice(
    models.UnprovisionedDevice device,
    dynamic params,
  ) async {
    return await _guard(() => _platform.provisionDevice(device, params));
  }

  // Message sending
  /// Send a mesh message
  Future<void> sendMessage(models.MeshMessage message) async {
    return _guard(
      () => _commandQueue.enqueue(
        () => _platform.sendMessage(message),
        debugLabel: 'sendMessage(${message.opcode})',
      ),
    );
  }

  /// Stream of received mesh messages
  Stream<models.MeshMessage> get messageStream {
    return _platform.messageStream;
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
  Future<List<models.ProvisionedNode>> getNodes() async {
    return await _guard(() => _platform.getNodes());
  }

  /// Remove a node from the network
  Future<void> removeNode(String nodeId) async {
    return await _guard(() => _platform.removeNode(nodeId));
  }

  // Group management
  /// Create a new mesh group
  Future<models.MeshGroup> createGroup(String name) async {
    return await _guard(() => _platform.createGroup(name));
  }

  /// Get all mesh groups
  Future<List<models.MeshGroup>> getGroups() async {
    return await _guard(() => _platform.getGroups());
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
}

/// Provisioning parameters for mesh devices
class ProvisioningParameters {
  final String deviceName;
  final int? oobMethod;
  final String? oobData;
  final bool enablePrivacy;

  ProvisioningParameters({
    required this.deviceName,
    this.oobMethod,
    this.oobData,
    this.enablePrivacy = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceName': deviceName,
      'oobMethod': oobMethod,
      'oobData': oobData,
      'enablePrivacy': enablePrivacy,
    };
  }
}
