import 'provisioned_node.dart';
import 'mesh_group.dart';

/// Snapshot of a mesh network as exposed to Dart (topology, keys, groups).
///
/// Populated by native bridges after [PlatoJobsNrfMeshManager.loadNetwork], provisioning, etc.
class MeshNetwork {
  /// Implementation-defined stable network id.
  final String networkId;

  /// User-visible network name.
  final String name;

  /// Network (NetKey) entries known to the provisioner.
  final List<NetworkKey> networkKeys;

  /// Application keys bound to this network.
  final List<AppKey> appKeys;

  /// Provisioned nodes and their composition snapshots (best-effort).
  final List<ProvisionedNode> nodes;

  /// Mesh groups (including virtual label groups when supported).
  final List<MeshGroup> groups;

  /// Local provisioner identity and unicast allocation range metadata.
  final Provisioner provisioner;

  /// Creates a mesh network snapshot with the given topology data.
  MeshNetwork({
    required this.networkId,
    required this.name,
    required this.networkKeys,
    required this.appKeys,
    required this.nodes,
    required this.groups,
    required this.provisioner,
  });

  /// Parses a [MeshNetwork] from JSON-style maps (interop / caching).
  factory MeshNetwork.fromMap(Map<String, dynamic> map) {
    return MeshNetwork(
      networkId: map['networkId'],
      name: map['name'],
      networkKeys: (map['networkKeys'] as List)
          .map((e) => NetworkKey.fromMap(e))
          .toList(),
      appKeys: (map['appKeys'] as List).map((e) => AppKey.fromMap(e)).toList(),
      nodes: (map['nodes'] as List)
          .map((e) => ProvisionedNode.fromMap(e))
          .toList(),
      groups: (map['groups'] as List).map((e) => MeshGroup.fromMap(e)).toList(),
      provisioner: Provisioner.fromMap(map['provisioner']),
    );
  }

  /// Converts this snapshot to a JSON-style map.
  Map<String, dynamic> toMap() {
    return {
      'networkId': networkId,
      'name': name,
      'networkKeys': networkKeys.map((e) => e.toMap()).toList(),
      'appKeys': appKeys.map((e) => e.toMap()).toList(),
      'nodes': nodes.map((e) => e.toMap()).toList(),
      'groups': groups.map((e) => e.toMap()).toList(),
      'provisioner': provisioner.toMap(),
    };
  }
}

/// A Network Key (NetKey) entry at the provisioner.
class NetworkKey {
  /// Logical key identifier (implementation-defined string).
  final String keyId;

  /// Key material as hex or opaque string from native (do not log in production).
  final String key;

  /// NetKey index (0-based mesh key index).
  final int index;

  /// Whether this key is active / selectable in the local DB snapshot.
  final bool enabled;

  /// Creates a NetKey row for serialization layers.
  NetworkKey({
    required this.keyId,
    required this.key,
    required this.index,
    required this.enabled,
  });

  /// Parses from JSON-style map fields from native or cached bundles.
  factory NetworkKey.fromMap(Map<String, dynamic> map) {
    return NetworkKey(
      keyId: map['keyId'],
      key: map['key'],
      index: map['index'],
      enabled: map['enabled'],
    );
  }

  /// Converts to a JSON-style map.
  Map<String, dynamic> toMap() {
    return {'keyId': keyId, 'key': key, 'index': index, 'enabled': enabled};
  }
}

/// An Application Key (AppKey) entry used for Access-layer encryption.
class AppKey {
  /// Logical application key identifier (implementation-defined).
  final String keyId;

  /// Key material as hex or opaque string from native (secret — avoid logging).
  final String key;

  /// AppKey index (12-bit space in mesh; exposed as int).
  final int index;

  /// Whether this AppKey is enabled in the current snapshot.
  final bool enabled;

  /// Creates an AppKey row for Dart models.
  AppKey({
    required this.keyId,
    required this.key,
    required this.index,
    required this.enabled,
  });

  /// Parses AppKey fields from a JSON-style map.
  factory AppKey.fromMap(Map<String, dynamic> map) {
    return AppKey(
      keyId: map['keyId'],
      key: map['key'],
      index: map['index'],
      enabled: map['enabled'],
    );
  }

  /// Converts this AppKey to a JSON-style map.
  Map<String, dynamic> toMap() {
    return {'keyId': keyId, 'key': key, 'index': index, 'enabled': enabled};
  }
}

/// Describes the local provisioner instance managing this network.
class Provisioner {
  /// Display name of the provisioner.
  final String name;

  /// Stable provisioner id string from native.
  final String provisionerId;

  /// Inclusive unicast address range reserved for assigning new nodes (two ints).
  final List<int> addressRange;

  /// Creates provisioner metadata for [MeshNetwork].
  Provisioner({
    required this.name,
    required this.provisionerId,
    required this.addressRange,
  });

  /// Parses provisioner data from a JSON-style map.
  factory Provisioner.fromMap(Map<String, dynamic> map) {
    return Provisioner(
      name: map['name'],
      provisionerId: map['provisionerId'],
      addressRange: List<int>.from(map['addressRange']),
    );
  }

  /// Converts provisioner metadata to a JSON-style map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'provisionerId': provisionerId,
      'addressRange': addressRange,
    };
  }
}
