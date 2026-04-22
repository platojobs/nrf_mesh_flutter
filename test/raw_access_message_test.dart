import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  test('RawAccessMessage validates byte range', () {
    expect(
      () => RawAccessMessage(
        opCode: 0x8202,
        parameters: const <int>[0, -1],
        address: 0xC000,
        appKeyIndex: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('RawAccessMessage validates address range', () {
    expect(
      () => RawAccessMessage(
        opCode: 0x8202,
        parameters: const <int>[0, 1],
        address: 0x1_0000,
        appKeyIndex: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('RawAccessMessage validates appKeyIndex range', () {
    expect(
      () => RawAccessMessage(
        opCode: 0x8202,
        parameters: const <int>[0, 1],
        address: 0xC000,
        appKeyIndex: 4096,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('RawAccessMessage formats opcode as hex string', () {
    final msg = RawAccessMessage(
      opCode: 0x8202,
      parameters: const <int>[1, 2, 3],
      address: 0xC000,
      appKeyIndex: 0,
    );
    expect(msg.opcode, '0x8202');
    expect(msg.parameters, const <int>[1, 2, 3]);
  });
}

