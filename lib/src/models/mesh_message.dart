import 'raw_access_message.dart';

abstract class MeshMessage {
  /// Opcode as hex string (e.g. `0x8201`).
  final String opcode;

  /// Raw access payload bytes (model parameters).
  final List<int> parameters;

  /// Destination (for outgoing) or source (for incoming), depending on platform.
  /// When unknown, may be null.
  final int? address;

  /// Application key index used for encrypting the access message.
  /// When unknown, may be null.
  final int? appKeyIndex;

  MeshMessage({
    required this.opcode,
    required this.parameters,
    this.address,
    this.appKeyIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'opcode': opcode,
      'parameters': parameters,
      'address': address,
      'appKeyIndex': appKeyIndex,
      'messageType': runtimeType.toString(),
    };
  }

  factory MeshMessage.fromMap(Map<String, dynamic> map) {
    final messageType = map['messageType'];
    switch (messageType) {
      case 'GenericOnOffSet':
        return GenericOnOffSet.fromMap(map);
      case 'GenericLevelSet':
        return GenericLevelSet.fromMap(map);
      case 'GenericOnOffStatus':
        return GenericOnOffStatus.fromMap(map);
      case 'GenericLevelStatus':
        return GenericLevelStatus.fromMap(map);
      case 'RawAccessMessage':
        return RawAccessMessage(
          opCode: map['opCode'],
          parameters: List<int>.from(map['parameters']),
          address: map['address'],
          appKeyIndex: map['appKeyIndex'],
        );
      default:
        return UnknownMessage(
          opcode: map['opcode'],
          parameters: List<int>.from(map['parameters']),
          address: map['address'],
          appKeyIndex: map['appKeyIndex'],
        );
    }
  }

  /// Decode an incoming access message into a typed [MeshMessage] when possible.
  ///
  /// Note: This decoder currently only covers a minimal P0 set of models.
  factory MeshMessage.fromIncoming({
    required int opcode,
    required List<int> parameters,
    int? address,
    int? appKeyIndex,
  }) {
    final opcodeHex = '0x${opcode.toRadixString(16)}';
    switch (opcode) {
      // Generic OnOff Status (0x8204)
      case 0x8204:
        if (parameters.isNotEmpty) {
          return GenericOnOffStatus(
            presentOnOff: parameters[0] != 0,
            targetOnOff: parameters.length >= 2 ? (parameters[1] != 0) : null,
            remainingTime:
                parameters.length >= 3 ? parameters[2] : null,
            address: address,
            appKeyIndex: appKeyIndex,
          );
        }
        break;

      // Generic Level Status (0x8208)
      case 0x8208:
        if (parameters.length >= 2) {
          final present = (parameters[0] & 0xFF) | ((parameters[1] & 0xFF) << 8);
          int toSigned16(int v) => v >= 0x8000 ? v - 0x10000 : v;
          final presentLevel = toSigned16(present);

          int? targetLevel;
          int? remainingTime;
          if (parameters.length >= 5) {
            final target =
                (parameters[2] & 0xFF) | ((parameters[3] & 0xFF) << 8);
            targetLevel = toSigned16(target);
            remainingTime = parameters[4];
          }

          return GenericLevelStatus(
            presentLevel: presentLevel,
            targetLevel: targetLevel,
            remainingTime: remainingTime,
            address: address,
            appKeyIndex: appKeyIndex,
          );
        }
        break;
    }

    return UnknownMessage(
      opcode: opcodeHex,
      parameters: parameters,
      address: address,
      appKeyIndex: appKeyIndex,
    );
  }
}

class GenericOnOffSet extends MeshMessage {
  final bool state;
  final int tid;
  final int? transitionTime;
  final int? delay;

  GenericOnOffSet({
    required this.state,
    int? tid,
    this.transitionTime,
    this.delay,
    super.address,
    super.appKeyIndex,
  })  : tid = (tid ?? DateTime.now().millisecondsSinceEpoch & 0xFF),
        super(
          // Generic OnOff Set (acknowledged): 0x8202
          opcode: '0x8202',
          parameters: _buildParameters(
            state,
            tid ?? DateTime.now().millisecondsSinceEpoch & 0xFF,
            transitionTime,
            delay,
          ),
        );

  factory GenericOnOffSet.fromMap(Map<String, dynamic> map) {
    return GenericOnOffSet(
      state: map['state'],
      tid: map['tid'],
      transitionTime: map['transitionTime'],
      delay: map['delay'],
      address: map['address'],
      appKeyIndex: map['appKeyIndex'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'state': state,
      'tid': tid,
      'transitionTime': transitionTime,
      'delay': delay,
    });
  }

  static List<int> _buildParameters(
    bool state,
    int tid,
    int? transitionTime,
    int? delay,
  ) {
    final params = <int>[];
    params.add(state ? 1 : 0);
    params.add(tid & 0xFF);
    if (transitionTime != null && delay != null) {
      // Mesh Model spec: optional Transition Time (1B) + Delay (1B, 5ms steps).
      params.add(transitionTime & 0xFF);
      params.add(delay & 0xFF);
    }
    return params;
  }
}

class GenericLevelSet extends MeshMessage {
  final int level;
  final int tid;
  final int? transitionTime;
  final int? delay;

  GenericLevelSet({
    required this.level,
    int? tid,
    this.transitionTime,
    this.delay,
    super.address,
    super.appKeyIndex,
  })  : tid = (tid ?? DateTime.now().millisecondsSinceEpoch & 0xFF),
        super(
          // Generic Level Set (acknowledged): 0x8206
          opcode: '0x8206',
          parameters: _buildParameters(
            level,
            tid ?? DateTime.now().millisecondsSinceEpoch & 0xFF,
            transitionTime,
            delay,
          ),
        );

  factory GenericLevelSet.fromMap(Map<String, dynamic> map) {
    return GenericLevelSet(
      level: map['level'],
      tid: map['tid'],
      transitionTime: map['transitionTime'],
      delay: map['delay'],
      address: map['address'],
      appKeyIndex: map['appKeyIndex'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'level': level,
      'tid': tid,
      'transitionTime': transitionTime,
      'delay': delay,
    });
  }

  static List<int> _buildParameters(
    int level,
    int tid,
    int? transitionTime,
    int? delay,
  ) {
    final params = <int>[];
    // Convert level to 2-byte little-endian
    params.add(level & 0xFF);
    params.add((level >> 8) & 0xFF);
    params.add(tid & 0xFF);
    if (transitionTime != null && delay != null) {
      params.add(transitionTime & 0xFF);
      params.add(delay & 0xFF);
    }
    return params;
  }
}

class GenericOnOffStatus extends MeshMessage {
  final bool presentOnOff;
  final bool? targetOnOff;
  final int? remainingTime;

  GenericOnOffStatus({
    required this.presentOnOff,
    this.targetOnOff,
    this.remainingTime,
    super.address,
    super.appKeyIndex,
  }) : super(
          opcode: '0x8204',
          parameters: const <int>[],
        );

  factory GenericOnOffStatus.fromMap(Map<String, dynamic> map) {
    return GenericOnOffStatus(
      presentOnOff: map['presentOnOff'],
      targetOnOff: map['targetOnOff'],
      remainingTime: map['remainingTime'],
      address: map['address'],
      appKeyIndex: map['appKeyIndex'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'presentOnOff': presentOnOff,
      'targetOnOff': targetOnOff,
      'remainingTime': remainingTime,
    });
  }
}

class GenericLevelStatus extends MeshMessage {
  final int presentLevel;
  final int? targetLevel;
  final int? remainingTime;

  GenericLevelStatus({
    required this.presentLevel,
    this.targetLevel,
    this.remainingTime,
    super.address,
    super.appKeyIndex,
  }) : super(
          opcode: '0x8208',
          parameters: const <int>[],
        );

  factory GenericLevelStatus.fromMap(Map<String, dynamic> map) {
    return GenericLevelStatus(
      presentLevel: map['presentLevel'],
      targetLevel: map['targetLevel'],
      remainingTime: map['remainingTime'],
      address: map['address'],
      appKeyIndex: map['appKeyIndex'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'presentLevel': presentLevel,
      'targetLevel': targetLevel,
      'remainingTime': remainingTime,
    });
  }
}

class UnknownMessage extends MeshMessage {
  UnknownMessage({
    required super.opcode,
    required super.parameters,
    super.address,
    super.appKeyIndex,
  });
}
