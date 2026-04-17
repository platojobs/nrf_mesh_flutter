// lib/src/platform_interface/platojobs_mesh_platform.dart

import 'dart:async';

import '../models/mesh_network.dart' as models;
import '../models/provisioned_node.dart' as models;
import '../models/unprovisioned_device.dart' as models;
import '../models/mesh_message.dart' as models;
import '../models/mesh_group.dart' as models;
import 'pigeon_generated.dart' as pigeon;

abstract class PlatoJobsMeshBridge {
  static PlatoJobsMeshBridge? _instance;

  static PlatoJobsMeshBridge get instance {
    if (_instance == null) {
      throw Exception('PlatoJobsMeshBridge instance not initialized');
    }
    return _instance!;
  }

  static set instance(PlatoJobsMeshBridge instance) {
    _instance = instance;
  }

  Future<void> initialize();

  Future<models.MeshNetwork> createNetwork(String name);

  Future<models.MeshNetwork> loadNetwork();

  Future<bool> saveNetwork();

  Future<bool> exportNetwork(String path);

  Future<bool> importNetwork(String path);

  Stream<models.UnprovisionedDevice> scanForDevices();

  Future<void> stopScan();

  Future<models.ProvisionedNode> provisionDevice(
    models.UnprovisionedDevice device,
    dynamic params,
  );

  Future<void> sendMessage(models.MeshMessage message);

  Stream<models.MeshMessage> get messageStream;

  Future<List<models.ProvisionedNode>> getNodes();

  Future<void> removeNode(String nodeId);

  Future<models.MeshGroup> createGroup(String name);

  Future<List<models.MeshGroup>> getGroups();

  Future<void> addNodeToGroup(String nodeId, String groupId);
}

class PlatoJobsMeshBridgeImpl extends PlatoJobsMeshBridge {
  final pigeon.MeshApi _meshApi = pigeon.MeshApi();
  final StreamController<models.UnprovisionedDevice> _scanStreamController =
      StreamController<models.UnprovisionedDevice>.broadcast();
  final StreamController<models.MeshMessage> _messageStreamController =
      StreamController<models.MeshMessage>.broadcast();

  @override
  Future<void> initialize() async {
    pigeon.MeshFlutterApi.setUp(
      _PlatoJobsMeshFlutterApiHandler(
        onDeviceDiscovered: (device) {
          _scanStreamController.add(
            models.UnprovisionedDevice(
              deviceId: device.deviceId ?? '',
              name: device.name ?? '',
              serviceUuid: '',
              rssi: device.rssi ?? 0,
              serviceData: device.uuid ?? [],
            ),
          );
        },
        onMessageReceived: (message) {
          _messageStreamController.add(
            models.UnknownMessage(
              opcode: message.opcode?.toString() ?? '0',
              parameters: message.parameters?.values.cast<int>().toList() ?? [],
            ),
          );
        },
      ),
    );
  }

  @override
  Future<models.MeshNetwork> createNetwork(String name) async {
    final result = await _meshApi.createNetwork(name);
    return _convertToMeshNetwork(result);
  }

  @override
  Future<models.MeshNetwork> loadNetwork() async {
    final result = await _meshApi.loadNetwork();
    return _convertToMeshNetwork(result);
  }

  @override
  Future<bool> saveNetwork() async {
    return await _meshApi.saveNetwork();
  }

  @override
  Future<bool> exportNetwork(String path) async {
    return await _meshApi.exportNetwork(path);
  }

  @override
  Future<bool> importNetwork(String path) async {
    return await _meshApi.importNetwork(path);
  }

  @override
  Stream<models.UnprovisionedDevice> scanForDevices() {
    _meshApi.startScan();
    return _scanStreamController.stream;
  }

  @override
  Future<void> stopScan() async {
    await _meshApi.stopScan();
  }

  @override
  Future<models.ProvisionedNode> provisionDevice(
    models.UnprovisionedDevice device,
    dynamic params,
  ) async {
    final pigeonDevice = pigeon.UnprovisionedDevice(
      deviceId: device.deviceId,
      name: device.name,
      rssi: device.rssi,
      uuid: device.serviceData,
    );

    final pigeonParams = pigeon.ProvisioningParameters(
      deviceName: params.deviceName,
      oobMethod: params.oobMethod,
      oobData: params.oobData,
      enablePrivacy: params.enablePrivacy,
    );

    final result = await _meshApi.provisionDevice(pigeonDevice, pigeonParams);
    return _convertToProvisionedNode(result);
  }

  @override
  Future<void> sendMessage(models.MeshMessage message) async {
    final pigeonMessage = pigeon.MeshMessage(
      opcode: int.tryParse(message.opcode.replaceAll('0x', '')),
      address: 0,
      appKeyIndex: 0,
      parameters: {},
    );
    await _meshApi.sendMessage(pigeonMessage);
  }

  @override
  Stream<models.MeshMessage> get messageStream {
    return _messageStreamController.stream;
  }

  @override
  Future<List<models.ProvisionedNode>> getNodes() async {
    final result = await _meshApi.getNodes();
    return result.map((node) => _convertToProvisionedNode(node)).toList();
  }

  @override
  Future<void> removeNode(String nodeId) async {
    await _meshApi.removeNode(nodeId);
  }

  @override
  Future<models.MeshGroup> createGroup(String name) async {
    final result = await _meshApi.createGroup(name);
    return _convertToMeshGroup(result);
  }

  @override
  Future<List<models.MeshGroup>> getGroups() async {
    final result = await _meshApi.getGroups();
    return result.map((group) => _convertToMeshGroup(group)).toList();
  }

  @override
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    await _meshApi.addNodeToGroup(nodeId, groupId);
  }

  models.MeshNetwork _convertToMeshNetwork(pigeon.MeshNetwork pigeonNetwork) {
    return models.MeshNetwork(
      networkId: pigeonNetwork.networkId ?? '',
      name: pigeonNetwork.name ?? '',
      networkKeys: [],
      appKeys: [],
      nodes: [],
      groups: [],
      provisioner: models.Provisioner(
        name: pigeonNetwork.provisioner?.name ?? '',
        provisionerId: pigeonNetwork.provisioner?.provisionerId ?? '',
        addressRange: pigeonNetwork.provisioner?.addressRange ?? [],
      ),
    );
  }

  models.ProvisionedNode _convertToProvisionedNode(
    pigeon.ProvisionedNode pigeonNode,
  ) {
    return models.ProvisionedNode(
      uuid: pigeonNode.uuid?.toString() ?? '',
      unicastAddress: pigeonNode.unicastAddress?.toString() ?? '',
      elements: [],
      networkKeys: [],
      appKeys: [],
      features: models.NodeFeatures(
        relay: false,
        proxy: false,
        friend: false,
        lowPower: false,
      ),
    );
  }

  models.MeshGroup _convertToMeshGroup(pigeon.MeshGroup pigeonGroup) {
    return models.MeshGroup(
      groupId: pigeonGroup.groupId ?? '',
      name: pigeonGroup.name ?? '',
      address: pigeonGroup.address?.toString() ?? '',
      nodeIds: pigeonGroup.nodeIds ?? [],
    );
  }
}

class _PlatoJobsMeshFlutterApiHandler extends pigeon.MeshFlutterApi {
  final Function(pigeon.UnprovisionedDevice) _onDeviceDiscovered;
  final Function(pigeon.MeshMessage) _onMessageReceived;

  _PlatoJobsMeshFlutterApiHandler({
    required Function(pigeon.UnprovisionedDevice) onDeviceDiscovered,
    required Function(pigeon.MeshMessage) onMessageReceived,
  }) : _onDeviceDiscovered = onDeviceDiscovered,
       _onMessageReceived = onMessageReceived;

  @override
  void onDeviceDiscovered(pigeon.UnprovisionedDevice device) {
    _onDeviceDiscovered(device);
  }

  @override
  void onMessageReceived(pigeon.MeshMessage message) {
    _onMessageReceived(message);
  }
}
