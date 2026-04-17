import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mesh manager instance creation', () {
    // Test that the singleton instance is created correctly
    final instance1 = NrfMeshManager.instance;
    final instance2 = NrfMeshManager.instance;
    expect(instance1, same(instance2));
  });

  test('provisioning parameters creation', () {
    // Test that provisioning parameters are created correctly
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
