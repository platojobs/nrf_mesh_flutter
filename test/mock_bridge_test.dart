import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fake bridge can drive scan + message streams', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);

    await PlatoJobsNrfMeshManager.instance.initialize();

    final discovered = <UnprovisionedDevice>[];
    final sub = PlatoJobsNrfMeshManager.instance.scanForDevices().listen(discovered.add);

    fake.emitDiscoveredDevice(
      UnprovisionedDevice(
        deviceId: 'dev-1',
        name: 'Demo',
        serviceUuid: '',
        rssi: -40,
        serviceData: const <int>[1, 2, 3],
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(discovered.length, 1);
    expect(discovered.single.deviceId, 'dev-1');

    final received = <MeshMessage>[];
    final msgSub = PlatoJobsNrfMeshManager.instance.messageStream.listen(received.add);
    await PlatoJobsNrfMeshManager.instance.sendMessage(GenericOnOffSet(state: true));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(received.isNotEmpty, true);

    await sub.cancel();
    await msgSub.cancel();
    await fake.dispose();
  });
}

