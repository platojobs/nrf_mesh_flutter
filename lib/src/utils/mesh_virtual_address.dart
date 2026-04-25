// Bluetooth Mesh: Virtual Address from Label UUID (Nordic / nRFMeshProvision compatible).
// Reference: iOS nRFMeshProvision Crypto.calculateVirtualAddress — S1("vtad") then
// AES-CMAC over the 16 octet label using that salt, then the last 16 bits with 0b10?????????????.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/macs/cmac.dart';

/// Thrown when [labelUuid] is not exactly 16 bytes.
void _requireLabel16(List<int> labelUuid) {
  if (labelUuid.length != 16) {
    throw ArgumentError.value(
      labelUuid,
      'labelUuid',
      'Label UUID must be 16 bytes (0..255 each), got length ${labelUuid.length}.',
    );
  }
  for (final b in labelUuid) {
    if (b < 0 || b > 255) {
      throw ArgumentError.value(labelUuid, 'labelUuid', 'Each byte must be 0..255.');
    }
  }
}

/// AES-128 CMAC in one shot (16-byte MAC) — matches Nordic helper usage for Mesh salt/MACs.
Uint8List _cmac(Uint8List key, Uint8List message) {
  final cmac = CMac(AESEngine(), 128)..init(KeyParameter(key));
  return cmac.process(message);
}

/// Computes the 16-bit Virtual Address (0x8000..0xBFFF) for a 128-bit Label.
///
/// This is pure Dart; use the same [labelUuid] byte order as the native stack when
/// you create a virtual [Group] / [VirtualAddress] (16 bytes, per mesh configuration).
int meshVirtualAddressFromLabel(List<int> labelUuid) {
  _requireLabel16(labelUuid);
  // salt = s1 = AES-CMAC_0^128("vtad")
  final zeroKey = Uint8List(16);
  final vtad = utf8.encode('vtad');
  final salt = _cmac(zeroKey, Uint8List.fromList(vtad));
  final label = Uint8List.fromList(labelUuid);
  final mac = _cmac(salt, label);
  var v = ((mac[14] & 0xFF) << 8) | (mac[15] & 0xFF);
  v |= 0x8000;
  v &= 0xBFFF;
  return v;
}
