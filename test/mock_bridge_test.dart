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

  test('Fake bridge records sent messages', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    await PlatoJobsNrfMeshManager.instance.sendMessage(GenericOnOffSet(state: true));

    expect(fake.sentMessages.length, 1);
    expect(fake.sentMessages.single, isA<GenericOnOffSet>());

    await fake.dispose();
  });

  test('Fake bridge can inject provision failure', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    fake.nextProvisionError = Exception('provision failed');
    await expectLater(
      PlatoJobsNrfMeshManager.instance.provisionDevice(
        UnprovisionedDevice(
          deviceId: 'dev-x',
          name: 'X',
          serviceUuid: '',
          rssi: -10,
          serviceData: const <int>[1],
        ),
        ProvisioningParameters(deviceName: 'X'),
      ),
      throwsA(isA<Exception>()),
    );

    await fake.dispose();
  });

  test('Fake bridge supports minimal configuration operations', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    await PlatoJobsNrfMeshManager.instance.provisionDevice(
      UnprovisionedDevice(
        deviceId: 'dev-cfg',
        name: 'Cfg',
        serviceUuid: '',
        rssi: -10,
        serviceData: const <int>[1],
      ),
      ProvisioningParameters(deviceName: 'Cfg'),
    );

    final ok1 = await PlatoJobsNrfMeshManager.instance.bindAppKey(0x0001, 0x1000, 0);
    final ok2 = await PlatoJobsNrfMeshManager.instance.addSubscription(0x0001, 0x1000, 0xC000);
    final ok3 = await PlatoJobsNrfMeshManager.instance.setPublication(
      0x0001,
      0x1000,
      0xC000,
      0,
      ttl: 5,
    );
    final ok4 = await PlatoJobsNrfMeshManager.instance.removeSubscription(0x0001, 0x1000, 0xC000);
    final ok5 = await PlatoJobsNrfMeshManager.instance.unbindAppKey(0x0001, 0x1000, 0);

    expect(ok1, true);
    expect(ok2, true);
    expect(ok3, true);
    expect(ok4, true);
    expect(ok5, true);

    final nodes = await PlatoJobsNrfMeshManager.instance.getNodes();
    expect(nodes.isNotEmpty, true);
    final element = nodes.first.elements.first;
    final model = element.models.firstWhere((m) => m.modelId == '4096'); // 0x1000
    expect(model.boundAppKeyIndexes, isEmpty);
    expect(model.subscriptions, isEmpty);

    await fake.dispose();
  });
}

