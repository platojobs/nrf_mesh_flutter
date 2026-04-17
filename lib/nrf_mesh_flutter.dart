import 'dart:async';

import 'src/core/mesh_manager_api.dart';
import 'src/models/mesh_network.dart';
import 'src/models/provisioned_node.dart';
import 'src/models/unprovisioned_device.dart';
import 'src/models/mesh_message.dart';
import 'src/models/mesh_group.dart';

/// Main entry point for the nRF Mesh Flutter plugin
class NrfMeshManager {
  // Singleton instance
  static final NrfMeshManager instance = NrfMeshManager._internal();
  factory NrfMeshManager() => instance;
  NrfMeshManager._internal();

  final MeshManagerApi _meshManagerApi = MeshManagerApi();

  /// Initialize the mesh manager
  Future<void> initialize() async {
    await _meshManagerApi.initialize();
  }

  // Network management
  /// Create a new mesh network
  Future<MeshNetwork> createNetwork(String name) async {
    return await _meshManagerApi.createNetwork(name);
  }

  /// Load an existing mesh network
  Future<MeshNetwork> loadNetwork() async {
    return await _meshManagerApi.loadNetwork();
  }

  /// Save the current mesh network
  Future<bool> saveNetwork() async {
    return await _meshManagerApi.saveNetwork();
  }

  /// Export the mesh network to a file
  Future<bool> exportNetwork(String path) async {
    return await _meshManagerApi.exportNetwork(path);
  }

  /// Import a mesh network from a file
  Future<bool> importNetwork(String path) async {
    return await _meshManagerApi.importNetwork(path);
  }

  // Device scanning
  /// Scan for unprovisioned devices
  Stream<UnprovisionedDevice> scanForDevices() {
    return _meshManagerApi.scanForDevices();
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    return await _meshManagerApi.stopScan();
  }

  // Provisioning
  /// Provision a device into the mesh network
  Future<ProvisionedNode> provisionDevice(
    UnprovisionedDevice device,
    ProvisioningParameters params,
  ) async {
    return await _meshManagerApi.provisionDevice(device, params);
  }

  // Message sending
  /// Send a mesh message
  Future<void> sendMessage(MeshMessage message) async {
    return await _meshManagerApi.sendMessage(message);
  }

  /// Stream of received mesh messages
  Stream<MeshMessage> get messageStream {
    return _meshManagerApi.messageStream;
  }

  // Node management
  /// Get all provisioned nodes
  Future<List<ProvisionedNode>> getNodes() async {
    return await _meshManagerApi.getNodes();
  }

  /// Remove a node from the network
  Future<void> removeNode(String nodeId) async {
    return await _meshManagerApi.removeNode(nodeId);
  }

  // Group management
  /// Create a new mesh group
  Future<MeshGroup> createGroup(String name) async {
    return await _meshManagerApi.createGroup(name);
  }

  /// Get all mesh groups
  Future<List<MeshGroup>> getGroups() async {
    return await _meshManagerApi.getGroups();
  }

  /// Add a node to a group
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    return await _meshManagerApi.addNodeToGroup(nodeId, groupId);
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
}