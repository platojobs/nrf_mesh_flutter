import 'provisioned_node.dart';
import 'mesh_group.dart';

class MeshNetwork {
  final String networkId;
  final String name;
  final List<NetworkKey> networkKeys;
  final List<AppKey> appKeys;
  final List<ProvisionedNode> nodes;
  final List<MeshGroup> groups;
  final Provisioner provisioner;

  MeshNetwork({
    required this.networkId,
    required this.name,
    required this.networkKeys,
    required this.appKeys,
    required this.nodes,
    required this.groups,
    required this.provisioner,
  });

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

class NetworkKey {
  final String keyId;
  final String key;
  final int index;
  final bool enabled;

  NetworkKey({
    required this.keyId,
    required this.key,
    required this.index,
    required this.enabled,
  });

  factory NetworkKey.fromMap(Map<String, dynamic> map) {
    return NetworkKey(
      keyId: map['keyId'],
      key: map['key'],
      index: map['index'],
      enabled: map['enabled'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'keyId': keyId, 'key': key, 'index': index, 'enabled': enabled};
  }
}

class AppKey {
  final String keyId;
  final String key;
  final int index;
  final bool enabled;

  AppKey({
    required this.keyId,
    required this.key,
    required this.index,
    required this.enabled,
  });

  factory AppKey.fromMap(Map<String, dynamic> map) {
    return AppKey(
      keyId: map['keyId'],
      key: map['key'],
      index: map['index'],
      enabled: map['enabled'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'keyId': keyId, 'key': key, 'index': index, 'enabled': enabled};
  }
}

class Provisioner {
  final String name;
  final String provisionerId;
  final List<int> addressRange;

  Provisioner({
    required this.name,
    required this.provisionerId,
    required this.addressRange,
  });

  factory Provisioner.fromMap(Map<String, dynamic> map) {
    return Provisioner(
      name: map['name'],
      provisionerId: map['provisionerId'],
      addressRange: List<int>.from(map['addressRange']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'provisionerId': provisionerId,
      'addressRange': addressRange,
    };
  }
}
