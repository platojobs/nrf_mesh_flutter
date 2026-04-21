import 'dart:async';

import '../models/mesh_group.dart';
import '../models/mesh_message.dart';
import '../models/mesh_network.dart';
import '../models/provisioned_node.dart';
import '../models/unprovisioned_device.dart';
import '../platform_interface/platojobs_mesh_platform.dart';

class FakeMeshScenarioStep {
  FakeMeshScenarioStep._(this.delay, this.action);

  final Duration delay;
  final void Function(FakePlatoJobsMeshBridge bridge) action;

  static FakeMeshScenarioStep discoveredDevice(
    UnprovisionedDevice device, {
    Duration delay = Duration.zero,
  }) {
    return FakeMeshScenarioStep._(
      delay,
      (b) => b.emitDiscoveredDevice(device),
    );
  }

  static FakeMeshScenarioStep incomingMessage(
    MeshMessage message, {
    Duration delay = Duration.zero,
  }) {
    return FakeMeshScenarioStep._(delay, (b) => b.emitIncomingMessage(message));
  }

  static FakeMeshScenarioStep scanError(
    Object error, {
    Duration delay = Duration.zero,
  }) {
    return FakeMeshScenarioStep._(delay, (b) => b.emitScanError(error));
  }
}

class FakeMeshScenario {
  FakeMeshScenario({List<FakeMeshScenarioStep>? steps})
      : steps = steps ?? <FakeMeshScenarioStep>[];

  final List<FakeMeshScenarioStep> steps;

  FakeMeshScenario add(FakeMeshScenarioStep step) {
    steps.add(step);
    return this;
  }
}

/// A lightweight fake implementation of [PlatoJobsMeshBridge] for UI development
/// and unit tests without real Mesh hardware.
class FakePlatoJobsMeshBridge extends PlatoJobsMeshBridge {
  FakePlatoJobsMeshBridge({this.scenario});

  /// Optional scripted scenario that will run when scanning starts.
  final FakeMeshScenario? scenario;

  Duration scanStartDelay = Duration.zero;
  bool echoSentMessagesToIncomingStream = true;

  Object? nextSendMessageError;
  Duration nextSendMessageDelay = Duration.zero;

  Object? nextProvisionError;
  Duration nextProvisionDelay = Duration.zero;

  Object? nextExportNetworkError;
  Duration nextExportNetworkDelay = Duration.zero;

  Object? nextImportNetworkError;
  Duration nextImportNetworkDelay = Duration.zero;

  final StreamController<UnprovisionedDevice> _scanController =
      StreamController<UnprovisionedDevice>.broadcast();
  final StreamController<MeshMessage> _messageController =
      StreamController<MeshMessage>.broadcast();
  final StreamController<MeshMessage> _sentMessageController =
      StreamController<MeshMessage>.broadcast();

  bool _scanStarted = false;
  int _nextUnicastAddress = 1;

  final Map<String, MeshNetwork> _networksByPath = <String, MeshNetwork>{};
  final List<MeshMessage> _sentMessages = <MeshMessage>[];

  Stream<MeshMessage> get sentMessageStream => _sentMessageController.stream;
  List<MeshMessage> get sentMessages => List<MeshMessage>.unmodifiable(_sentMessages);

  MeshNetwork _network = MeshNetwork(
    networkId: 'fake-network',
    name: 'Fake Mesh Network',
    networkKeys: const [],
    appKeys: const [],
    nodes: const [],
    groups: const [],
    provisioner: Provisioner(
      name: 'Fake Provisioner',
      provisionerId: 'fake-provisioner',
      addressRange: <int>[1, 256],
    ),
  );

  final List<ProvisionedNode> _nodes = <ProvisionedNode>[];
  final List<MeshGroup> _groups = <MeshGroup>[];

  // P1 configuration state (purely in-memory for tests/UI)
  //
  // Key format: "$elementAddress:$modelId"
  final Map<String, Set<int>> _boundAppKeysByModel = <String, Set<int>>{};
  final Map<String, Set<int>> _subscriptionsByModel = <String, Set<int>>{};
  final Map<String, ({int publishAddress, int appKeyIndex, int? ttl})>
      _publicationByModel =
      <String, ({int publishAddress, int appKeyIndex, int? ttl})>{};

  String _modelKey(int elementAddress, int modelId) => '$elementAddress:$modelId';

  @override
  Future<void> initialize() async {
    // no-op
  }

  @override
  Future<MeshNetwork> createNetwork(String name) async {
    _network = MeshNetwork(
      networkId: 'fake-network',
      name: name,
      networkKeys: const [],
      appKeys: const [],
      nodes: _nodes,
      groups: _groups,
      provisioner: _network.provisioner,
    );
    return _network;
  }

  @override
  Future<MeshNetwork> loadNetwork() async => _network;

  @override
  Future<bool> saveNetwork() async => true;

  @override
  Future<bool> exportNetwork(String path) async {
    if (nextExportNetworkDelay != Duration.zero) {
      await Future<void>.delayed(nextExportNetworkDelay);
      nextExportNetworkDelay = Duration.zero;
    }
    final error = nextExportNetworkError;
    if (error != null) {
      nextExportNetworkError = null;
      throw error;
    }
    _networksByPath[path] = _network;
    return true;
  }

  @override
  Future<bool> importNetwork(String path) async {
    if (nextImportNetworkDelay != Duration.zero) {
      await Future<void>.delayed(nextImportNetworkDelay);
      nextImportNetworkDelay = Duration.zero;
    }
    final error = nextImportNetworkError;
    if (error != null) {
      nextImportNetworkError = null;
      throw error;
    }
    final loaded = _networksByPath[path];
    if (loaded == null) return false;
    _network = loaded;
    return true;
  }

  @override
  Stream<UnprovisionedDevice> scanForDevices() {
    // Fire-and-forget scripted scenario when scan starts.
    //
    // We schedule this to avoid emitting before the caller attaches a listener.
    scheduleMicrotask(() => unawaited(startScenarioIfNeeded()));
    return _scanController.stream;
  }

  @override
  Future<void> stopScan() async {
    // no-op
  }

  @override
  Future<ProvisionedNode> provisionDevice(
    UnprovisionedDevice device,
    dynamic params,
  ) async {
    if (nextProvisionDelay != Duration.zero) {
      await Future<void>.delayed(nextProvisionDelay);
      nextProvisionDelay = Duration.zero;
    }
    final provisionError = nextProvisionError;
    if (provisionError != null) {
      nextProvisionError = null;
      throw provisionError;
    }

    final unicast = _nextUnicastAddress;
    _nextUnicastAddress += 1;

    final elementAddress = unicast;
    const genericOnOffServer = 0x1000;
    const genericLevelServer = 0x1002;

    final node = ProvisionedNode(
      uuid: device.deviceId,
      unicastAddress: '0x${unicast.toRadixString(16).padLeft(4, '0')}',
      elements: <Element>[
        Element(
          address: '0x${elementAddress.toRadixString(16).padLeft(4, '0')}',
          models: <Model>[
            Model(
              modelId: '$genericOnOffServer',
              modelName: 'Generic OnOff Server',
              isServer: true,
              isClient: false,
            ),
            Model(
              modelId: '$genericLevelServer',
              modelName: 'Generic Level Server',
              isServer: true,
              isClient: false,
            ),
          ],
        ),
      ],
      networkKeys: const [],
      appKeys: const [],
      features: NodeFeatures(
        relay: false,
        proxy: true,
        friend: false,
        lowPower: false,
      ),
    );
    _nodes.add(node);
    return node;
  }

  @override
  Future<void> sendMessage(MeshMessage message) async {
    if (nextSendMessageDelay != Duration.zero) {
      await Future<void>.delayed(nextSendMessageDelay);
      nextSendMessageDelay = Duration.zero;
    }

    final error = nextSendMessageError;
    if (error != null) {
      nextSendMessageError = null;
      throw error;
    }

    _sentMessages.add(message);
    _sentMessageController.add(message);

    if (echoSentMessagesToIncomingStream) {
      _messageController.add(message);
    }
  }

  @override
  Stream<MeshMessage> get messageStream => _messageController.stream;

  @override
  Future<List<ProvisionedNode>> getNodes() async => List.unmodifiable(_nodes);

  @override
  Future<void> removeNode(String nodeId) async {
    _nodes.removeWhere((n) => n.uuid == nodeId);
  }

  @override
  Future<MeshGroup> createGroup(String name) async {
    final group = MeshGroup(
      groupId: 'fake-group-${_groups.length + 1}',
      name: name,
      address: '0xC000',
      nodeIds: const [],
    );
    _groups.add(group);
    return group;
  }

  @override
  Future<List<MeshGroup>> getGroups() async => List.unmodifiable(_groups);

  @override
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    final idx = _groups.indexWhere((g) => g.groupId == groupId);
    if (idx == -1) return;
    final group = _groups[idx];
    final updated = MeshGroup(
      groupId: group.groupId,
      name: group.name,
      address: group.address,
      nodeIds: <String>[...group.nodeIds, nodeId],
    );
    _groups[idx] = updated;
  }

  @override
  Future<bool> bindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    final key = _modelKey(elementAddress, modelId);
    final set = _boundAppKeysByModel.putIfAbsent(key, () => <int>{});
    set.add(appKeyIndex);
    _applyConfigToNodes(elementAddress: elementAddress, modelId: modelId);
    return true;
  }

  @override
  Future<bool> unbindAppKey(int elementAddress, int modelId, int appKeyIndex) async {
    final key = _modelKey(elementAddress, modelId);
    _boundAppKeysByModel[key]?.remove(appKeyIndex);
    _applyConfigToNodes(elementAddress: elementAddress, modelId: modelId);
    return true;
  }

  @override
  Future<bool> addSubscription(int elementAddress, int modelId, int address) async {
    final key = _modelKey(elementAddress, modelId);
    final set = _subscriptionsByModel.putIfAbsent(key, () => <int>{});
    set.add(address);
    _applyConfigToNodes(elementAddress: elementAddress, modelId: modelId);
    return true;
  }

  @override
  Future<bool> removeSubscription(int elementAddress, int modelId, int address) async {
    final key = _modelKey(elementAddress, modelId);
    _subscriptionsByModel[key]?.remove(address);
    _applyConfigToNodes(elementAddress: elementAddress, modelId: modelId);
    return true;
  }

  @override
  Future<bool> setPublication(
    int elementAddress,
    int modelId,
    int publishAddress,
    int appKeyIndex, {
    int? ttl,
  }) async {
    final key = _modelKey(elementAddress, modelId);
    _publicationByModel[key] =
        (publishAddress: publishAddress, appKeyIndex: appKeyIndex, ttl: ttl);
    _applyConfigToNodes(elementAddress: elementAddress, modelId: modelId);
    return true;
  }

  void _applyConfigToNodes({
    required int elementAddress,
    required int modelId,
  }) {
    final key = _modelKey(elementAddress, modelId);
    final bound = _boundAppKeysByModel[key] ?? const <int>{};
    final subs = _subscriptionsByModel[key] ?? const <int>{};
    final pub = _publicationByModel[key];

    final elementHex = '0x${elementAddress.toRadixString(16).padLeft(4, '0')}';
    final modelIdStr = '$modelId';

    for (var i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      final updatedElements = node.elements.map((e) {
        if (e.address != elementHex) return e;
        final updatedModels = e.models.map((m) {
          if (m.modelId != modelIdStr) return m;
          return Model(
            modelId: m.modelId,
            modelName: m.modelName,
            isServer: m.isServer,
            isClient: m.isClient,
            boundAppKeyIndexes: bound.toList(growable: false),
            subscriptions: subs.toList(growable: false),
            publication: pub == null
                ? null
                : Publication(
                    address: pub.publishAddress,
                    appKeyIndex: pub.appKeyIndex,
                    ttl: pub.ttl,
                  ),
          );
        }).toList(growable: false);
        return Element(address: e.address, models: updatedModels);
      }).toList(growable: false);

      _nodes[i] = ProvisionedNode(
        uuid: node.uuid,
        unicastAddress: node.unicastAddress,
        elements: updatedElements,
        networkKeys: node.networkKeys,
        appKeys: node.appKeys,
        features: node.features,
      );
    }
  }

  /// Test helper: emit a fake unprovisioned device discovery event.
  void emitDiscoveredDevice(UnprovisionedDevice device) {
    _scanController.add(device);
  }

  /// Test helper: emit a fake incoming mesh message.
  void emitIncomingMessage(MeshMessage message) {
    _messageController.add(message);
  }

  /// Test helper: emit an error on scan stream.
  void emitScanError(Object error) {
    _scanController.addError(error);
  }

  /// Reset fake in-memory state.
  void reset() {
    _scanStarted = false;
    _nextUnicastAddress = 1;
    _nodes.clear();
    _groups.clear();
    _sentMessages.clear();
    _networksByPath.clear();
    _boundAppKeysByModel.clear();
    _subscriptionsByModel.clear();
    _publicationByModel.clear();
  }

  /// Starts the scripted scenario (if any). Safe to call multiple times.
  Future<void> startScenarioIfNeeded() async {
    if (_scanStarted) return;
    _scanStarted = true;

    if (scanStartDelay != Duration.zero) {
      await Future<void>.delayed(scanStartDelay);
    }
    final s = scenario;
    if (s == null) return;
    for (final step in s.steps) {
      if (step.delay != Duration.zero) {
        await Future<void>.delayed(step.delay);
      }
      step.action(this);
    }
  }

  /// Dispose stream controllers.
  Future<void> dispose() async {
    await _scanController.close();
    await _messageController.close();
    await _sentMessageController.close();
  }
}

