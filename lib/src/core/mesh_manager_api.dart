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
