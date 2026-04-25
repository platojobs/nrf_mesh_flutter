import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/platojobs_nrf_mesh.dart';

void main() {
  group('Scenes message encoding', () {
    test('SceneStore encodes scene number LE', () {
      final m = SceneStore(sceneNumber: 0x1234, address: 1, appKeyIndex: 0);
      expect(m.opcode, '0x8246');
      expect(m.parameters, [0x34, 0x12]);
    });

    test('SceneRecall minimal encodes scene number + tid', () {
      final m = SceneRecall(sceneNumber: 0x0001, tid: 0xAA, address: 1, appKeyIndex: 0);
      expect(m.opcode, '0x8242');
      expect(m.parameters, [0x01, 0x00, 0xAA]);
    });

    test('SceneRecall optional encodes transition + delay', () {
      final m = SceneRecall(
        sceneNumber: 0x0002,
        tid: 0x01,
        transitionTime: 0x10,
        delay: 0x20,
        address: 1,
        appKeyIndex: 0,
      );
      expect(m.parameters, [0x02, 0x00, 0x01, 0x10, 0x20]);
    });
  });

  group('Scenes status decoding', () {
    test('SceneStatus minimal decodes', () {
      final m = MeshMessage.fromIncoming(opcode: 0x5E, parameters: [0x00, 0x34, 0x12]);
      expect(m, isA<SceneStatusMessage>());
      final s = m as SceneStatusMessage;
      expect(s.currentScene, 0x1234);
      expect(s.targetScene, isNull);
      expect(s.remainingTime, isNull);
    });

    test('SceneStatus optional decodes target + remain', () {
      final m = MeshMessage.fromIncoming(
        opcode: 0x5E,
        parameters: [0x00, 0x01, 0x00, 0x02, 0x00, 0x7F],
      );
      final s = m as SceneStatusMessage;
      expect(s.currentScene, 1);
      expect(s.targetScene, 2);
      expect(s.remainingTime, 0x7F);
    });

    test('SceneRegisterStatus decodes list', () {
      final m = MeshMessage.fromIncoming(
        opcode: 0x8245,
        parameters: [0x00, 0x01, 0x00, 0x02, 0x00, 0x34, 0x12],
      );
      expect(m, isA<SceneRegisterStatusMessage>());
      final r = m as SceneRegisterStatusMessage;
      expect(r.currentScene, 1);
      expect(r.scenes, [2, 0x1234]);
    });
  });
}

