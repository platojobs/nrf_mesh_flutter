import '../../models/mesh_message.dart';

/// Bluetooth Mesh Scenes model opcodes (SIG).
///
/// Source: Bluetooth Mesh Model spec (Scenes) and cross-checked against
/// python-bluetooth-mesh `SceneOpcode`.
class SceneOpcode {
  static const int sceneGet = 0x8241;
  static const int sceneRecall = 0x8242;
  static const int sceneRecallUnacknowledged = 0x8243;
  static const int sceneStatus = 0x005E;
  static const int sceneRegisterGet = 0x8244;
  static const int sceneRegisterStatus = 0x8245;
  static const int sceneStore = 0x8246;
  static const int sceneStoreUnacknowledged = 0x8247;
  static const int sceneDelete = 0x829E;
  static const int sceneDeleteUnacknowledged = 0x829F;
}

/// Scene Store (acknowledged). Responds with Scene Register Status.
class SceneStore extends MeshMessage {
  final int sceneNumber;

  SceneStore({
    required this.sceneNumber,
    super.address,
    super.appKeyIndex,
    super.virtualLabel,
  }) : super(
          opcode: '0x${SceneOpcode.sceneStore.toRadixString(16)}',
          parameters: _u16le(sceneNumber),
        ) {
    _validateSceneNumber(sceneNumber);
  }
}

/// Scene Recall (acknowledged). Responds with Scene Status.
class SceneRecall extends MeshMessage {
  final int sceneNumber;
  final int tid;
  final int? transitionTime;
  final int? delay;

  SceneRecall({
    required this.sceneNumber,
    int? tid,
    this.transitionTime,
    this.delay,
    super.address,
    super.appKeyIndex,
    super.virtualLabel,
  })  : tid = (tid ?? DateTime.now().millisecondsSinceEpoch & 0xFF),
        super(
          opcode: '0x${SceneOpcode.sceneRecall.toRadixString(16)}',
          parameters: _build(sceneNumber, tid ?? DateTime.now().millisecondsSinceEpoch & 0xFF, transitionTime, delay),
        ) {
    _validateSceneNumber(sceneNumber);
    _validateOptionalTransition(transitionTime, delay);
  }

  static List<int> _build(int sceneNumber, int tid, int? transitionTime, int? delay) {
    final out = <int>[];
    out.addAll(_u16le(sceneNumber));
    out.add(tid & 0xFF);
    if (transitionTime != null && delay != null) {
      out.add(transitionTime & 0xFF);
      out.add(delay & 0xFF);
    }
    return out;
  }
}

/// Scene Delete (acknowledged). Responds with Scene Register Status.
class SceneDelete extends MeshMessage {
  final int sceneNumber;

  SceneDelete({
    required this.sceneNumber,
    super.address,
    super.appKeyIndex,
    super.virtualLabel,
  }) : super(
          opcode: '0x${SceneOpcode.sceneDelete.toRadixString(16)}',
          parameters: _u16le(sceneNumber),
        ) {
    // Note: spec allows deleting scene 0? In practice, 0x0000 is prohibited for store/recall,
    // and delete typically uses a valid scene number. We'll keep the same validation.
    _validateSceneNumber(sceneNumber);
  }
}

/// Scene Get (acknowledged). Responds with Scene Status.
class SceneGet extends MeshMessage {
  SceneGet({
    super.address,
    super.appKeyIndex,
    super.virtualLabel,
  }) : super(
          opcode: '0x${SceneOpcode.sceneGet.toRadixString(16)}',
          parameters: const <int>[],
        );
}

/// Scene Register Get (acknowledged). Responds with Scene Register Status.
class SceneRegisterGet extends MeshMessage {
  SceneRegisterGet({
    super.address,
    super.appKeyIndex,
    super.virtualLabel,
  }) : super(
          opcode: '0x${SceneOpcode.sceneRegisterGet.toRadixString(16)}',
          parameters: const <int>[],
        );
}

void _validateSceneNumber(int sceneNumber) {
  if (sceneNumber <= 0 || sceneNumber > 0xFFFF) {
    throw ArgumentError.value(sceneNumber, 'sceneNumber', 'Must be 1..65535 (0x0000 is prohibited).');
  }
}

void _validateOptionalTransition(int? transitionTime, int? delay) {
  if ((transitionTime == null) != (delay == null)) {
    throw ArgumentError('transitionTime and delay must be provided together, or both null.');
  }
}

List<int> _u16le(int v) => <int>[v & 0xFF, (v >> 8) & 0xFF];

