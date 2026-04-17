import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fake bridge can drive scan + message streams', () async {
    final fake = FakePlatoJobsMeshBridge(
      scenario: FakeMeshScenario()
          .add(
            FakeMeshScenarioStep.discoveredDevice(
              UnprovisionedDevice(
                deviceId: 'dev-1',
                name: 'Demo',
                serviceUuid: '',
                rssi: -40,
                serviceData: const <int>[1, 2, 3],
              ),
            ),
          )
          .add(
            FakeMeshScenarioStep.incomingMessage(
              GenericOnOffSet(state: true),
              delay: const Duration(milliseconds: 10),
            ),
          ),
    );
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);

    await PlatoJobsNrfMeshManager.instance.initialize();

    final received = <MeshMessage>[];
    final msgSub = PlatoJobsNrfMeshManager.instance.messageStream.listen(received.add);

    final discovered = <UnprovisionedDevice>[];
    final sub = PlatoJobsNrfMeshManager.instance.scanForDevices().listen(discovered.add);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(discovered.length, 1);
    expect(discovered.single.deviceId, 'dev-1');

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(received.isNotEmpty, true);

    await sub.cancel();
    await msgSub.cancel();
    await fake.dispose();
  });

  test('Fake bridge can inject sendMessage failure', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    fake.nextSendMessageError = Exception('boom');
    await expectLater(
      PlatoJobsNrfMeshManager.instance.sendMessage(GenericOnOffSet(state: true)),
      throwsA(isA<Exception>()),
    );

    await fake.dispose();
  });
}

