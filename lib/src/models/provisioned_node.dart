/// Provisioned mesh node including UUID, primary address, and elements/models.
class ProvisionedNode {
  /// Device UUID string assigned during provisioning.
  final String uuid;

  /// Primary element unicast as hex string (e.g. `0x0007`).
  final String unicastAddress;

  /// Elements declared in the last composition snapshot known to native.
  final List<Element> elements;

  /// Network keys associated with this node in snapshot form.
  final List<NetworkKey> networkKeys;

  /// Application keys associated with this node in snapshot form.
  final List<AppKey> appKeys;

  /// Feature bits relay/proxy/friend/LPN when exposed by stack.
  final NodeFeatures features;

  /// Creates node model returned from [PlatoJobsNrfMeshManager.getNodes].
  ProvisionedNode({
    required this.uuid,
    required this.unicastAddress,
    required this.elements,
    required this.networkKeys,
    required this.appKeys,
    required this.features,
  });

  /// Parses JSON-style composition snapshots from native bridge or caches.
  factory ProvisionedNode.fromMap(Map<String, dynamic> map) {
    return ProvisionedNode(
      uuid: map['uuid'],
      unicastAddress: map['unicastAddress'],
      elements: (map['elements'] as List)
          .map((e) => Element.fromMap(e))
          .toList(),
      networkKeys: (map['networkKeys'] as List)
          .map((e) => NetworkKey.fromMap(e))
          .toList(),
      appKeys: (map['appKeys'] as List).map((e) => AppKey.fromMap(e)).toList(),
      features: NodeFeatures.fromMap(map['features']),
    );
  }

  /// Converts node snapshot to JSON-style maps.
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'unicastAddress': unicastAddress,
      'elements': elements.map((e) => e.toMap()).toList(),
      'networkKeys': networkKeys.map((e) => e.toMap()).toList(),
      'appKeys': appKeys.map((e) => e.toMap()).toList(),
      'features': features.toMap(),
    };
  }
}

/// Element within a provisioned node (address + models).
class Element {
  /// Element unicast address string (`0x`-prefixed hex typical).
  final String address;

  /// SIG/vendor models bound to this element.
  final List<Model> models;

  /// Constructs element row inside [ProvisionedNode.elements].
  Element({required this.address, required this.models});

  /// Parses element maps emitted by native serializers.
  factory Element.fromMap(Map<String, dynamic> map) {
    return Element(
      address: map['address'],
      models: (map['models'] as List).map((e) => Model.fromMap(e)).toList(),
    );
  }

  /// Converts element tree to JSON-style maps.
  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'models': models.map((e) => e.toMap()).toList(),
    };
  }
}

/// Mesh model instance discovered under an element.
class Model {
  /// SIG model identifier string (`0x1000`, vendor IDs, etc.).
  final String modelId;

  /// Human-readable model label when native supplies it.
  final String modelName;

  /// Whether model exposes server-side behaviour.
  final bool isServer;

  /// Whether model exposes client-side behaviour.
  final bool isClient;

  /// AppKey indexes currently bound to this model instance.
  final List<int> boundAppKeyIndexes;

  /// Subscription addresses (group/unicast/virtual ints) for this model.
  final List<int> subscriptions;

  /// Publication target metadata when configured.
  final Publication? publication;

  /// Creates model descriptor attached to [Element.models].
  Model({
    required this.modelId,
    required this.modelName,
    required this.isServer,
    required this.isClient,
    this.boundAppKeyIndexes = const <int>[],
    this.subscriptions = const <int>[],
    this.publication,
  });

  /// Parses model maps returned over platform channels.
  factory Model.fromMap(Map<String, dynamic> map) {
    return Model(
      modelId: map['modelId'],
      modelName: map['modelName'],
      isServer: map['isServer'],
      isClient: map['isClient'],
      boundAppKeyIndexes:
          (map['boundAppKeyIndexes'] as List?)?.cast<int>() ?? const <int>[],
      subscriptions:
          (map['subscriptions'] as List?)?.cast<int>() ?? const <int>[],
      publication: map['publication'] == null
          ? null
          : Publication.fromMap(
              (map['publication'] as Map).cast<String, dynamic>(),
            ),
    );
  }

  /// Converts model descriptor into JSON-style maps.
  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'modelName': modelName,
      'isServer': isServer,
      'isClient': isClient,
      'boundAppKeyIndexes': boundAppKeyIndexes,
      'subscriptions': subscriptions,
      'publication': publication?.toMap(),
    };
  }
}

/// Publication state for a mesh model (destination + AppKey + TTL).
class Publication {
  /// Publish destination address (group/unicast/virtual).
  final int address;

  /// AppKey index encrypting published traffic.
  final int appKeyIndex;

  /// Optional TTL override for publications.
  final int? ttl;

  /// Constructs publication metadata attached to [Model.publication].
  const Publication({
    required this.address,
    required this.appKeyIndex,
    this.ttl,
  });

  /// Parses publication maps from native serializers.
  factory Publication.fromMap(Map<String, dynamic> map) {
    return Publication(
      address: map['address'],
      appKeyIndex: map['appKeyIndex'],
      ttl: map['ttl'],
    );
  }

  /// Converts publication metadata to maps.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'address': address,
      'appKeyIndex': appKeyIndex,
      'ttl': ttl,
    };
  }
}

/// Relay / proxy / friend / low-power feature flags reported with nodes.
class NodeFeatures {
  /// Relay feature enabled.
  final bool relay;

  /// GATT proxy feature enabled.
  final bool proxy;

  /// Friend feature enabled.
  final bool friend;

  /// Low-power node behaviour indicated by remote device.
  final bool lowPower;

  /// Constructs node capability snapshot.
  NodeFeatures({
    required this.relay,
    required this.proxy,
    required this.friend,
    required this.lowPower,
  });

  /// Parses feature booleans from mesh stacks.
  factory NodeFeatures.fromMap(Map<String, dynamic> map) {
    return NodeFeatures(
      relay: map['relay'],
      proxy: map['proxy'],
      friend: map['friend'],
      lowPower: map['lowPower'],
    );
  }

  /// Converts flags into JSON-style maps.
  Map<String, dynamic> toMap() {
    return {
      'relay': relay,
      'proxy': proxy,
      'friend': friend,
      'lowPower': lowPower,
    };
  }
}

/// NetKey row mirrored alongside [ProvisionedNode] composition exports.
///
/// Shape matches [mesh_network.NetworkKey] for serializer compatibility.
class NetworkKey {
  /// Logical key identifier.
  final String keyId;

  /// Hex-encoded key material (secret).
  final String key;

  /// NetKey index.
  final int index;

  /// Whether key is enabled in this snapshot.
  final bool enabled;

  /// Creates mirrored NetKey structure for node exports.
  NetworkKey({
    required this.keyId,
    required this.key,
    required this.index,
    required this.enabled,
  });

  /// Parses node-attached NetKey rows.
  factory NetworkKey.fromMap(Map<String, dynamic> map) {
    return NetworkKey(
      keyId: map['keyId'],
      key: map['key'],
      index: map['index'],
      enabled: map['enabled'],
    );
  }

  /// Converts to JSON-style maps.
  Map<String, dynamic> toMap() {
    return {'keyId': keyId, 'key': key, 'index': index, 'enabled': enabled};
  }
}

/// AppKey row mirrored alongside [ProvisionedNode] composition exports.
///
/// Shape matches [mesh_network.AppKey] for serializer compatibility.
class AppKey {
  /// Logical application key identifier.
  final String keyId;

  /// Hex-encoded key material (secret).
  final String key;

  /// AppKey index.
  final int index;

  /// Whether AppKey is enabled in snapshot.
  final bool enabled;

  /// Creates mirrored AppKey structure for node exports.
  AppKey({
    required this.keyId,
    required this.key,
    required this.index,
    required this.enabled,
  });

  /// Parses node-attached AppKey rows.
  factory AppKey.fromMap(Map<String, dynamic> map) {
    return AppKey(
      keyId: map['keyId'],
      key: map['key'],
      index: map['index'],
      enabled: map['enabled'],
    );
  }

  /// Converts to JSON-style maps.
  Map<String, dynamic> toMap() {
    return {'keyId': keyId, 'key': key, 'index': index, 'enabled': enabled};
  }
}
