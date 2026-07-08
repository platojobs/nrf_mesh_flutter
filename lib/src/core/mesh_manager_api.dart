// ignore_for_file: public_member_api_docs

import 'dart:async';

import '../models/mesh_network.dart' as net_models;
import '../models/provisioned_node.dart' as node_models;
import '../models/unprovisioned_device.dart' as dev_models;
import '../models/mesh_message.dart' as msg_models;
import '../models/mesh_group.dart' as group_models;
import '../models/rx_access_message.dart' as rx_models;
import '../models/mesh_bearer_snapshot.dart';
import '../models/mesh_capabilities.dart';
import '../models/mesh_proxy_filter.dart';
import '../models/mesh_proxy_auto_reconnect.dart';
import 'command_queue.dart';
import 'mesh_exceptions.dart';
import '../platform_interface/platojobs_mesh_platform.dart' as platform;
import '../platform_interface/pigeon_generated.dart' as pigeon;

class MeshManagerApi {
  platform.PlatoJobsMeshBridge get _platform =>
      platform.PlatoJobsMeshBridge.instance;
  final PlatoJobsMeshCommandQueue _commandQueue = PlatoJobsMeshCommandQueue();
  static const Duration _bearerTransitionTimeout = Duration(seconds: 15);
  bool _proxyConnecting = false;
  bool _provisioningConnecting = false;
  MeshProxyAutoReconnectPolicy _proxyAutoReconnectPolicy =
      MeshProxyAutoReconnectPolicy.disabled;
  Timer? _proxyHealthCheckTimer;
  Timer? _proxyReconnectTimer;
  bool _proxyReconnectInProgress = false;
  int _proxyReconnectAttempt = 0;
  String? _lastProxyDeviceId;
  int? _lastProxyUnicastAddress;
  bool _explicitProxyFilterStateKnown = false;
  MeshProxyFilterType _explicitProxyFilterType = MeshProxyFilterType.whitelist;
  final Set<int> _explicitProxyFilterAddresses = <int>{};

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw platoJobsMeshMapException(e);
    }
  }

  /// Initialize the mesh manager API
  Future<void> initialize() async {
    _resetExplicitProxyFilterState();
    _stopProxyAutoReconnect(clearTarget: true);
    await _guard(() => _platform.initialize());
  }

  // Network management
  /// Create a new mesh network
  Future<net_models.MeshNetwork> createNetwork(String name) async {
    return await _guard(() => _platform.createNetwork(name));
  }

  /// Load an existing mesh network
  Future<net_models.MeshNetwork> loadNetwork() async {
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
  Stream<dev_models.UnprovisionedDevice> scanForDevices() {
    return _platform.scanForDevices();
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    return await _guard(() => _platform.stopScan());
  }

  // Provisioning
  /// Provision a device into the mesh network
  Future<node_models.ProvisionedNode> provisionDevice(
    dev_models.UnprovisionedDevice device,
    dynamic params,
  ) async {
    return await _guard(() => _platform.provisionDevice(device, params));
  }

  // Message sending
  /// Send a mesh message
  Future<void> sendMessage(msg_models.MeshMessage message) async {
    return _guard(
      () => _commandQueue.enqueue(
        () => _platform.sendMessage(message),
        debugLabel: 'sendMessage(${message.opcode})',
      ),
    );
  }

  /// Stream of received mesh messages
  Stream<msg_models.MeshMessage> get messageStream {
    return _platform.messageStream;
  }

  /// Stream of received Access messages with best-effort metadata.
  Stream<rx_models.RxAccessMessage> get rxAccessMessageStream {
    return _platform.rxAccessMessageStream;
  }

  Stream<pigeon.ProvisioningEvent> get provisioningEventStream {
    return _platform.provisioningEventStream;
  }

  /// Hint stream when native mesh DB may have changed (refresh nodes/groups/keys).
  Stream<int> get meshNetworkUpdatedStream {
    return _platform.meshNetworkUpdatedStream;
  }

  Future<bool> provideProvisioningOobNumeric(String deviceId, int value) async {
    return await _guard(
      () => _platform.provideProvisioningOobNumeric(deviceId, value),
    );
  }

  Future<bool> provideProvisioningOobAlphaNumeric(
    String deviceId,
    String value,
  ) async {
    return await _guard(
      () => _platform.provideProvisioningOobAlphaNumeric(deviceId, value),
    );
  }

  /// Whether the native side can reliably populate source address for incoming Access messages.
  Future<bool> supportsRxSourceAddress() async {
    return await _guard(() => _platform.supportsRxSourceAddress());
  }

  /// Phase **1.4** capability probe — currently **false** on both stacks.
  Future<bool> supportsRxAppKeyIndex() async {
    return await _guard(() => _platform.supportsRxAppKeyIndex());
  }

  /// Phase **3.2** capability probe — **Android** exposes explicit controls; **iOS** remains automatic-only on the current official SDK surface.
  Future<bool> supportsProxyFilter() async {
    return await _guard(() => _platform.supportsProxyFilter());
  }

  /// Whether the native SDK already manages Proxy Filter automatically.
  Future<bool> supportsAutomaticProxyFilter() async {
    return await _guard(() => _platform.supportsAutomaticProxyFilter());
  }

  /// Aggregated capability snapshot for current bridge feature support.
  Future<MeshCapabilities> getCapabilities() async {
    final rxSourceAddress = await supportsRxSourceAddress();
    final rxAppKeyIndex = await supportsRxAppKeyIndex();
    final proxyFilter = await supportsProxyFilter();
    final automaticProxyFilter = await supportsAutomaticProxyFilter();
    return MeshCapabilities.fromSupportFlags(
      rxSourceAddress: rxSourceAddress,
      rxAppKeyIndex: rxAppKeyIndex,
      supportsProxyFilter: proxyFilter,
      supportsAutomaticProxyFilter: automaticProxyFilter,
    );
  }

  MeshProxyAutoReconnectPolicy getProxyAutoReconnectPolicy() {
    return _proxyAutoReconnectPolicy;
  }

  void setProxyAutoReconnectPolicy(MeshProxyAutoReconnectPolicy policy) {
    _proxyAutoReconnectPolicy = policy;
    if (!policy.enabled) {
      _stopProxyAutoReconnect(clearTarget: false);
      return;
    }

    _proxyHealthCheckTimer?.cancel();
    _proxyReconnectTimer?.cancel();
    if (_lastProxyDeviceId != null && _lastProxyUnicastAddress != null) {
      _startProxyHealthCheck();
    }
  }

  Future<bool> setProxyFilterType(MeshProxyFilterType type) async {
    return _guard(
      () => _commandQueue.enqueue(() async {
        final ok = await _platform.setProxyFilterType(type);
        if (ok) {
          _explicitProxyFilterStateKnown = true;
          _explicitProxyFilterType = type;
          _explicitProxyFilterAddresses.clear();
        }
        return ok;
      }, debugLabel: 'setProxyFilterType(${type.name})'),
    );
  }

  Future<bool> addProxyFilterAddresses(List<int> addresses) async {
    _validateProxyFilterAddresses(addresses);
    final normalized = _normalizeProxyFilterAddresses(addresses);
    return _guard(
      () => _commandQueue.enqueue(() async {
        final ok = await _platform.addProxyFilterAddresses(normalized);
        if (ok && _explicitProxyFilterStateKnown) {
          _explicitProxyFilterAddresses.addAll(normalized);
        }
        return ok;
      }, debugLabel: 'addProxyFilterAddresses(${normalized.length})'),
    );
  }

  Future<bool> removeProxyFilterAddresses(List<int> addresses) async {
    _validateProxyFilterAddresses(addresses);
    final normalized = _normalizeProxyFilterAddresses(addresses);
    return _guard(
      () => _commandQueue.enqueue(() async {
        final ok = await _platform.removeProxyFilterAddresses(normalized);
        if (ok && _explicitProxyFilterStateKnown) {
          _explicitProxyFilterAddresses.removeAll(normalized);
        }
        return ok;
      }, debugLabel: 'removeProxyFilterAddresses(${normalized.length})'),
    );
  }

  Future<bool> syncProxyFilter(
    MeshProxyFilterType type,
    List<int> addresses,
  ) async {
    _validateProxyFilterAddressRange(addresses);
    final desired = _normalizeProxyFilterAddresses(addresses);
    return _guard(
      () => _commandQueue.enqueue(() async {
        if (!_explicitProxyFilterStateKnown ||
            _explicitProxyFilterType != type) {
          final setOk = await _platform.setProxyFilterType(type);
          if (!setOk) {
            return false;
          }
          _explicitProxyFilterStateKnown = true;
          _explicitProxyFilterType = type;
          _explicitProxyFilterAddresses.clear();
        }

        final desiredSet = desired.toSet();
        final toRemove =
            _explicitProxyFilterAddresses.difference(desiredSet).toList()
              ..sort();
        if (toRemove.isNotEmpty) {
          final removeOk = await _platform.removeProxyFilterAddresses(toRemove);
          if (!removeOk) {
            return false;
          }
          _explicitProxyFilterAddresses.removeAll(toRemove);
        }

        final toAdd =
            desiredSet.difference(_explicitProxyFilterAddresses).toList()
              ..sort();
        if (toAdd.isNotEmpty) {
          final addOk = await _platform.addProxyFilterAddresses(toAdd);
          if (!addOk) {
            return false;
          }
          _explicitProxyFilterAddresses.addAll(toAdd);
        }
        return true;
      }, debugLabel: 'syncProxyFilter(${type.name}, ${desired.length})'),
    );
  }

  List<int> _normalizeProxyFilterAddresses(List<int> addresses) {
    final normalized = addresses.toSet().toList()..sort();
    return List<int>.unmodifiable(normalized);
  }

  void _validateProxyFilterAddresses(List<int> addresses) {
    if (addresses.isEmpty) {
      throw ArgumentError.value(
        addresses,
        'addresses',
        'Proxy Filter address list must not be empty',
      );
    }
    _validateProxyFilterAddressRange(addresses);
  }

  void _validateProxyFilterAddressRange(List<int> addresses) {
    for (final address in addresses) {
      if (address < 0x0001 || address > 0xFFFF) {
        throw ArgumentError.value(
          address,
          'addresses',
          'Proxy Filter address must be in 0x0001..0xFFFF',
        );
      }
    }
  }

  void _resetExplicitProxyFilterState() {
    _explicitProxyFilterStateKnown = false;
    _explicitProxyFilterType = MeshProxyFilterType.whitelist;
    _explicitProxyFilterAddresses.clear();
  }

  void _rememberProxyTarget(String deviceId, int proxyUnicastAddress) {
    _lastProxyDeviceId = deviceId;
    _lastProxyUnicastAddress = proxyUnicastAddress;
  }

  void _stopProxyAutoReconnect({required bool clearTarget}) {
    _proxyHealthCheckTimer?.cancel();
    _proxyHealthCheckTimer = null;
    _proxyReconnectTimer?.cancel();
    _proxyReconnectTimer = null;
    _proxyReconnectInProgress = false;
    _proxyReconnectAttempt = 0;
    if (clearTarget) {
      _lastProxyDeviceId = null;
      _lastProxyUnicastAddress = null;
    }
  }

  void _startProxyHealthCheck() {
    if (!_proxyAutoReconnectPolicy.enabled ||
        _lastProxyDeviceId == null ||
        _lastProxyUnicastAddress == null) {
      return;
    }

    _proxyHealthCheckTimer?.cancel();
    _proxyHealthCheckTimer = Timer.periodic(
      _proxyAutoReconnectPolicy.healthCheckInterval,
      (_) => unawaited(_checkProxyHealth()),
    );
  }

  Future<void> _checkProxyHealth() async {
    if (!_proxyAutoReconnectPolicy.enabled ||
        _proxyReconnectInProgress ||
        _proxyConnecting ||
        _lastProxyDeviceId == null ||
        _lastProxyUnicastAddress == null) {
      return;
    }

    bool connected;
    try {
      connected = await isProxyConnected();
    } catch (_) {
      return;
    }
    if (connected) {
      _proxyReconnectAttempt = 0;
      return;
    }

    _scheduleProxyReconnect();
  }

  void _scheduleProxyReconnect() {
    if (!_proxyAutoReconnectPolicy.enabled ||
        _proxyReconnectInProgress ||
        _proxyReconnectTimer != null ||
        _lastProxyDeviceId == null ||
        _lastProxyUnicastAddress == null ||
        _proxyReconnectAttempt >= _proxyAutoReconnectPolicy.maxAttempts) {
      return;
    }

    _proxyReconnectTimer = Timer(_proxyAutoReconnectPolicy.retryDelay, () {
      _proxyReconnectTimer = null;
      unawaited(_runProxyReconnectAttempt());
    });
  }

  Future<void> _runProxyReconnectAttempt() async {
    final deviceId = _lastProxyDeviceId;
    final unicast = _lastProxyUnicastAddress;
    if (!_proxyAutoReconnectPolicy.enabled ||
        _proxyReconnectInProgress ||
        _proxyConnecting ||
        deviceId == null ||
        unicast == null) {
      return;
    }

    _proxyReconnectInProgress = true;
    _proxyReconnectAttempt += 1;
    var shouldRetry = false;
    try {
      final ok = await connectProxy(deviceId, unicast);
      shouldRetry = !ok;
    } catch (_) {
      shouldRetry = true;
    } finally {
      _proxyReconnectInProgress = false;
    }

    if (shouldRetry &&
        _proxyReconnectAttempt < _proxyAutoReconnectPolicy.maxAttempts) {
      _scheduleProxyReconnect();
    }
  }

  /// Clear persisted secure mesh state used for stable Access sending.
  Future<void> clearSecureStorage() async {
    return await _guard(() => _platform.clearSecureStorage());
  }

  /// **Deprecated (Phase 1.3).** See [PlatoJobsMeshBridge.setExperimentalRxMetadataEnabled].
  @Deprecated(
    'Phase 1.3: Prefer default Android public RX path; reflection may break across Nordic releases.',
  )
  Future<void> setExperimentalRxMetadataEnabled(bool enabled) async {
    return await _guard(
      () => _platform.setExperimentalRxMetadataEnabled(enabled),
    );
  }

  // Node management
  /// Get all provisioned nodes
  Future<List<node_models.ProvisionedNode>> getNodes() async {
    return await _guard(() => _platform.getNodes());
  }

  /// Remove a node from the network
  Future<void> removeNode(String nodeId) async {
    return await _guard(() => _platform.removeNode(nodeId));
  }

  // Group management
  /// Create a new mesh group
  Future<group_models.MeshGroup> createGroup(String name) async {
    return await _guard(() => _platform.createGroup(name));
  }

  /// Get all mesh groups
  Future<List<group_models.MeshGroup>> getGroups() async {
    return await _guard(() => _platform.getGroups());
  }

  Future<group_models.MeshGroup> createVirtualGroup(
    String name,
    List<int> labelUuid,
  ) async {
    return await _guard(() => _platform.createVirtualGroup(name, labelUuid));
  }

  Future<bool> removeGroup(String groupId) async {
    return await _guard(() => _platform.removeGroup(groupId));
  }

  Future<bool> addSubscriptionVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
  ) async {
    return await _guard(
      () =>
          _platform.addSubscriptionVirtual(elementAddress, modelId, labelUuid),
    );
  }

  Future<bool> removeSubscriptionVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
  ) async {
    return await _guard(
      () => _platform.removeSubscriptionVirtual(
        elementAddress,
        modelId,
        labelUuid,
      ),
    );
  }

  Future<bool> setPublicationVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
    int appKeyIndex, {
    int? ttl,
  }) async {
    return await _guard(
      () => _platform.setPublicationVirtual(
        elementAddress,
        modelId,
        labelUuid,
        appKeyIndex,
        ttl: ttl,
      ),
    );
  }

  // M2: Configuration foundation
  Future<bool> fetchCompositionData(int destination, {int page = 0}) async {
    return await _guard(
      () => _platform.fetchCompositionData(destination, page: page),
    );
  }

  Future<bool> addNetworkKey(int netKeyIndex, String keyHex) async {
    return await _guard(() => _platform.addNetworkKey(netKeyIndex, keyHex));
  }

  Future<bool> addAppKey(int appKeyIndex, String keyHex) async {
    return await _guard(() => _platform.addAppKey(appKeyIndex, keyHex));
  }

  Future<List<net_models.NetworkKey>> getNetworkKeys() async {
    return await _guard(() => _platform.getNetworkKeys());
  }

  Future<List<net_models.AppKey>> getAppKeys() async {
    return await _guard(() => _platform.getAppKeys());
  }

  // M2 acceptance: node config + reset + bundle export/import
  Future<bool> setNodeDefaultTtl(int destination, int ttl) async {
    return await _guard(() => _platform.setNodeDefaultTtl(destination, ttl));
  }

  Future<bool> setNodeRelay(
    int destination,
    bool enabled,
    int retransmitCount,
    int retransmitIntervalMs,
  ) async {
    return await _guard(
      () => _platform.setNodeRelay(
        destination,
        enabled,
        retransmitCount,
        retransmitIntervalMs,
      ),
    );
  }

  Future<bool> setNodeGattProxy(int destination, bool enabled) async {
    return await _guard(() => _platform.setNodeGattProxy(destination, enabled));
  }

  Future<bool> setNodeFriend(int destination, bool enabled) async {
    return await _guard(() => _platform.setNodeFriend(destination, enabled));
  }

  Future<bool> setNodeBeacon(int destination, bool enabled) async {
    return await _guard(() => _platform.setNodeBeacon(destination, enabled));
  }

  Future<bool> setNodeNetworkTransmit(
    int destination,
    int count,
    int intervalMs,
  ) async {
    return await _guard(
      () => _platform.setNodeNetworkTransmit(destination, count, intervalMs),
    );
  }

  Future<bool> nodeReset(int destination) async {
    return await _guard(() => _platform.nodeReset(destination));
  }

  Future<bool> exportConfigurationBundle(String path) async {
    return await _guard(() => _platform.exportConfigurationBundle(path));
  }

  Future<bool> importConfigurationBundle(String path) async {
    return await _guard(() => _platform.importConfigurationBundle(path));
  }

  Future<bool> removeNetworkKeyRemote(int destination, int netKeyIndex) async {
    return await _guard(
      () => _platform.removeNetworkKeyRemote(destination, netKeyIndex),
    );
  }

  Future<bool> removeAppKeyRemote(
    int destination,
    int appKeyIndex,
    int boundNetKeyIndex,
  ) async {
    return await _guard(
      () => _platform.removeAppKeyRemote(
        destination,
        appKeyIndex,
        boundNetKeyIndex,
      ),
    );
  }

  Future<int> getKeyRefreshPhase(int destination, int netKeyIndex) async {
    return await _guard(
      () => _platform.getKeyRefreshPhase(destination, netKeyIndex),
    );
  }

  Future<bool> setKeyRefreshPhaseTransition(
    int destination,
    int netKeyIndex,
    int transition,
  ) async {
    return await _guard(
      () => _platform.setKeyRefreshPhaseTransition(
        destination,
        netKeyIndex,
        transition,
      ),
    );
  }

  Future<bool> resetLocalMeshState() async {
    return await _guard(() async {
      final ok = await _platform.resetLocalMeshState();
      if (ok) {
        _resetExplicitProxyFilterState();
        _stopProxyAutoReconnect(clearTarget: true);
      }
      return ok;
    });
  }

  /// Add a node to a group
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    return await _guard(() => _platform.addNodeToGroup(nodeId, groupId));
  }

  // Configuration (P1 - minimal)
  Future<bool> bindAppKey(
    int elementAddress,
    int modelId,
    int appKeyIndex,
  ) async {
    return await _guard(
      () => _platform.bindAppKey(elementAddress, modelId, appKeyIndex),
    );
  }

  Future<bool> unbindAppKey(
    int elementAddress,
    int modelId,
    int appKeyIndex,
  ) async {
    return await _guard(
      () => _platform.unbindAppKey(elementAddress, modelId, appKeyIndex),
    );
  }

  Future<bool> addSubscription(
    int elementAddress,
    int modelId,
    int address,
  ) async {
    return await _guard(
      () => _platform.addSubscription(elementAddress, modelId, address),
    );
  }

  Future<bool> removeSubscription(
    int elementAddress,
    int modelId,
    int address,
  ) async {
    return await _guard(
      () => _platform.removeSubscription(elementAddress, modelId, address),
    );
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
    _rememberProxyTarget(deviceId, proxyUnicastAddress);
    _proxyReconnectTimer?.cancel();
    _proxyReconnectTimer = null;
    return _guard(
      () => _commandQueue.enqueue(
        () async {
          _proxyConnecting = true;
          _resetExplicitProxyFilterState();
          try {
            final ok = await _platform.connectProxy(
              deviceId,
              proxyUnicastAddress,
            );
            if (ok) {
              _proxyReconnectAttempt = 0;
              if (_proxyAutoReconnectPolicy.enabled) {
                _startProxyHealthCheck();
              }
            } else if (_proxyAutoReconnectPolicy.enabled &&
                !_proxyReconnectInProgress) {
              _scheduleProxyReconnect();
            }
            return ok;
          } finally {
            _proxyConnecting = false;
          }
        },
        timeout: _bearerTransitionTimeout,
        debugLabel: 'connectProxy($deviceId)',
      ),
    );
  }

  Future<bool> disconnectProxy() async {
    _stopProxyAutoReconnect(clearTarget: true);
    return _guard(
      () => _commandQueue.enqueue(
        () async {
          _proxyConnecting = false;
          _resetExplicitProxyFilterState();
          return await _platform.disconnectProxy();
        },
        timeout: _bearerTransitionTimeout,
        debugLabel: 'disconnectProxy()',
      ),
    );
  }

  Future<bool> isProxyConnected() async {
    return await _guard(() => _platform.isProxyConnected());
  }

  Future<bool> connectProvisioning(String deviceId) async {
    return _guard(
      () => _commandQueue.enqueue(
        () async {
          _provisioningConnecting = true;
          try {
            return await _platform.connectProvisioning(deviceId);
          } finally {
            _provisioningConnecting = false;
          }
        },
        timeout: _bearerTransitionTimeout,
        debugLabel: 'connectProvisioning($deviceId)',
      ),
    );
  }

  Future<bool> disconnectProvisioning() async {
    return _guard(
      () => _commandQueue.enqueue(
        () async {
          _provisioningConnecting = false;
          return await _platform.disconnectProvisioning();
        },
        timeout: _bearerTransitionTimeout,
        debugLabel: 'disconnectProvisioning()',
      ),
    );
  }

  Future<bool> isProvisioningConnected() async {
    return await _guard(() => _platform.isProvisioningConnected());
  }

  Future<MeshBearerSnapshot> getMeshBearerSnapshot() async {
    final proxyConnected = await _guard(() => _platform.isProxyConnected());
    final provisioningConnected = await _guard(
      () => _platform.isProvisioningConnected(),
    );
    return MeshBearerSnapshot.fromNativeFlags(
      proxyConnected: proxyConnected,
      provisioningConnected: provisioningConnected,
      proxyConnecting: _proxyConnecting && !proxyConnected,
      provisioningConnecting: _provisioningConnecting && !provisioningConnected,
    );
  }
}

/// Provisioning parameters for mesh devices
class ProvisioningParameters {
  final String deviceName;
  final int oobMethod;
  final String? oobData;
  final bool enablePrivacy;

  ProvisioningParameters({
    required this.deviceName,
    int? oobMethod,
    this.oobData,
    this.enablePrivacy = false,
  }) : oobMethod = oobMethod ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'deviceName': deviceName,
      'oobMethod': oobMethod,
      'oobData': oobData,
      'enablePrivacy': enablePrivacy,
    };
  }
}
