import 'dart:async';

import 'src/core/mesh_manager_api.dart';
import 'src/models/mesh_network.dart' as models;
import 'src/models/provisioned_node.dart' as models;
import 'src/models/unprovisioned_device.dart' as models;
import 'src/models/mesh_group.dart' as models;
import 'src/models/mesh_message.dart' as models;
import 'src/platform_interface/platojobs_mesh_platform.dart' as platform;

export 'src/models/mesh_network.dart' show MeshNetwork, NetworkKey, AppKey, Provisioner;
export 'src/models/unprovisioned_device.dart' show UnprovisionedDevice;
export 'src/models/provisioned_node.dart' show ProvisionedNode, NodeFeatures, Element, Model;
export 'src/models/mesh_group.dart' show MeshGroup;
export 'src/models/mesh_message.dart'
    show MeshMessage, UnknownMessage, GenericOnOffSet, GenericLevelSet;
export 'src/core/mesh_exceptions.dart'
    show
        PlatoJobsMeshException,
        PlatoJobsMeshPlatformException,
        PlatoJobsMeshTimeoutException,
        PlatoJobsMeshPermissionException,
        PlatoJobsMeshConnectionException,
        PlatoJobsMeshInvalidStateException;

class PlatoJobsNrfMeshManager {
  static final PlatoJobsNrfMeshManager instance =
      PlatoJobsNrfMeshManager._internal();
  factory PlatoJobsNrfMeshManager() => instance;
  PlatoJobsNrfMeshManager._internal() {
    platform.PlatoJobsMeshBridge.instance = platform.PlatoJobsMeshBridgeImpl();
  }

  final MeshManagerApi _meshManagerApi = MeshManagerApi();

  Future<void> initialize() async {
    await _meshManagerApi.initialize();
  }

  Future<models.MeshNetwork> createNetwork(String name) async {
    return await _meshManagerApi.createNetwork(name);
  }

  Future<models.MeshNetwork> loadNetwork() async {
    return await _meshManagerApi.loadNetwork();
  }

  Future<bool> saveNetwork() async {
    return await _meshManagerApi.saveNetwork();
  }

  Future<bool> exportNetwork(String path) async {
    return await _meshManagerApi.exportNetwork(path);
  }

  Future<bool> importNetwork(String path) async {
    return await _meshManagerApi.importNetwork(path);
  }

  Stream<models.UnprovisionedDevice> scanForDevices() {
    return _meshManagerApi.scanForDevices();
  }

  Future<void> stopScan() async {
    return await _meshManagerApi.stopScan();
  }

  Future<models.ProvisionedNode> provisionDevice(
    models.UnprovisionedDevice device,
    ProvisioningParameters params,
  ) async {
    return await _meshManagerApi.provisionDevice(device, params);
  }

  Future<void> sendMessage(models.MeshMessage message) async {
    return await _meshManagerApi.sendMessage(message);
  }

  Stream<models.MeshMessage> get messageStream {
    return _meshManagerApi.messageStream;
  }

  Future<List<models.ProvisionedNode>> getNodes() async {
    return await _meshManagerApi.getNodes();
  }

  Future<void> removeNode(String nodeId) async {
    return await _meshManagerApi.removeNode(nodeId);
  }

  Future<models.MeshGroup> createGroup(String name) async {
    return await _meshManagerApi.createGroup(name);
  }

  Future<List<models.MeshGroup>> getGroups() async {
    return await _meshManagerApi.getGroups();
  }

  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    return await _meshManagerApi.addNodeToGroup(nodeId, groupId);
  }
}

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
