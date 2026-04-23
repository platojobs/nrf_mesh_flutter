import 'dart:async';

import 'src/core/mesh_manager_api.dart';
import 'src/models/mesh_network.dart' as models;
import 'src/models/provisioned_node.dart' as models;
import 'src/models/unprovisioned_device.dart' as models;
import 'src/models/mesh_group.dart' as models;
import 'src/models/mesh_message.dart' as models;
import 'src/models/raw_access_message.dart' as models;
import 'src/models/rx_access_message.dart' as rx_models;
import 'src/platform_interface/platojobs_mesh_platform.dart' as platform;
import 'src/platform_interface/pigeon_generated.dart' as pigeon;

export 'src/models/mesh_network.dart' show MeshNetwork, NetworkKey, AppKey, Provisioner;
export 'src/models/unprovisioned_device.dart' show UnprovisionedDevice;
export 'src/models/provisioned_node.dart'
    show ProvisionedNode, NodeFeatures, Element, Model, Publication;
export 'src/models/mesh_group.dart' show MeshGroup;
export 'src/models/mesh_message.dart'
    show
        MeshMessage,
        UnknownMessage,
        GenericOnOffSet,
        GenericLevelSet,
        GenericOnOffStatus,
        GenericLevelStatus;
export 'src/models/raw_access_message.dart' show RawAccessMessage;
export 'src/models/rx_access_message.dart' show RxAccessMessage, RxMetadataStatus;
export 'src/platform_interface/pigeon_generated.dart'
    show ProvisioningEvent, ProvisioningEventType;
export 'src/core/mesh_exceptions.dart'
    show
        PlatoJobsMeshException,
        PlatoJobsMeshPlatformException,
        PlatoJobsMeshTimeoutException,
        PlatoJobsMeshPermissionException,
        PlatoJobsMeshConnectionException,
        PlatoJobsMeshInvalidStateException;
export 'src/testing/fake_mesh_bridge.dart'
    show
        FakePlatoJobsMeshBridge,
        FakeMeshScenario,
        FakeMeshScenarioStep;

class PlatoJobsNrfMeshManager {
  static final PlatoJobsNrfMeshManager instance =
      PlatoJobsNrfMeshManager._internal();
  factory PlatoJobsNrfMeshManager() => instance;
  PlatoJobsNrfMeshManager._internal() {
    if (!platform.PlatoJobsMeshBridge.isInitialized) {
      platform.PlatoJobsMeshBridge.instance = platform.PlatoJobsMeshBridgeImpl();
    }
  }

  final MeshManagerApi _meshManagerApi = MeshManagerApi();

  /// Override the platform bridge, intended for tests / mocks.
  static void setBridgeForTesting(platform.PlatoJobsMeshBridge bridge) {
    platform.PlatoJobsMeshBridge.instance = bridge;
  }

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

  /// Send a raw Access message (opcode + parameters bytes) to [address] using [appKeyIndex].
  ///
  /// Prefer this over manually constructing a Pigeon payload map.
  Future<void> sendAccess({
    required int opCode,
    required List<int> parameters,
    required int address,
    required int appKeyIndex,
  }) async {
    return await _meshManagerApi.sendMessage(
      models.RawAccessMessage(
        opCode: opCode,
        parameters: parameters,
        address: address,
        appKeyIndex: appKeyIndex,
      ),
    );
  }

  Stream<models.MeshMessage> get messageStream {
    return _meshManagerApi.messageStream;
  }

  Stream<rx_models.RxAccessMessage> get rxAccessMessageStream {
    return _meshManagerApi.rxAccessMessageStream;
  }

  Stream<pigeon.ProvisioningEvent> get provisioningEventStream {
    return _meshManagerApi.provisioningEventStream;
  }

  /// Provide user input required by Output OOB (numeric).
  Future<bool> provideProvisioningOobNumeric(String deviceId, int value) async {
    return await _meshManagerApi.provideProvisioningOobNumeric(deviceId, value);
  }

  /// Provide user input required by Output OOB (alphanumeric).
  Future<bool> provideProvisioningOobAlphaNumeric(String deviceId, String value) async {
    return await _meshManagerApi.provideProvisioningOobAlphaNumeric(deviceId, value);
  }

  /// Whether the native side can reliably populate source address for incoming Access messages.
  Future<bool> supportsRxSourceAddress() async {
    return await _meshManagerApi.supportsRxSourceAddress();
  }

  /// Clear persisted secure mesh state used for stable Access sending.
  Future<void> clearSecureStorage() async {
    return await _meshManagerApi.clearSecureStorage();
  }

  /// Android-only: enable/disable experimental RX metadata extraction.
  ///
  /// When enabled, Android may use internal APIs (via reflection) to extract the
  /// source address for incoming Access messages.
  Future<void> setExperimentalRxMetadataEnabled(bool enabled) async {
    return await _meshManagerApi.setExperimentalRxMetadataEnabled(enabled);
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

  // Configuration (P1 - minimal)
  Future<bool> bindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    return await _meshManagerApi.bindAppKey(elementAddress, modelId, appKeyIndex);
  }

  Future<bool> unbindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    return await _meshManagerApi.unbindAppKey(elementAddress, modelId, appKeyIndex);
  }

  Future<bool> addSubscription(int elementAddress, int modelId, int address) async {
    return await _meshManagerApi.addSubscription(elementAddress, modelId, address);
  }

  Future<bool> removeSubscription(int elementAddress, int modelId, int address) async {
    return await _meshManagerApi.removeSubscription(elementAddress, modelId, address);
  }

  Future<bool> setPublication(
    int elementAddress,
    int modelId,
    int publishAddress,
    int appKeyIndex, {
    int? ttl,
  }) async {
    return await _meshManagerApi.setPublication(
      elementAddress,
      modelId,
      publishAddress,
      appKeyIndex,
      ttl: ttl,
    );
  }

  // Proxy (P1 real-transport prerequisite)
  Future<bool> connectProxy(String deviceId, int proxyUnicastAddress) async {
    return await _meshManagerApi.connectProxy(deviceId, proxyUnicastAddress);
  }

  Future<bool> disconnectProxy() async {
    return await _meshManagerApi.disconnectProxy();
  }

  Future<bool> isProxyConnected() async {
    return await _meshManagerApi.isProxyConnected();
  }

  Future<bool> connectProvisioning(String deviceId) async {
    return await _meshManagerApi.connectProvisioning(deviceId);
  }

  Future<bool> disconnectProvisioning() async {
    return await _meshManagerApi.disconnectProvisioning();
  }

  Future<bool> isProvisioningConnected() async {
    return await _meshManagerApi.isProvisioningConnected();
  }
}

class ProvisioningParameters {
  final String deviceName;
  /// OOB method code used by native implementations.
  ///
  /// Convention:
  /// - 0: no OOB
  /// - 1: static OOB
  /// - 2: output OOB (device outputs, user enters)
  /// - 3: input OOB (user provides, device inputs)
  final int oobMethod;

  /// OOB payload (format depends on [oobMethod]).
  ///
  /// - static OOB: hex string (no `0x` prefix), even-length, 1..32 bytes.
  /// - output/input OOB: digits or ASCII string depending on UI flow.
  final String? oobData;
  final bool enablePrivacy;

  ProvisioningParameters._({
    required this.deviceName,
    this.oobData,
    required this.oobMethod,
    this.enablePrivacy = false,
  }) {
    _validate();
  }

  /// Backward-compatible constructor.
  ///
  /// Prefer using the typed factories like [noOob] / [staticOob].
  factory ProvisioningParameters({
    required String deviceName,
    int? oobMethod,
    String? oobData,
    bool enablePrivacy = false,
  }) {
    return ProvisioningParameters._(
      deviceName: deviceName,
      oobMethod: oobMethod ?? 0,
      oobData: oobData,
      enablePrivacy: enablePrivacy,
    );
  }

  factory ProvisioningParameters.noOob({
    required String deviceName,
    bool enablePrivacy = false,
  }) {
    return ProvisioningParameters._(
      deviceName: deviceName,
      oobMethod: 0,
      oobData: null,
      enablePrivacy: enablePrivacy,
    );
  }

  factory ProvisioningParameters.staticOob({
    required String deviceName,
    required String hex,
    bool enablePrivacy = false,
  }) {
    return ProvisioningParameters._(
      deviceName: deviceName,
      oobMethod: 1,
      oobData: hex,
      enablePrivacy: enablePrivacy,
    );
  }

  /// Output OOB means the device outputs a value (number/text) and user enters it in the app.
  factory ProvisioningParameters.outputOob({
    required String deviceName,
    String? data,
    bool enablePrivacy = false,
  }) {
    return ProvisioningParameters._(
      deviceName: deviceName,
      oobMethod: 2,
      oobData: data,
      enablePrivacy: enablePrivacy,
    );
  }

  /// Input OOB means the app provides a value (number/text) and the device inputs it.
  factory ProvisioningParameters.inputOob({
    required String deviceName,
    String? data,
    bool enablePrivacy = false,
  }) {
    return ProvisioningParameters._(
      deviceName: deviceName,
      oobMethod: 3,
      oobData: data,
      enablePrivacy: enablePrivacy,
    );
  }

  void _validate() {
    if (deviceName.trim().isEmpty) {
      throw ArgumentError.value(deviceName, 'deviceName', 'Must not be empty.');
    }
    if (oobMethod < 0 || oobMethod > 3) {
      throw ArgumentError.value(oobMethod, 'oobMethod', 'Must be 0..3.');
    }
    if (oobMethod == 0) {
      if (oobData != null && oobData!.isNotEmpty) {
        throw ArgumentError.value(oobData, 'oobData', 'Must be null/empty when no OOB is used.');
      }
      return;
    }
    if (oobMethod == 1) {
      final v = oobData ?? '';
      if (v.isEmpty) {
        throw ArgumentError('Static OOB requires non-empty hex payload.');
      }
      final hex = v.startsWith('0x') ? v.substring(2) : v;
      final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
      if (!isHex || (hex.length % 2 != 0)) {
        throw ArgumentError.value(v, 'oobData', 'Static OOB must be even-length hex (no separators).');
      }
      final bytesLen = hex.length ~/ 2;
      if (bytesLen < 1 || bytesLen > 32) {
        throw ArgumentError.value(v, 'oobData', 'Static OOB must be 1..32 bytes.');
      }
      return;
    }
    // output/input OOB: data may be null initially; UI flow can fill it later.
  }
}
