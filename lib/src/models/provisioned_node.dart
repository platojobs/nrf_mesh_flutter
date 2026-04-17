class ProvisionedNode {
  final String uuid;
  final String unicastAddress;
  final List<Element> elements;
  final List<NetworkKey> networkKeys;
  final List<AppKey> appKeys;
  final NodeFeatures features;

  ProvisionedNode({
    required this.uuid,
    required this.unicastAddress,
    required this.elements,
    required this.networkKeys,
    required this.appKeys,
    required this.features,
  });

  factory ProvisionedNode.fromMap(Map<String, dynamic> map) {
    return ProvisionedNode(
      uuid: map['uuid'],
      unicastAddress: map['unicastAddress'],
      elements: (map['elements'] as List).map((e) => Element.fromMap(e)).toList(),
      networkKeys: (map['networkKeys'] as List).map((e) => NetworkKey.fromMap(e)).toList(),
      appKeys: (map['appKeys'] as List).map((e) => AppKey.fromMap(e)).toList(),
      features: NodeFeatures.fromMap(map['features']),
    );
  }

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

class Element {
  final String address;
  final List<Model> models;

  Element({
    required this.address,
    required this.models,
  });

  factory Element.fromMap(Map<String, dynamic> map) {
    return Element(
      address: map['address'],
      models: (map['models'] as List).map((e) => Model.fromMap(e)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'models': models.map((e) => e.toMap()).toList(),
    };
  }
}

class Model {
  final String modelId;
  final String modelName;
  final bool isServer;
  final bool isClient;

  Model({
    required this.modelId,
    required this.modelName,
    required this.isServer,
    required this.isClient,
  });

  factory Model.fromMap(Map<String, dynamic> map) {
    return Model(
      modelId: map['modelId'],
      modelName: map['modelName'],
      isServer: map['isServer'],
      isClient: map['isClient'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'modelName': modelName,
      'isServer': isServer,
      'isClient': isClient,
    };
  }
}

class NodeFeatures {
  final bool relay;
  final bool proxy;
  final bool friend;
  final bool lowPower;

  NodeFeatures({
    required this.relay,
    required this.proxy,
    required this.friend,
    required this.lowPower,
  });

  factory NodeFeatures.fromMap(Map<String, dynamic> map) {
    return NodeFeatures(
      relay: map['relay'],
      proxy: map['proxy'],
      friend: map['friend'],
      lowPower: map['lowPower'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'relay': relay,
      'proxy': proxy,
      'friend': friend,
      'lowPower': lowPower,
    };
  }
}

// Reuse NetworkKey and AppKey from mesh_network.dart
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
    return {
      'keyId': keyId,
      'key': key,
      'index': index,
      'enabled': enabled,
    };
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
    return {
      'keyId': keyId,
      'key': key,
      'index': index,
      'enabled': enabled,
    };
  }
}