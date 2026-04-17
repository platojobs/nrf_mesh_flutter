import 'package:flutter_test/flutter_test.dart';
import 'package:platojobs_nrf_mesh/platojobs_nrf_mesh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provisioning parameters creation', () {
    final params = ProvisioningParameters(
      deviceName: 'Test Device',
      oobMethod: 1,
      oobData: 'test data',
      enablePrivacy: true,
    );
    expect(params.deviceName, 'Test Device');
    expect(params.oobMethod, 1);
    expect(params.oobData, 'test data');
    expect(params.enablePrivacy, true);
  });
}
