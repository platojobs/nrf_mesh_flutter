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

  final StreamController<UnprovisionedDevice> _scanController =
      StreamController<UnprovisionedDevice>.broadcast();
  final StreamController<MeshMessage> _messageController =
      StreamController<MeshMessage>.broadcast();

  bool _scanStarted = false;

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
  Future<bool> exportNetwork(String path) async => true;

  @override
  Future<bool> importNetwork(String path) async => true;

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
    final node = ProvisionedNode(
      uuid: device.deviceId,
      unicastAddress: '0x0001',
      elements: const [],
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

  /// Test helper: emit a fake unprovisioned device discovery event.
  void emitDiscoveredDevice(UnprovisionedDevice device) {
    _scanController.add(device);
  }

  /// Test helper: emit a fake incoming mesh message.
  void emitIncomingMessage(MeshMessage message) {
    _messageController.add(message);
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
  }
}

