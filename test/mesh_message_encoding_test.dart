import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  test('GenericOnOffSet uses spec opcode and parameters', () {
    final msg = GenericOnOffSet(state: true, tid: 0x7A);
    expect(msg.opcode, '0x8202');
    expect(msg.parameters, <int>[1, 0x7A]);
  });

  test('GenericOnOffSet includes optional transition+delay bytes', () {
    final msg = GenericOnOffSet(
      state: false,
      tid: 1,
      transitionTime: 0xAA,
      delay: 0x05,
    );
    expect(msg.opcode, '0x8202');
    expect(msg.parameters, <int>[0, 1, 0xAA, 0x05]);
  });

  test('GenericLevelSet uses spec opcode and parameters', () {
    final msg = GenericLevelSet(level: 0x1234, tid: 0x10);
    expect(msg.opcode, '0x8206');
    expect(msg.parameters, <int>[0x34, 0x12, 0x10]);
  });

  test('GenericLevelSet includes optional transition+delay bytes', () {
    final msg = GenericLevelSet(
      level: -1,
      tid: 2,
      transitionTime: 0x01,
      delay: 0xFF,
    );
    // -1 as Int16 => 0xFFFF little endian
    expect(msg.opcode, '0x8206');
    expect(msg.parameters, <int>[0xFF, 0xFF, 2, 0x01, 0xFF]);
  });
}

