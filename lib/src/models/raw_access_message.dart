import 'mesh_message.dart';

/// A raw Access Layer message (opcode + parameters bytes) that will be sent as-is.
///
/// This is intentionally explicit to avoid relying on the implicit
/// `parameters['bytes']` convention used by the platform bridge.
class RawAccessMessage extends MeshMessage {
  final int opCode;

  RawAccessMessage({
    required this.opCode,
    required List<int> parameters,
    required int address,
    required int appKeyIndex,
  }) : super(
          opcode: _formatOpcode(opCode),
          parameters: _validateBytes(parameters),
          address: _validateAddress(address),
          appKeyIndex: _validateAppKeyIndex(appKeyIndex),
        );

  static String _formatOpcode(int opCode) {
    if (opCode < 0 || opCode > 0xFFFFFFFF) {
      throw ArgumentError.value(opCode, 'opCode', 'Must be a UInt32.');
    }
    final hex = opCode.toRadixString(16);
    return '0x$hex';
  }

  static List<int> _validateBytes(List<int> bytes) {
    for (final b in bytes) {
      if (b < 0 || b > 255) {
        throw ArgumentError.value(b, 'parameters', 'Each byte must be 0..255.');
      }
    }
    return List<int>.unmodifiable(bytes);
  }

  static int _validateAddress(int address) {
    if (address < 0 || address > 0xFFFF) {
      throw ArgumentError.value(address, 'address', 'Must be a UInt16.');
    }
    return address;
  }

  static int _validateAppKeyIndex(int appKeyIndex) {
    // Bluetooth Mesh AppKey Index is 12-bit (0..4095).
    if (appKeyIndex < 0 || appKeyIndex > 0x0FFF) {
      throw ArgumentError.value(appKeyIndex, 'appKeyIndex', 'Must be 0..4095.');
    }
    return appKeyIndex;
  }
}

