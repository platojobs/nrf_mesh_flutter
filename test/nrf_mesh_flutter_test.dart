import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provisioning parameters creation', () {
    final params = ProvisioningParameters(
      deviceName: 'Test Device',
      oobMethod: 0,
      oobData: null,
      enablePrivacy: true,
    );
    expect(params.deviceName, 'Test Device');
    expect(params.oobMethod, 0);
    expect(params.oobData, null);
    expect(params.enablePrivacy, true);
  });
}
