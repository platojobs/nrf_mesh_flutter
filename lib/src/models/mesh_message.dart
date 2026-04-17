abstract class MeshMessage {
  final String opcode;
  final List<int> parameters;

  MeshMessage({
    required this.opcode,
    required this.parameters,
  });

  Map<String, dynamic> toMap() {
    return {
      'opcode': opcode,
      'parameters': parameters,
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
      default:
        return UnknownMessage(
          opcode: map['opcode'],
          parameters: List<int>.from(map['parameters']),
        );
    }
  }
}

class GenericOnOffSet extends MeshMessage {
  final bool state;
  final int? transitionTime;
  final int? delay;

  GenericOnOffSet({
    required this.state,
    this.transitionTime,
    this.delay,
  }) : super(
          opcode: '0x8201',
          parameters: _buildParameters(state, transitionTime, delay),
        );

  factory GenericOnOffSet.fromMap(Map<String, dynamic> map) {
    return GenericOnOffSet(
      state: map['state'],
      transitionTime: map['transitionTime'],
      delay: map['delay'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'state': state,
      'transitionTime': transitionTime,
      'delay': delay,
    });
  }

  static List<int> _buildParameters(bool state, int? transitionTime, int? delay) {
    final params = <int>[];
    params.add(state ? 1 : 0);
    if (transitionTime != null && delay != null) {
      // Format transition time and delay according to Mesh spec
      params.add((transitionTime << 4) | (delay & 0x0F));
    }
    return params;
  }
}

class GenericLevelSet extends MeshMessage {
  final int level;
  final int? transitionTime;
  final int? delay;

  GenericLevelSet({
    required this.level,
    this.transitionTime,
    this.delay,
  }) : super(
          opcode: '0x8203',
          parameters: _buildParameters(level, transitionTime, delay),
        );

  factory GenericLevelSet.fromMap(Map<String, dynamic> map) {
    return GenericLevelSet(
      level: map['level'],
      transitionTime: map['transitionTime'],
      delay: map['delay'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'level': level,
      'transitionTime': transitionTime,
      'delay': delay,
    });
  }

  static List<int> _buildParameters(int level, int? transitionTime, int? delay) {
    final params = <int>[];
    // Convert level to 2-byte little-endian
    params.add(level & 0xFF);
    params.add((level >> 8) & 0xFF);
    if (transitionTime != null && delay != null) {
      params.add((transitionTime << 4) | (delay & 0x0F));
    }
    return params;
  }
}

class UnknownMessage extends MeshMessage {
  UnknownMessage({
    required super.opcode,
    required super.parameters,
  });
}