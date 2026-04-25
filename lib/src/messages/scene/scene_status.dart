import '../../models/mesh_message.dart';
import 'scene_messages.dart';

/// Scene Status codes per Bluetooth Mesh Model spec.
enum SceneStatusCode {
  success(0x00),
  sceneRegisterFull(0x01),
  sceneNotFound(0x02);

  final int value;
  const SceneStatusCode(this.value);

  static SceneStatusCode? fromByte(int b) {
    for (final v in SceneStatusCode.values) {
      if (v.value == (b & 0xFF)) return v;
    }
    return null;
  }
}

/// Decoded Scene Status (incoming).
class SceneStatusMessage extends MeshMessage {
  final SceneStatusCode statusCode;
  final int currentScene;
  final int? targetScene;
  final int? remainingTime; // raw TransitionTime byte

  SceneStatusMessage({
    required this.statusCode,
    required this.currentScene,
    required this.targetScene,
    required this.remainingTime,
    required super.parameters,
    super.address,
    super.appKeyIndex,
    super.virtualLabel,
  }) : super(opcode: '0x${SceneOpcode.sceneStatus.toRadixString(16)}');

  static SceneStatusMessage? tryDecode({
    required int opcode,
    required List<int> parameters,
    int? address,
    int? appKeyIndex,
  }) {
    if (opcode != SceneOpcode.sceneStatus) return null;
    if (parameters.length != 3 && parameters.length != 6) return null;

    final code = SceneStatusCode.fromByte(parameters[0]) ?? SceneStatusCode.success;
    final current = _u16le(parameters, 1);
    if (parameters.length == 3) {
      return SceneStatusMessage(
        statusCode: code,
        currentScene: current,
        targetScene: null,
        remainingTime: null,
        parameters: parameters,
        address: address,
        appKeyIndex: appKeyIndex,
      );
    }
    final target = _u16le(parameters, 3);
    final remain = parameters[5] & 0xFF;
    return SceneStatusMessage(
      statusCode: code,
      currentScene: current,
      targetScene: target,
      remainingTime: remain,
      parameters: parameters,
      address: address,
      appKeyIndex: appKeyIndex,
    );
  }
}

/// Decoded Scene Register Status (incoming).
class SceneRegisterStatusMessage extends MeshMessage {
  final SceneStatusCode statusCode;
  final int currentScene;
  final List<int> scenes;

  SceneRegisterStatusMessage({
    required this.statusCode,
    required this.currentScene,
    required this.scenes,
    required super.parameters,
    super.address,
    super.appKeyIndex,
    super.virtualLabel,
  }) : super(opcode: '0x${SceneOpcode.sceneRegisterStatus.toRadixString(16)}');

  static SceneRegisterStatusMessage? tryDecode({
    required int opcode,
    required List<int> parameters,
    int? address,
    int? appKeyIndex,
  }) {
    if (opcode != SceneOpcode.sceneRegisterStatus) return null;
    if (parameters.length < 3) return null;
    if (((parameters.length - 3) % 2) != 0) return null;

    final code = SceneStatusCode.fromByte(parameters[0]) ?? SceneStatusCode.success;
    final current = _u16le(parameters, 1);
    final scenes = <int>[];
    for (var i = 3; i + 1 < parameters.length; i += 2) {
      scenes.add(_u16le(parameters, i));
    }
    return SceneRegisterStatusMessage(
      statusCode: code,
      currentScene: current,
      scenes: scenes,
      parameters: parameters,
      address: address,
      appKeyIndex: appKeyIndex,
    );
  }
}

int _u16le(List<int> b, int offset) => (b[offset] & 0xFF) | ((b[offset + 1] & 0xFF) << 8);

