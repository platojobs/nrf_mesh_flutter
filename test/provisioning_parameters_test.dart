import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  group('ProvisioningParameters OOB validation', () {
    test('noOob sets method=0 and null data', () {
      final p = ProvisioningParameters.noOob(deviceName: 'n');
      expect(p.oobMethod, 0);
      expect(p.oobData, isNull);
    });

    test('staticOob accepts even-length hex up to 32 bytes', () {
      final p = ProvisioningParameters.staticOob(
        deviceName: 'n',
        hex: 'aabbcc',
      );
      expect(p.oobMethod, 1);
      expect(p.oobData, 'aabbcc');
    });

    test('staticOob rejects odd-length hex', () {
      expect(
        () => ProvisioningParameters.staticOob(
          deviceName: 'n',
          hex: 'abc',
        ),
        throwsArgumentError,
      );
    });

    test('staticOob rejects non-hex', () {
      expect(
        () => ProvisioningParameters.staticOob(
          deviceName: 'n',
          hex: 'zz',
        ),
        throwsArgumentError,
      );
    });
  });
}

