import 'dart:async';

import '../models/mesh_network.dart';
import '../models/provisioned_node.dart';
import '../models/unprovisioned_device.dart';
import '../models/mesh_message.dart';
import '../models/mesh_group.dart';
import '../platform/method_channel_handler.dart';

class MeshManagerApi {
  final MethodChannelHandler _channelHandler = MethodChannelHandler();
  final StreamController<UnprovisionedDevice> _scanStreamController =
      StreamController<UnprovisionedDevice>.broadcast();
  final StreamController<MeshMessage> _messageStreamController =
      StreamController<MeshMessage>.broadcast();

  /// Initialize the mesh manager API
  Future<void> initialize() async {
    await _channelHandler.initialize();
    _channelHandler.setScanCallback((device) {
      _scanStreamController.add(device);
    });
    _channelHandler.setMessageCallback((message) {
      _messageStreamController.add(message);
    });
  }

  // Network management
  /// Create a new mesh network
  Future<MeshNetwork> createNetwork(String name) async {
    final result = await _channelHandler.invokeMethod('createNetwork', {
      'name': name,
    });
    return MeshNetwork.fromMap(result);
  }

  /// Load an existing mesh network
  Future<MeshNetwork> loadNetwork() async {
    final result = await _channelHandler.invokeMethod('loadNetwork');
    return MeshNetwork.fromMap(result);
  }

  /// Save the current mesh network
  Future<bool> saveNetwork() async {
    return await _channelHandler.invokeMethod('saveNetwork');
  }

  /// Export the mesh network to a file
  Future<bool> exportNetwork(String path) async {
    return await _channelHandler.invokeMethod('exportNetwork', {'path': path});
  }

  /// Import a mesh network from a file
  Future<bool> importNetwork(String path) async {
    return await _channelHandler.invokeMethod('importNetwork', {'path': path});
  }

  // Device scanning
  /// Scan for unprovisioned devices
  Stream<UnprovisionedDevice> scanForDevices() {
    _channelHandler.invokeMethod('scanDevices');
    return _scanStreamController.stream;
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    await _channelHandler.invokeMethod('stopScan');
  }

  // Provisioning
  /// Provision a device into the mesh network
  Future<ProvisionedNode> provisionDevice(
    UnprovisionedDevice device,
    dynamic params,
  ) async {
    final result = await _channelHandler.invokeMethod('provisionDevice', {
      'device': device.toMap(),
      'params': params is ProvisioningParameters ? params.toMap() : params,
    });
    return ProvisionedNode.fromMap(result);
  }

  // Message sending
  /// Send a mesh message
  Future<void> sendMessage(MeshMessage message) async {
    await _channelHandler.invokeMethod('sendMessage', {
      'message': message.toMap(),
    });
  }

  /// Stream of received mesh messages
  Stream<MeshMessage> get messageStream {
    return _messageStreamController.stream;
  }

  // Node management
  /// Get all provisioned nodes
  Future<List<ProvisionedNode>> getNodes() async {
    final result = await _channelHandler.invokeMethod('getNodes');
    return (result as List).map((e) => ProvisionedNode.fromMap(e)).toList();
  }

  /// Remove a node from the network
  Future<void> removeNode(String nodeId) async {
    await _channelHandler.invokeMethod('removeNode', {'nodeId': nodeId});
  }

  // Group management
  /// Create a new mesh group
  Future<MeshGroup> createGroup(String name) async {
    final result = await _channelHandler.invokeMethod('createGroup', {
      'name': name,
    });
    return MeshGroup.fromMap(result);
  }

  /// Get all mesh groups
  Future<List<MeshGroup>> getGroups() async {
    final result = await _channelHandler.invokeMethod('getGroups');
    return (result as List).map((e) => MeshGroup.fromMap(e)).toList();
  }

  /// Add a node to a group
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    await _channelHandler.invokeMethod('addNodeToGroup', {
      'nodeId': nodeId,
      'groupId': groupId,
    });
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
