// lib/src/platform_interface/platojobs_mesh_platform.dart

import 'dart:async';

import '../models/mesh_group.dart' as group_models;
import '../models/mesh_message.dart' as msg_models;
import '../models/mesh_network.dart' as net_models;
import '../models/provisioned_node.dart' as node_models;
import '../models/rx_access_message.dart' as rx_models;
import '../models/unprovisioned_device.dart' as dev_models;
import 'pigeon_generated.dart' as pigeon;

abstract class PlatoJobsMeshBridge {
  static PlatoJobsMeshBridge? _instance;

  static PlatoJobsMeshBridge get instance {
    if (_instance == null) {
      throw Exception('PlatoJobsMeshBridge instance not initialized');
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  static set instance(PlatoJobsMeshBridge instance) {
    _instance = instance;
  }

  static void resetForTesting() {
    _instance = null;
  }

  Future<void> initialize();

  Future<net_models.MeshNetwork> createNetwork(String name);

  Future<net_models.MeshNetwork> loadNetwork();

  Future<bool> saveNetwork();

  Future<bool> exportNetwork(String path);

  Future<bool> importNetwork(String path);

  Stream<dev_models.UnprovisionedDevice> scanForDevices();

  Future<void> stopScan();

  Future<node_models.ProvisionedNode> provisionDevice(
    dev_models.UnprovisionedDevice device,
    dynamic params,
  );

  Future<void> sendMessage(msg_models.MeshMessage message);

  Stream<msg_models.MeshMessage> get messageStream;

  /// A richer RX stream with best-effort metadata (source/destination).
  Stream<rx_models.RxAccessMessage> get rxAccessMessageStream;

  /// Provisioning lifecycle events (progress + OOB prompts).
  Stream<pigeon.ProvisioningEvent> get provisioningEventStream;

  Future<List<node_models.ProvisionedNode>> getNodes();

  Future<void> removeNode(String nodeId);

  Future<group_models.MeshGroup> createGroup(String name);

  Future<List<group_models.MeshGroup>> getGroups();

  Future<void> addNodeToGroup(String nodeId, String groupId);

  // Configuration (P1 - minimal)
  Future<bool> bindAppKey(int elementAddress, int modelId, int appKeyIndex);
  Future<bool> unbindAppKey(int elementAddress, int modelId, int appKeyIndex);
  Future<bool> addSubscription(int elementAddress, int modelId, int address);
  Future<bool> removeSubscription(int elementAddress, int modelId, int address);
  Future<bool> setPublication(
    int elementAddress,
    int modelId,
    int publishAddress,
    int appKeyIndex, {
    int? ttl,
  });

  // M2: Configuration foundation
  Future<bool> fetchCompositionData(int destination, {int page = 0});
  Future<bool> addAppKey(int appKeyIndex, String keyHex);
  Future<bool> addNetworkKey(int netKeyIndex, String keyHex);
  Future<List<net_models.NetworkKey>> getNetworkKeys();
  Future<List<net_models.AppKey>> getAppKeys();

  // M2 acceptance: node config + reset + bundle export/import
  Future<bool> setNodeDefaultTtl(int destination, int ttl);
  Future<bool> setNodeRelay(
    int destination,
    bool enabled,
    int retransmitCount,
    int retransmitIntervalMs,
  );
  Future<bool> setNodeGattProxy(int destination, bool enabled);
  Future<bool> setNodeFriend(int destination, bool enabled);
  Future<bool> setNodeBeacon(int destination, bool enabled);
  Future<bool> setNodeNetworkTransmit(int destination, int count, int intervalMs);
  Future<bool> nodeReset(int destination);
  Future<bool> exportConfigurationBundle(String path);
  Future<bool> importConfigurationBundle(String path);

  // Proxy (P1 real-transport prerequisite)
  Future<bool> connectProxy(String deviceId, int proxyUnicastAddress);
  Future<bool> disconnectProxy();
  Future<bool> isProxyConnected();

  // Provisioning bearer connection (PB-GATT) foundation.
  Future<bool> connectProvisioning(String deviceId);
  Future<bool> disconnectProvisioning();
  Future<bool> isProvisioningConnected();

  /// Provide user input required by Output OOB (numeric).
  Future<bool> provideProvisioningOobNumeric(String deviceId, int value);

  /// Provide user input required by Output OOB (alphanumeric).
  Future<bool> provideProvisioningOobAlphaNumeric(String deviceId, String value);

  /// Whether the native side can reliably populate the source address for
  /// incoming Access messages (`messageStream`).
  Future<bool> supportsRxSourceAddress();

  /// Clear persisted secure mesh state used for stable Access sending.
  Future<void> clearSecureStorage();

  /// Enable/disable experimental RX metadata extraction on Android.
  Future<void> setExperimentalRxMetadataEnabled(bool enabled);
}

class PlatoJobsMeshBridgeImpl extends PlatoJobsMeshBridge {
  final pigeon.MeshApi _meshApi = pigeon.MeshApi();
  final StreamController<dev_models.UnprovisionedDevice> _scanStreamController =
      StreamController<dev_models.UnprovisionedDevice>.broadcast();
  final StreamController<msg_models.MeshMessage> _messageStreamController =
      StreamController<msg_models.MeshMessage>.broadcast();
  final StreamController<rx_models.RxAccessMessage> _rxAccessStreamController =
      StreamController<rx_models.RxAccessMessage>.broadcast();
  final StreamController<pigeon.ProvisioningEvent> _provStreamController =
      StreamController<pigeon.ProvisioningEvent>.broadcast();

  @override
  Future<void> initialize() async {
    pigeon.MeshFlutterApi.setUp(
      _PlatoJobsMeshFlutterApiHandler(
        onDeviceDiscovered: (device) {
          _scanStreamController.add(
            dev_models.UnprovisionedDevice(
              deviceId: device.deviceId ?? '',
              name: device.name ?? '',
              serviceUuid: device.serviceUuid ?? '',
              rssi: device.rssi ?? 0,
              serviceData: device.uuid ?? [],
            ),
          );
        },
        onMessageReceived: (message) {
          final bytes = message.parameters?['bytes'];
          final parameters = (bytes is List) ? bytes.cast<int>() : <int>[];
          final opcode = message.opcode ?? 0;
          _messageStreamController.add(
            msg_models.MeshMessage.fromIncoming(
              opcode: opcode,
              parameters: parameters,
              address: message.address?.toInt(),
              appKeyIndex: message.appKeyIndex?.toInt(),
            ),
          );
        },
        onRxAccessMessage: (event) {
          _rxAccessStreamController.add(
            rx_models.RxAccessMessage(
              opcode: event.opcode ?? 0,
              parameters: (event.parameters ?? const <int>[]).toList(growable: false),
              source: event.source,
              destination: event.destination,
              metadataStatus: event.metadataStatus == pigeon.RxMetadataStatus.available
                  ? rx_models.RxMetadataStatus.available
                  : rx_models.RxMetadataStatus.unavailable,
            ),
          );
        },
        onProvisioningEvent: (event) {
          _provStreamController.add(event);
        },
      ),
    );
  }

  @override
  Future<net_models.MeshNetwork> createNetwork(String name) async {
    final result = await _meshApi.createNetwork(name);
    return _convertToMeshNetwork(result);
  }

  @override
  Future<net_models.MeshNetwork> loadNetwork() async {
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
  Stream<dev_models.UnprovisionedDevice> scanForDevices() {
    _meshApi.startScan();
    return _scanStreamController.stream;
  }

  @override
  Future<void> stopScan() async {
    await _meshApi.stopScan();
  }

  @override
  Future<node_models.ProvisionedNode> provisionDevice(
    dev_models.UnprovisionedDevice device,
    dynamic params,
  ) async {
    final pigeonDevice = pigeon.FlutterUnprovisionedDevice(
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
  Future<void> sendMessage(msg_models.MeshMessage message) async {
    final opcodeStr = message.opcode.toLowerCase().replaceAll('0x', '');
    final opcodeInt = int.tryParse(opcodeStr, radix: 16);
    final pigeonMessage = pigeon.MeshMessage(
      opcode: opcodeInt,
      address: message.address ?? 0,
      appKeyIndex: message.appKeyIndex ?? 0,
      parameters: <String, Object?>{'bytes': message.parameters},
    );
    await _meshApi.sendMessage(pigeonMessage);
  }

  @override
  Stream<msg_models.MeshMessage> get messageStream {
    return _messageStreamController.stream;
  }

  @override
  Stream<rx_models.RxAccessMessage> get rxAccessMessageStream {
    return _rxAccessStreamController.stream;
  }

  @override
  Stream<pigeon.ProvisioningEvent> get provisioningEventStream {
    return _provStreamController.stream;
  }

  @override
  Future<List<node_models.ProvisionedNode>> getNodes() async {
    final result = await _meshApi.getNodes();
    return result.map((node) => _convertToProvisionedNode(node)).toList();
  }

  @override
  Future<void> removeNode(String nodeId) async {
    await _meshApi.removeNode(nodeId);
  }

  @override
  Future<group_models.MeshGroup> createGroup(String name) async {
    final result = await _meshApi.createGroup(name);
    return _convertToMeshGroup(result);
  }

  @override
  Future<List<group_models.MeshGroup>> getGroups() async {
    final result = await _meshApi.getGroups();
    return result.map((group) => _convertToMeshGroup(group)).toList();
  }

  @override
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    await _meshApi.addNodeToGroup(nodeId, groupId);
  }

  @override
  Future<bool> bindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    return await _meshApi.bindAppKey(elementAddress, modelId, appKeyIndex);
  }

  @override
  Future<bool> unbindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    return await _meshApi.unbindAppKey(elementAddress, modelId, appKeyIndex);
  }

  @override
  Future<bool> addSubscription(int elementAddress, int modelId, int address) async {
    return await _meshApi.addSubscription(elementAddress, modelId, address);
  }

  @override
  Future<bool> removeSubscription(int elementAddress, int modelId, int address) async {
    return await _meshApi.removeSubscription(elementAddress, modelId, address);
  }

  @override
  Future<bool> setPublication(
    int elementAddress,
    int modelId,
    int publishAddress,
    int appKeyIndex, {
    int? ttl,
  }) async {
    return await _meshApi.setPublication(
      elementAddress,
      modelId,
      publishAddress,
      appKeyIndex,
      ttl: ttl,
    );
  }

  @override
  Future<bool> fetchCompositionData(int destination, {int page = 0}) async {
    return await _meshApi.fetchCompositionData(destination, page: page);
  }

  @override
  Future<bool> addAppKey(int appKeyIndex, String keyHex) async {
    return await _meshApi.addAppKey(appKeyIndex, keyHex);
  }

  @override
  Future<bool> addNetworkKey(int netKeyIndex, String keyHex) async {
    return await _meshApi.addNetworkKey(netKeyIndex, keyHex);
  }

  @override
  Future<List<net_models.NetworkKey>> getNetworkKeys() async {
    final result = await _meshApi.getNetworkKeys();
    return result
        .map(
          (k) => net_models.NetworkKey(
            keyId: k.keyId ?? '',
            key: k.key ?? '',
            index: k.index?.toInt() ?? 0,
            enabled: k.enabled ?? true,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<net_models.AppKey>> getAppKeys() async {
    final result = await _meshApi.getAppKeys();
    return result
        .map(
          (k) => net_models.AppKey(
            keyId: k.keyId ?? '',
            key: k.key ?? '',
            index: k.index?.toInt() ?? 0,
            enabled: k.enabled ?? true,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> setNodeDefaultTtl(int destination, int ttl) async {
    return await _meshApi.setNodeDefaultTtl(destination, ttl);
  }

  @override
  Future<bool> setNodeRelay(
    int destination,
    bool enabled,
    int retransmitCount,
    int retransmitIntervalMs,
  ) async {
    return await _meshApi.setNodeRelay(
      destination,
      enabled,
      retransmitCount,
      retransmitIntervalMs,
    );
  }

  @override
  Future<bool> setNodeGattProxy(int destination, bool enabled) async {
    return await _meshApi.setNodeGattProxy(destination, enabled);
  }

  @override
  Future<bool> setNodeFriend(int destination, bool enabled) async {
    return await _meshApi.setNodeFriend(destination, enabled);
  }

  @override
  Future<bool> setNodeBeacon(int destination, bool enabled) async {
    return await _meshApi.setNodeBeacon(destination, enabled);
  }

  @override
  Future<bool> setNodeNetworkTransmit(int destination, int count, int intervalMs) async {
    return await _meshApi.setNodeNetworkTransmit(destination, count, intervalMs);
  }

  @override
  Future<bool> nodeReset(int destination) async {
    return await _meshApi.nodeReset(destination);
  }

  @override
  Future<bool> exportConfigurationBundle(String path) async {
    return await _meshApi.exportConfigurationBundle(path);
  }

  @override
  Future<bool> importConfigurationBundle(String path) async {
    return await _meshApi.importConfigurationBundle(path);
  }

  @override
  Future<bool> connectProxy(String deviceId, int proxyUnicastAddress) async {
    return await _meshApi.connectProxy(deviceId, proxyUnicastAddress);
  }

  @override
  Future<bool> disconnectProxy() async {
    return await _meshApi.disconnectProxy();
  }

  @override
  Future<bool> isProxyConnected() async {
    return await _meshApi.isProxyConnected();
  }

  @override
  Future<bool> connectProvisioning(String deviceId) async {
    return await _meshApi.connectProvisioning(deviceId);
  }

  @override
  Future<bool> disconnectProvisioning() async {
    return await _meshApi.disconnectProvisioning();
  }

  @override
  Future<bool> isProvisioningConnected() async {
    return await _meshApi.isProvisioningConnected();
  }

  @override
  Future<bool> provideProvisioningOobNumeric(String deviceId, int value) async {
    return await _meshApi.provideProvisioningOobNumeric(deviceId, value);
  }

  @override
  Future<bool> provideProvisioningOobAlphaNumeric(String deviceId, String value) async {
    return await _meshApi.provideProvisioningOobAlphaNumeric(deviceId, value);
  }

  @override
  Future<bool> supportsRxSourceAddress() async {
    return await _meshApi.supportsRxSourceAddress();
  }

  @override
  Future<void> clearSecureStorage() async {
    await _meshApi.clearSecureStorage();
  }

  @override
  Future<void> setExperimentalRxMetadataEnabled(bool enabled) async {
    await _meshApi.setExperimentalRxMetadataEnabled(enabled);
  }

  net_models.MeshNetwork _convertToMeshNetwork(pigeon.MeshNetwork pigeonNetwork) {
    return net_models.MeshNetwork(
      networkId: pigeonNetwork.networkId ?? '',
      name: pigeonNetwork.name ?? '',
      networkKeys: (pigeonNetwork.networkKeys ?? const <pigeon.NetworkKey>[])
          .map(
            (k) => net_models.NetworkKey(
              keyId: k.keyId ?? '',
              key: k.key ?? '',
              index: (k.index ?? 0).toInt(),
              enabled: k.enabled ?? true,
            ),
          )
          .toList(growable: false),
      appKeys: (pigeonNetwork.appKeys ?? const <pigeon.AppKey>[])
          .map(
            (k) => net_models.AppKey(
              keyId: k.keyId ?? '',
              key: k.key ?? '',
              index: (k.index ?? 0).toInt(),
              enabled: k.enabled ?? true,
            ),
          )
          .toList(growable: false),
      nodes: (pigeonNetwork.nodes ?? const <pigeon.ProvisionedNode>[])
          .map(_convertToProvisionedNode)
          .toList(growable: false),
      groups: (pigeonNetwork.groups ?? const <pigeon.MeshGroup>[])
          .map(_convertToMeshGroup)
          .toList(growable: false),
      provisioner: net_models.Provisioner(
        name: pigeonNetwork.provisioner?.name ?? '',
        provisionerId: pigeonNetwork.provisioner?.provisionerId ?? '',
        addressRange: pigeonNetwork.provisioner?.addressRange ?? [],
      ),
    );
  }

  node_models.ProvisionedNode _convertToProvisionedNode(
    pigeon.ProvisionedNode pigeonNode,
  ) {
    String hex16(int v) => '0x${v.toRadixString(16).padLeft(4, '0')}';

    return node_models.ProvisionedNode(
      uuid: (pigeonNode.uuid ?? const <int>[])
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      unicastAddress: pigeonNode.unicastAddress == null
          ? ''
          : hex16(pigeonNode.unicastAddress!.toInt()),
      elements: (pigeonNode.elements ?? const <pigeon.Element>[])
          .map(
            (e) => node_models.Element(
              address: e.address == null ? '' : hex16(e.address!.toInt()),
              models: (e.models ?? const <pigeon.Model>[])
                  .map(
                    (m) => node_models.Model(
                      modelId: (m.modelId ?? 0).toString(),
                      modelName: m.modelName ?? '',
                      isServer: m.publishable ?? false,
                      isClient: m.subscribable ?? false,
                      boundAppKeyIndexes: m.boundAppKeyIndexes ?? const <int>[],
                      subscriptions: m.subscriptions ?? const <int>[],
                      publication: m.publication == null
                          ? null
                          : node_models.Publication(
                              address: (m.publication!.address ?? 0).toInt(),
                              appKeyIndex: (m.publication!.appKeyIndex ?? 0).toInt(),
                              ttl: m.publication!.ttl?.toInt(),
                            ),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      networkKeys: const <node_models.NetworkKey>[],
      appKeys: const <node_models.AppKey>[],
      features: node_models.NodeFeatures(
        relay: false,
        proxy: false,
        friend: false,
        lowPower: false,
      ),
    );
  }

  group_models.MeshGroup _convertToMeshGroup(pigeon.MeshGroup pigeonGroup) {
    return group_models.MeshGroup(
      groupId: pigeonGroup.groupId ?? '',
      name: pigeonGroup.name ?? '',
      address: pigeonGroup.address?.toString() ?? '',
      nodeIds: pigeonGroup.nodeIds ?? [],
    );
  }
}

class _PlatoJobsMeshFlutterApiHandler extends pigeon.MeshFlutterApi {
  final Function(pigeon.FlutterUnprovisionedDevice) _onDeviceDiscovered;
  final Function(pigeon.MeshMessage) _onMessageReceived;
  final Function(pigeon.RxAccessMessage) _onRxAccessMessage;
  final Function(pigeon.ProvisioningEvent) _onProvisioningEvent;

  _PlatoJobsMeshFlutterApiHandler({
    required Function(pigeon.FlutterUnprovisionedDevice) onDeviceDiscovered,
    required Function(pigeon.MeshMessage) onMessageReceived,
    required Function(pigeon.RxAccessMessage) onRxAccessMessage,
    required Function(pigeon.ProvisioningEvent) onProvisioningEvent,
  }) : _onDeviceDiscovered = onDeviceDiscovered,
       _onMessageReceived = onMessageReceived,
       _onRxAccessMessage = onRxAccessMessage,
       _onProvisioningEvent = onProvisioningEvent;

  @override
  void onDeviceDiscovered(pigeon.FlutterUnprovisionedDevice device) {
    _onDeviceDiscovered(device);
  }

  @override
  void onMessageReceived(pigeon.MeshMessage message) {
    _onMessageReceived(message);
  }

  @override
  void onRxAccessMessage(pigeon.RxAccessMessage event) {
    _onRxAccessMessage(event);
  }

  @override
  void onProvisioningEvent(pigeon.ProvisioningEvent event) {
    _onProvisioningEvent(event);
  }
}
