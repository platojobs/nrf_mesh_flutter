import 'dart:async';

import 'src/core/mesh_manager_api.dart';
import 'src/models/mesh_bearer_snapshot.dart';
import 'src/models/mesh_capabilities.dart';
import 'src/models/mesh_proxy_filter.dart';
import 'src/models/mesh_network.dart' as net_models;
import 'src/models/provisioned_node.dart' as node_models;
import 'src/models/unprovisioned_device.dart' as dev_models;
import 'src/models/mesh_group.dart' as group_models;
import 'src/models/mesh_message.dart' as msg_models;
import 'src/models/raw_access_message.dart' as raw_models;
import 'src/models/rx_access_message.dart' as rx_models;
import 'src/messages/scene/scene_messages.dart' as scene_msgs;
import 'src/messages/scene/scene_status.dart' as scene_status;
import 'src/platform_interface/platojobs_mesh_platform.dart' as platform;
import 'src/platform_interface/pigeon_generated.dart' as pigeon;

export 'src/models/mesh_network.dart'
    show MeshNetwork, NetworkKey, AppKey, Provisioner;
export 'src/models/unprovisioned_device.dart' show UnprovisionedDevice;
export 'src/models/provisioned_node.dart'
    show ProvisionedNode, NodeFeatures, Element, Model, Publication;
export 'src/models/mesh_group.dart' show MeshGroup;
export 'src/models/mesh_bearer_snapshot.dart'
    show MeshBearerSnapshot, MeshBearerPhase;
export 'src/models/mesh_capabilities.dart'
    show MeshCapabilities, MeshProxyFilterCapability;
export 'src/models/mesh_proxy_filter.dart' show MeshProxyFilterType;
export 'src/models/mesh_message.dart'
    show
        MeshMessage,
        UnknownMessage,
        GenericOnOffSet,
        GenericLevelSet,
        GenericOnOffStatus,
        GenericLevelStatus;
export 'src/models/raw_access_message.dart' show RawAccessMessage;
export 'src/utils/mesh_virtual_address.dart' show meshVirtualAddressFromLabel;
export 'src/utils/mesh_network_update_debounce.dart'
    show debounceMeshNetworkUpdates;
export 'src/models/rx_access_message.dart'
    show RxAccessMessage, RxMetadataStatus;
export 'src/messages/scene/scene_messages.dart'
    show
        SceneOpcode,
        SceneStore,
        SceneRecall,
        SceneDelete,
        SceneGet,
        SceneRegisterGet;
export 'src/messages/scene/scene_status.dart'
    show SceneStatusCode, SceneStatusMessage, SceneRegisterStatusMessage;
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
    show FakePlatoJobsMeshBridge, FakeMeshScenario, FakeMeshScenarioStep;

/// Application façade over Nordic **MeshNetworkManager** / Kotlin Mesh on native platforms.
///
/// Obtained via [instance]; call [initialize] during app startup.
class PlatoJobsNrfMeshManager {
  /// Shared singleton used by mesh-aware screens and services.
  static final PlatoJobsNrfMeshManager instance =
      PlatoJobsNrfMeshManager._internal();

  /// Equivalent to reading [instance] (provided for symmetry with typical Flutter singletons).
  factory PlatoJobsNrfMeshManager() => instance;
  PlatoJobsNrfMeshManager._internal() {
    if (!platform.PlatoJobsMeshBridge.isInitialized) {
      platform.PlatoJobsMeshBridge.instance =
          platform.PlatoJobsMeshBridgeImpl();
    }
  }

  final MeshManagerApi _meshManagerApi = MeshManagerApi();

  /// Override the platform bridge, intended for tests / mocks.
  static void setBridgeForTesting(platform.PlatoJobsMeshBridge bridge) {
    platform.PlatoJobsMeshBridge.instance = bridge;
  }

  /// Registers platform channels and mesh callbacks; call once after `WidgetsFlutterBinding`.
  Future<void> initialize() async {
    await _meshManagerApi.initialize();
  }

  /// Creates a new empty mesh network with display name [name].
  Future<net_models.MeshNetwork> createNetwork(String name) async {
    return await _meshManagerApi.createNetwork(name);
  }

  /// Loads the persisted mesh network from native storage, if any.
  Future<net_models.MeshNetwork> loadNetwork() async {
    return await _meshManagerApi.loadNetwork();
  }

  /// Persists the current mesh DB (provisioned nodes, keys, etc.) natively.
  Future<bool> saveNetwork() async {
    return await _meshManagerApi.saveNetwork();
  }

  /// Exports node/group/key snapshot for backup or migration (platform-defined JSON).
  Future<bool> exportNetwork(String path) async {
    return await _meshManagerApi.exportNetwork(path);
  }

  /// Imports a previously exported JSON snapshot from [path].
  Future<bool> importNetwork(String path) async {
    return await _meshManagerApi.importNetwork(path);
  }

  /// Starts BLE scan for Mesh Provisioning Service advertisers.
  Stream<dev_models.UnprovisionedDevice> scanForDevices() {
    return _meshManagerApi.scanForDevices();
  }

  /// Stops unprovisioned-device scanning.
  Future<void> stopScan() async {
    return await _meshManagerApi.stopScan();
  }

  /// Runs full provisioning for [device] using [params] (OOB, privacy flags).
  Future<node_models.ProvisionedNode> provisionDevice(
    dev_models.UnprovisionedDevice device,
    ProvisioningParameters params,
  ) async {
    return await _meshManagerApi.provisionDevice(device, params);
  }

  /// Sends a typed client [MeshMessage] (Generic OnOff/Level, scenes, etc.).
  Future<void> sendMessage(msg_models.MeshMessage message) async {
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
    List<int>? virtualLabel,
  }) async {
    return await _meshManagerApi.sendMessage(
      raw_models.RawAccessMessage(
        opCode: opCode,
        parameters: parameters,
        address: address,
        appKeyIndex: appKeyIndex,
        virtualLabel: virtualLabel,
      ),
    );
  }

  /// Incoming Access PDUs mapped to [MeshMessage] (opcode + parameters map).
  Stream<msg_models.MeshMessage> get messageStream {
    return _meshManagerApi.messageStream;
  }

  /// Same traffic as [messageStream] with structured metadata ([RxAccessMessage]).
  Stream<rx_models.RxAccessMessage> get rxAccessMessageStream {
    return _meshManagerApi.rxAccessMessageStream;
  }

  /// Convenience stream: decoded Scene Status (opcode 0x5E).
  Stream<scene_status.SceneStatusMessage> get sceneStatusStream {
    return rxAccessMessageStream
        .map(
          (e) => msg_models.MeshMessage.fromIncoming(
            opcode: e.opcode,
            parameters: e.parameters,
            address: e.source,
            appKeyIndex: null,
          ),
        )
        .where((m) => m is scene_status.SceneStatusMessage)
        .cast<scene_status.SceneStatusMessage>();
  }

  /// Convenience stream: decoded Scene Register Status (opcode 0x8245).
  Stream<scene_status.SceneRegisterStatusMessage>
  get sceneRegisterStatusStream {
    return rxAccessMessageStream
        .map(
          (e) => msg_models.MeshMessage.fromIncoming(
            opcode: e.opcode,
            parameters: e.parameters,
            address: e.source,
            appKeyIndex: null,
          ),
        )
        .where((m) => m is scene_status.SceneRegisterStatusMessage)
        .cast<scene_status.SceneRegisterStatusMessage>();
  }

  // M4: Scenes (client-side helpers).

  /// Sends Scene Store (SIG model) to [destination].
  Future<void> sceneStore({
    required int destination,
    required int appKeyIndex,
    required int sceneNumber,
    List<int>? virtualLabel,
  }) async {
    return await sendMessage(
      scene_msgs.SceneStore(
        sceneNumber: sceneNumber,
        address: destination,
        appKeyIndex: appKeyIndex,
        virtualLabel: virtualLabel,
      ),
    );
  }

  /// Sends Scene Recall (acknowledged).
  Future<void> sceneRecall({
    required int destination,
    required int appKeyIndex,
    required int sceneNumber,
    int? tid,
    int? transitionTime,
    int? delay,
    List<int>? virtualLabel,
  }) async {
    return await sendMessage(
      scene_msgs.SceneRecall(
        sceneNumber: sceneNumber,
        tid: tid,
        transitionTime: transitionTime,
        delay: delay,
        address: destination,
        appKeyIndex: appKeyIndex,
        virtualLabel: virtualLabel,
      ),
    );
  }

  /// Sends Scene Delete (acknowledged).
  Future<void> sceneDelete({
    required int destination,
    required int appKeyIndex,
    required int sceneNumber,
    List<int>? virtualLabel,
  }) async {
    return await sendMessage(
      scene_msgs.SceneDelete(
        sceneNumber: sceneNumber,
        address: destination,
        appKeyIndex: appKeyIndex,
        virtualLabel: virtualLabel,
      ),
    );
  }

  /// Queries current scene on [destination].
  Future<void> sceneGet({
    required int destination,
    required int appKeyIndex,
    List<int>? virtualLabel,
  }) async {
    return await sendMessage(
      scene_msgs.SceneGet(
        address: destination,
        appKeyIndex: appKeyIndex,
        virtualLabel: virtualLabel,
      ),
    );
  }

  /// Reads the scene register list from [destination].
  Future<void> sceneRegisterGet({
    required int destination,
    required int appKeyIndex,
    List<int>? virtualLabel,
  }) async {
    return await sendMessage(
      scene_msgs.SceneRegisterGet(
        address: destination,
        appKeyIndex: appKeyIndex,
        virtualLabel: virtualLabel,
      ),
    );
  }

  /// Provisioning progress, OOB prompts, and completion/failure hooks per device.
  Stream<pigeon.ProvisioningEvent> get provisioningEventStream {
    return _meshManagerApi.provisioningEventStream;
  }

  /// Best-effort signal that native mesh configuration changed (reload caches as needed).
  Stream<int> get meshNetworkUpdatedStream {
    return _meshManagerApi.meshNetworkUpdatedStream;
  }

  /// Provide user input required by Output OOB (numeric).
  Future<bool> provideProvisioningOobNumeric(String deviceId, int value) async {
    return await _meshManagerApi.provideProvisioningOobNumeric(deviceId, value);
  }

  /// Provide user input required by Output OOB (alphanumeric).
  Future<bool> provideProvisioningOobAlphaNumeric(
    String deviceId,
    String value,
  ) async {
    return await _meshManagerApi.provideProvisioningOobAlphaNumeric(
      deviceId,
      value,
    );
  }

  /// Whether the native side can reliably populate source address for incoming Access messages.
  Future<bool> supportsRxSourceAddress() async {
    return await _meshManagerApi.supportsRxSourceAddress();
  }

  /// Phase **1.4**: whether inbound AppKey index **could** be exposed on RX paths.
  ///
  /// Currently **false** until Nordic stacks align; avoids silent assumptions.
  Future<bool> supportsRxAppKeyIndex() async {
    return await _meshManagerApi.supportsRxAppKeyIndex();
  }

  /// Phase **3.2**: whether **Proxy Filter** can be configured from Dart (**false** today).
  Future<bool> supportsProxyFilter() async {
    return await _meshManagerApi.supportsProxyFilter();
  }

  /// Whether the native SDK manages Proxy Filter automatically even without
  /// explicit Flutter-side controls.
  Future<bool> supportsAutomaticProxyFilter() async {
    return await _meshManagerApi.supportsAutomaticProxyFilter();
  }

  /// Aggregated capability snapshot for receive metadata and Proxy Filter support.
  Future<MeshCapabilities> getCapabilities() async {
    return await _meshManagerApi.getCapabilities();
  }

  /// Sets explicit Proxy Filter type on the connected Proxy Node.
  Future<bool> setProxyFilterType(MeshProxyFilterType type) async {
    return await _meshManagerApi.setProxyFilterType(type);
  }

  /// Adds addresses to the explicit Proxy Filter list on the connected Proxy Node.
  Future<bool> addProxyFilterAddresses(List<int> addresses) async {
    return await _meshManagerApi.addProxyFilterAddresses(addresses);
  }

  /// Removes addresses from the explicit Proxy Filter list on the connected Proxy Node.
  Future<bool> removeProxyFilterAddresses(List<int> addresses) async {
    return await _meshManagerApi.removeProxyFilterAddresses(addresses);
  }

  /// Clear persisted secure mesh state used for stable Access sending.
  Future<void> clearSecureStorage() async {
    return await _meshManagerApi.clearSecureStorage();
  }

  /// **Deprecated (Phase 1.3).** Prefer Kotlin Mesh **1.0+** public `networkEvents`
  /// receive path; enabling this opts into fragile reflection on Android.
  @Deprecated(
    'Phase 1.3: Prefer default Android public RX path; reflection may break across Nordic releases.',
  )
  Future<void> setExperimentalRxMetadataEnabled(bool enabled) async {
    return await _meshManagerApi.setExperimentalRxMetadataEnabled(enabled);
  }

  /// Returns provisioned nodes with best-effort composition data from native DB.
  Future<List<node_models.ProvisionedNode>> getNodes() async {
    return await _meshManagerApi.getNodes();
  }

  /// Removes node identity [nodeId] from local mesh representation when supported.
  Future<void> removeNode(String nodeId) async {
    return await _meshManagerApi.removeNode(nodeId);
  }

  /// Creates a SIG group address entry with display [name].
  Future<group_models.MeshGroup> createGroup(String name) async {
    return await _meshManagerApi.createGroup(name);
  }

  /// Lists known mesh groups (fixed groups + virtual label groups).
  Future<List<group_models.MeshGroup>> getGroups() async {
    return await _meshManagerApi.getGroups();
  }

  /// Associates [nodeId] membership with SIG group [groupId].
  Future<void> addNodeToGroup(String nodeId, String groupId) async {
    return await _meshManagerApi.addNodeToGroup(nodeId, groupId);
  }

  // M3: virtual label groups

  /// Creates a virtual-label group from a 16-byte [labelUuid].
  Future<group_models.MeshGroup> createVirtualGroup(
    String name,
    List<int> labelUuid,
  ) async {
    return await _meshManagerApi.createVirtualGroup(name, labelUuid);
  }

  /// Deletes a group definition locally/natively when supported.
  Future<bool> removeGroup(String groupId) async {
    return await _meshManagerApi.removeGroup(groupId);
  }

  /// Adds virtual-address subscription derived from [labelUuid].
  Future<bool> addSubscriptionVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
  ) async {
    return await _meshManagerApi.addSubscriptionVirtual(
      elementAddress,
      modelId,
      labelUuid,
    );
  }

  /// Removes virtual-address subscription for [labelUuid].
  Future<bool> removeSubscriptionVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
  ) async {
    return await _meshManagerApi.removeSubscriptionVirtual(
      elementAddress,
      modelId,
      labelUuid,
    );
  }

  /// Sets publication toward a virtual destination computed from [labelUuid].
  Future<bool> setPublicationVirtual(
    int elementAddress,
    int modelId,
    List<int> labelUuid,
    int appKeyIndex, {
    int? ttl,
  }) async {
    return await _meshManagerApi.setPublicationVirtual(
      elementAddress,
      modelId,
      labelUuid,
      appKeyIndex,
      ttl: ttl,
    );
  }

  // Configuration (P1 - minimal)

  /// Config Model App Bind — binds AppKey index on element/model.
  Future<bool> bindAppKey(
    int elementAddress,
    int modelId,
    int appKeyIndex,
  ) async {
    return await _meshManagerApi.bindAppKey(
      elementAddress,
      modelId,
      appKeyIndex,
    );
  }

  /// Config Model App Unbind.
  Future<bool> unbindAppKey(
    int elementAddress,
    int modelId,
    int appKeyIndex,
  ) async {
    return await _meshManagerApi.unbindAppKey(
      elementAddress,
      modelId,
      appKeyIndex,
    );
  }

  /// Adds group/virtual unicast subscription address [address].
  Future<bool> addSubscription(
    int elementAddress,
    int modelId,
    int address,
  ) async {
    return await _meshManagerApi.addSubscription(
      elementAddress,
      modelId,
      address,
    );
  }

  /// Removes subscription to [address].
  Future<bool> removeSubscription(
    int elementAddress,
    int modelId,
    int address,
  ) async {
    return await _meshManagerApi.removeSubscription(
      elementAddress,
      modelId,
      address,
    );
  }

  /// Sets model publication state toward [publishAddress].
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

  // M2: Configuration foundation

  /// Reads Composition Data page from remote node [destination].
  Future<bool> fetchCompositionData(int destination, {int page = 0}) async {
    return await _meshManagerApi.fetchCompositionData(destination, page: page);
  }

  /// Adds NetKey material at local provisioner DB ([keyHex] = 32 hex chars typical).
  Future<bool> addNetworkKey(int netKeyIndex, String keyHex) async {
    return await _meshManagerApi.addNetworkKey(netKeyIndex, keyHex);
  }

  /// Adds AppKey bound to current NetKey ([keyHex] material format per native).
  Future<bool> addAppKey(int appKeyIndex, String keyHex) async {
    return await _meshManagerApi.addAppKey(appKeyIndex, keyHex);
  }

  /// Lists NetKeys stored locally / reported by stack.
  Future<List<net_models.NetworkKey>> getNetworkKeys() async {
    return await _meshManagerApi.getNetworkKeys();
  }

  /// Lists AppKeys stored locally / reported by stack.
  Future<List<net_models.AppKey>> getAppKeys() async {
    return await _meshManagerApi.getAppKeys();
  }

  // M2 acceptance: node config + reset + bundle export/import

  /// Sets Default TTL on remote node.
  Future<bool> setNodeDefaultTtl(int destination, int ttl) async {
    return await _meshManagerApi.setNodeDefaultTtl(destination, ttl);
  }

  /// Enables/disables Relay + retransmit parameters on remote node.
  Future<bool> setNodeRelay(
    int destination,
    bool enabled,
    int retransmitCount,
    int retransmitIntervalMs,
  ) async {
    return await _meshManagerApi.setNodeRelay(
      destination,
      enabled,
      retransmitCount,
      retransmitIntervalMs,
    );
  }

  /// Sets GATT Proxy feature on remote node.
  Future<bool> setNodeGattProxy(int destination, bool enabled) async {
    return await _meshManagerApi.setNodeGattProxy(destination, enabled);
  }

  /// Sets Friend feature on remote node.
  Future<bool> setNodeFriend(int destination, bool enabled) async {
    return await _meshManagerApi.setNodeFriend(destination, enabled);
  }

  /// Sets Secure Network Beacon on remote node.
  Future<bool> setNodeBeacon(int destination, bool enabled) async {
    return await _meshManagerApi.setNodeBeacon(destination, enabled);
  }

  /// Sets Network Transmit Count / Interval on remote node.
  Future<bool> setNodeNetworkTransmit(
    int destination,
    int count,
    int intervalMs,
  ) async {
    return await _meshManagerApi.setNodeNetworkTransmit(
      destination,
      count,
      intervalMs,
    );
  }

  /// Sends Config Node Reset to factory-reset remote node from mesh.
  Future<bool> nodeReset(int destination) async {
    return await _meshManagerApi.nodeReset(destination);
  }

  /// Exports mesh DB + secure bundle JSON suitable for backup.
  Future<bool> exportConfigurationBundle(String path) async {
    return await _meshManagerApi.exportConfigurationBundle(path);
  }

  /// Imports bundle previously written by [exportConfigurationBundle].
  Future<bool> importConfigurationBundle(String path) async {
    return await _meshManagerApi.importConfigurationBundle(path);
  }

  /// M2: Config Net Key Delete (remote node).
  Future<bool> removeNetworkKeyRemote(int destination, int netKeyIndex) async {
    return await _meshManagerApi.removeNetworkKeyRemote(
      destination,
      netKeyIndex,
    );
  }

  /// M2: Config App Key Delete (remote node).
  Future<bool> removeAppKeyRemote(
    int destination,
    int appKeyIndex,
    int boundNetKeyIndex,
  ) async {
    return await _meshManagerApi.removeAppKeyRemote(
      destination,
      appKeyIndex,
      boundNetKeyIndex,
    );
  }

  /// M2: Key Refresh phase (0/1/2), or `-1` on failure.
  Future<int> getKeyRefreshPhase(int destination, int netKeyIndex) async {
    return await _meshManagerApi.getKeyRefreshPhase(destination, netKeyIndex);
  }

  /// M2: Key Refresh transition — `2` = use new keys, `3` = revoke old keys.
  Future<bool> setKeyRefreshPhaseTransition(
    int destination,
    int netKeyIndex,
    int transition,
  ) async {
    return await _meshManagerApi.setKeyRefreshPhaseTransition(
      destination,
      netKeyIndex,
      transition,
    );
  }

  /// M2: Clear local mesh DB + secure state; then [createNetwork] or [import].
  Future<bool> resetLocalMeshState() async {
    return await _meshManagerApi.resetLocalMeshState();
  }

  // Proxy (P1 real-transport prerequisite)

  /// Opens GATT proxy session toward BLE device [deviceId] using mesh address [proxyUnicastAddress].
  Future<bool> connectProxy(String deviceId, int proxyUnicastAddress) async {
    return await _meshManagerApi.connectProxy(deviceId, proxyUnicastAddress);
  }

  /// Closes active proxy GATT connection if any.
  Future<bool> disconnectProxy() async {
    return await _meshManagerApi.disconnectProxy();
  }

  /// Whether proxy bearer reports connected.
  Future<bool> isProxyConnected() async {
    return await _meshManagerApi.isProxyConnected();
  }

  /// Opens PB-GATT bearer toward advertiser [deviceId] prior to [provisionDevice].
  Future<bool> connectProvisioning(String deviceId) async {
    return await _meshManagerApi.connectProvisioning(deviceId);
  }

  /// Disconnects provisioning bearer for device [deviceId] / global session per native rules.
  Future<bool> disconnectProvisioning() async {
    return await _meshManagerApi.disconnectProvisioning();
  }

  /// Whether provisioning GATT link is active.
  Future<bool> isProvisioningConnected() async {
    return await _meshManagerApi.isProvisioningConnected();
  }

  /// Phase **3.1**: unified bearer view from **`isProxyConnected`** /
  /// **`isProvisioningConnected`** plus local in-flight connect state tracked by
  /// this Dart facade.
  ///
  /// Native Nordic SDK probes report connected / disconnected; while a connect
  /// call is pending, this snapshot may surface [MeshBearerPhase.proxyConnecting]
  /// or [MeshBearerPhase.provisioningConnecting].
  Future<MeshBearerSnapshot> getMeshBearerSnapshot() async {
    return await _meshManagerApi.getMeshBearerSnapshot();
  }
}

/// Parameters controlling provisioning authentication / privacy flags for PB-GATT.
class ProvisioningParameters {
  /// Friendly label displayed to operators (must be non-empty).
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

  /// Enables provisioning privacy mode when stack supports it.
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

  /// Provisioning without out-of-band authentication material.
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

  /// Static OOB using raw secret bytes encoded as even-length [hex] string.
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
        throw ArgumentError.value(
          oobData,
          'oobData',
          'Must be null/empty when no OOB is used.',
        );
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
        throw ArgumentError.value(
          v,
          'oobData',
          'Static OOB must be even-length hex (no separators).',
        );
      }
      final bytesLen = hex.length ~/ 2;
      if (bytesLen < 1 || bytesLen > 32) {
        throw ArgumentError.value(
          v,
          'oobData',
          'Static OOB must be 1..32 bytes.',
        );
      }
      return;
    }
    // output/input OOB: data may be null initially; UI flow can fill it later.
  }
}
