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
    final msgSub = PlatoJobsNrfMeshManager.instance.messageStream.listen(
      received.add,
    );

    final discovered = <UnprovisionedDevice>[];
    final sub = PlatoJobsNrfMeshManager.instance.scanForDevices().listen(
      discovered.add,
    );

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
      PlatoJobsNrfMeshManager.instance.sendMessage(
        GenericOnOffSet(state: true),
      ),
      throwsA(isA<Exception>()),
    );

    await fake.dispose();
  });

  test('Fake bridge records sent messages', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    await PlatoJobsNrfMeshManager.instance.sendMessage(
      GenericOnOffSet(state: true),
    );

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

  test('Fake bridge reports RX capability flags', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    expect(
      await PlatoJobsNrfMeshManager.instance.supportsRxSourceAddress(),
      true,
    );
    expect(
      await PlatoJobsNrfMeshManager.instance.supportsRxAppKeyIndex(),
      false,
    );
    expect(await PlatoJobsNrfMeshManager.instance.supportsProxyFilter(), false);
    expect(
      await PlatoJobsNrfMeshManager.instance.supportsAutomaticProxyFilter(),
      false,
    );

    await fake.dispose();
  });

  test('Fake bridge exposes aggregated capability snapshot', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    final caps = await PlatoJobsNrfMeshManager.instance.getCapabilities();
    expect(caps.rxSourceAddress, true);
    expect(caps.rxAppKeyIndex, false);
    expect(caps.proxyFilter, MeshProxyFilterCapability.unsupported);

    await fake.dispose();
  });

  test('Fake bridge can simulate explicit Proxy Filter capability', () async {
    final fake = FakePlatoJobsMeshBridge(
      rxSourceAddressSupported: false,
      rxAppKeyIndexSupported: true,
      proxyFilterSupported: true,
    );
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    final caps = await PlatoJobsNrfMeshManager.instance.getCapabilities();
    expect(caps.rxSourceAddress, false);
    expect(caps.rxAppKeyIndex, true);
    expect(caps.proxyFilter, MeshProxyFilterCapability.explicitControl);

    await fake.dispose();
  });

  test('Fake bridge supports explicit Proxy Filter operations', () async {
    final fake = FakePlatoJobsMeshBridge(proxyFilterSupported: true);
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    expect(
      await PlatoJobsNrfMeshManager.instance.setProxyFilterType(
        MeshProxyFilterType.blacklist,
      ),
      true,
    );
    expect(
      await PlatoJobsNrfMeshManager.instance.addProxyFilterAddresses(
        const <int>[0x0003, 0xC000],
      ),
      true,
    );
    expect(
      await PlatoJobsNrfMeshManager.instance.removeProxyFilterAddresses(
        const <int>[0x0003],
      ),
      true,
    );

    expect(fake.proxyFilterType, MeshProxyFilterType.blacklist);
    expect(fake.proxyFilterAddresses, <int>{0xC000});

    await fake.dispose();
  });

  test(
    'Proxy Filter operations are serialized through the command queue',
    () async {
      final fake = FakePlatoJobsMeshBridge(proxyFilterSupported: true);
      fake.nextProxyFilterDelay = const Duration(milliseconds: 40);
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      await Future.wait<void>(<Future<void>>[
        PlatoJobsNrfMeshManager.instance.setProxyFilterType(
          MeshProxyFilterType.blacklist,
        ),
        PlatoJobsNrfMeshManager.instance.addProxyFilterAddresses(const <int>[
          0x0003,
        ]),
        PlatoJobsNrfMeshManager.instance.removeProxyFilterAddresses(const <int>[
          0x0003,
        ]),
      ]);

      expect(fake.proxyFilterOperationLog, <String>[
        'set:blacklist',
        'add:3',
        'remove:3',
      ]);
      expect(fake.proxyFilterType, MeshProxyFilterType.blacklist);
      expect(fake.proxyFilterAddresses, isEmpty);

      await fake.dispose();
    },
  );

  test(
    'syncProxyFilter sets full state first and diffs later updates',
    () async {
      final fake = FakePlatoJobsMeshBridge(proxyFilterSupported: true);
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      expect(
        await PlatoJobsNrfMeshManager.instance.syncProxyFilter(
          MeshProxyFilterType.blacklist,
          const <int>[0xC000, 0x0003, 0xC000],
        ),
        true,
      );
      expect(fake.proxyFilterOperationLog, <String>[
        'set:blacklist',
        'add:3,49152',
      ]);
      expect(fake.proxyFilterType, MeshProxyFilterType.blacklist);
      expect(fake.proxyFilterAddresses, <int>{0x0003, 0xC000});

      fake.proxyFilterOperationLog.clear();

      expect(
        await PlatoJobsNrfMeshManager.instance.syncProxyFilter(
          MeshProxyFilterType.blacklist,
          const <int>[0xC000, 0x0004],
        ),
        true,
      );
      expect(fake.proxyFilterOperationLog, <String>['remove:3', 'add:4']);
      expect(fake.proxyFilterAddresses, <int>{0x0004, 0xC000});

      fake.proxyFilterOperationLog.clear();

      expect(
        await PlatoJobsNrfMeshManager.instance.syncProxyFilter(
          MeshProxyFilterType.whitelist,
          const <int>[],
        ),
        true,
      );
      expect(fake.proxyFilterOperationLog, <String>['set:whitelist']);
      expect(fake.proxyFilterType, MeshProxyFilterType.whitelist);
      expect(fake.proxyFilterAddresses, isEmpty);

      await fake.dispose();
    },
  );

  test(
    'Proxy Filter address validation rejects empty and out-of-range values',
    () async {
      final fake = FakePlatoJobsMeshBridge(proxyFilterSupported: true);
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      await expectLater(
        () => PlatoJobsNrfMeshManager.instance.addProxyFilterAddresses(
          const <int>[],
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => PlatoJobsNrfMeshManager.instance.addProxyFilterAddresses(
          const <int>[0x0000],
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => PlatoJobsNrfMeshManager.instance.removeProxyFilterAddresses(
          const <int>[0x1_0000],
        ),
        throwsA(isA<ArgumentError>()),
      );

      await fake.dispose();
    },
  );

  test('Fake bridge can simulate automatic Proxy Filter capability', () async {
    final fake = FakePlatoJobsMeshBridge(automaticProxyFilterSupported: true);
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    expect(
      await PlatoJobsNrfMeshManager.instance.supportsAutomaticProxyFilter(),
      true,
    );

    final caps = await PlatoJobsNrfMeshManager.instance.getCapabilities();
    expect(caps.proxyFilter, MeshProxyFilterCapability.automaticOnly);

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

    final ok1 = await PlatoJobsNrfMeshManager.instance.bindAppKey(
      0x0001,
      0x1000,
      0,
    );
    final ok2 = await PlatoJobsNrfMeshManager.instance.addSubscription(
      0x0001,
      0x1000,
      0xC000,
    );
    final ok3 = await PlatoJobsNrfMeshManager.instance.setPublication(
      0x0001,
      0x1000,
      0xC000,
      0,
      ttl: 5,
    );
    final ok4 = await PlatoJobsNrfMeshManager.instance.removeSubscription(
      0x0001,
      0x1000,
      0xC000,
    );
    final ok5 = await PlatoJobsNrfMeshManager.instance.unbindAppKey(
      0x0001,
      0x1000,
      0,
    );

    expect(ok1, true);
    expect(ok2, true);
    expect(ok3, true);
    expect(ok4, true);
    expect(ok5, true);

    final nodes = await PlatoJobsNrfMeshManager.instance.getNodes();
    expect(nodes.isNotEmpty, true);
    final element = nodes.first.elements.first;
    final model = element.models.firstWhere(
      (m) => m.modelId == '4096',
    ); // 0x1000
    expect(model.boundAppKeyIndexes, isEmpty);
    expect(model.subscriptions, isEmpty);

    await fake.dispose();
  });

  test('Mesh bearer snapshot reflects fake proxy connection', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();

    expect(
      (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
      MeshBearerPhase.disconnected,
    );

    await PlatoJobsNrfMeshManager.instance.connectProxy('dev-proxy', 0x0003);
    expect(
      (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
      MeshBearerPhase.proxyReady,
    );

    await PlatoJobsNrfMeshManager.instance.disconnectProxy();
    expect(
      (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
      MeshBearerPhase.disconnected,
    );

    await fake.dispose();
  });

  test(
    'Mesh bearer snapshot reflects proxyConnecting while connect is in flight',
    () async {
      final fake = _DelayedProxyBridge();
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      final connectFuture = PlatoJobsNrfMeshManager.instance.connectProxy(
        'dev-proxy',
        0x0003,
      );

      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.proxyConnecting,
      );

      await connectFuture;
      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.proxyReady,
      );

      await fake.dispose();
    },
  );

  test(
    'Mesh bearer snapshot returns to disconnected after failed proxy connect',
    () async {
      final fake = _DelayedFailingProxyBridge();
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      final connectFuture = PlatoJobsNrfMeshManager.instance.connectProxy(
        'dev-proxy',
        0x0003,
      );

      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.proxyConnecting,
      );

      expect(await connectFuture, false);
      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.disconnected,
      );

      await fake.dispose();
    },
  );

  test(
    'Mesh bearer snapshot reflects provisioningConnecting while connect is in flight',
    () async {
      final fake = _DelayedProvisioningBridge();
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      final connectFuture = PlatoJobsNrfMeshManager.instance
          .connectProvisioning('dev-prov');

      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.provisioningConnecting,
      );

      await connectFuture;
      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.provisioning,
      );

      await fake.dispose();
    },
  );

  test(
    'Mesh bearer snapshot returns to disconnected after failed provisioning connect',
    () async {
      final fake = _DelayedFailingProvisioningBridge();
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      final connectFuture = PlatoJobsNrfMeshManager.instance
          .connectProvisioning('dev-prov');

      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.provisioningConnecting,
      );

      expect(await connectFuture, false);
      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.disconnected,
      );

      await fake.dispose();
    },
  );

  test(
    'Concurrent proxy connect then disconnect resolves in disconnect order',
    () async {
      final fake = _DelayedProxyBridge();
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      final connectFuture = PlatoJobsNrfMeshManager.instance.connectProxy(
        'dev-proxy',
        0x0003,
      );
      final disconnectFuture = PlatoJobsNrfMeshManager.instance
          .disconnectProxy();

      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.proxyConnecting,
      );

      expect(await connectFuture, true);
      expect(await disconnectFuture, true);
      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.disconnected,
      );

      await fake.dispose();
    },
  );

  test(
    'Concurrent provisioning connect then disconnect resolves in disconnect order',
    () async {
      final fake = _DelayedProvisioningBridge();
      PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
      await PlatoJobsNrfMeshManager.instance.initialize();

      final connectFuture = PlatoJobsNrfMeshManager.instance
          .connectProvisioning('dev-prov');
      final disconnectFuture = PlatoJobsNrfMeshManager.instance
          .disconnectProvisioning();

      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.provisioningConnecting,
      );

      expect(await connectFuture, true);
      expect(await disconnectFuture, true);
      expect(
        (await PlatoJobsNrfMeshManager.instance.getMeshBearerSnapshot()).phase,
        MeshBearerPhase.disconnected,
      );

      await fake.dispose();
    },
  );

  test('Proxy auto-reconnect retries after unexpected bearer loss', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();
    PlatoJobsNrfMeshManager.instance.setProxyAutoReconnectPolicy(
      const MeshProxyAutoReconnectPolicy(
        enabled: true,
        maxAttempts: 2,
        retryDelay: Duration(milliseconds: 5),
        healthCheckInterval: Duration(milliseconds: 5),
      ),
    );

    expect(
      await PlatoJobsNrfMeshManager.instance.connectProxy('dev-proxy', 0x0003),
      true,
    );
    expect(fake.proxyConnectCallCount, 1);

    fake.setProxyConnectedForTesting(false);
    fake.queuedProxyConnectResults.add(true);

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(fake.proxyConnectCallCount, greaterThanOrEqualTo(2));
    expect(await PlatoJobsNrfMeshManager.instance.isProxyConnected(), true);

    PlatoJobsNrfMeshManager.instance.setProxyAutoReconnectPolicy(
      MeshProxyAutoReconnectPolicy.disabled,
    );
    await fake.dispose();
  });

  test('Manual proxy disconnect cancels auto-reconnect target', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();
    PlatoJobsNrfMeshManager.instance.setProxyAutoReconnectPolicy(
      const MeshProxyAutoReconnectPolicy(
        enabled: true,
        maxAttempts: 2,
        retryDelay: Duration(milliseconds: 5),
        healthCheckInterval: Duration(milliseconds: 5),
      ),
    );

    expect(
      await PlatoJobsNrfMeshManager.instance.connectProxy('dev-proxy', 0x0003),
      true,
    );
    expect(fake.proxyConnectCallCount, 1);

    await PlatoJobsNrfMeshManager.instance.disconnectProxy();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(fake.proxyConnectCallCount, 1);
    expect(await PlatoJobsNrfMeshManager.instance.isProxyConnected(), false);

    PlatoJobsNrfMeshManager.instance.setProxyAutoReconnectPolicy(
      MeshProxyAutoReconnectPolicy.disabled,
    );
    await fake.dispose();
  });

  test('Proxy auto-reconnect stops after max attempts', () async {
    final fake = FakePlatoJobsMeshBridge();
    PlatoJobsNrfMeshManager.setBridgeForTesting(fake);
    await PlatoJobsNrfMeshManager.instance.initialize();
    PlatoJobsNrfMeshManager.instance.setProxyAutoReconnectPolicy(
      const MeshProxyAutoReconnectPolicy(
        enabled: true,
        maxAttempts: 2,
        retryDelay: Duration(milliseconds: 5),
        healthCheckInterval: Duration(milliseconds: 5),
      ),
    );

    expect(
      await PlatoJobsNrfMeshManager.instance.connectProxy('dev-proxy', 0x0003),
      true,
    );
    fake.setProxyConnectedForTesting(false);
    fake.queuedProxyConnectResults.addAll([false, false]);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(fake.proxyConnectCallCount, 3);
    expect(await PlatoJobsNrfMeshManager.instance.isProxyConnected(), false);

    PlatoJobsNrfMeshManager.instance.setProxyAutoReconnectPolicy(
      MeshProxyAutoReconnectPolicy.disabled,
    );
    await fake.dispose();
  });
}

class _DelayedProxyBridge extends FakePlatoJobsMeshBridge {
  @override
  Future<bool> connectProxy(String deviceId, int proxyUnicastAddress) async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return super.connectProxy(deviceId, proxyUnicastAddress);
  }
}

class _DelayedProvisioningBridge extends FakePlatoJobsMeshBridge {
  @override
  Future<bool> connectProvisioning(String deviceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return super.connectProvisioning(deviceId);
  }
}

class _DelayedFailingProxyBridge extends FakePlatoJobsMeshBridge {
  @override
  Future<bool> connectProxy(String deviceId, int proxyUnicastAddress) async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return false;
  }
}

class _DelayedFailingProvisioningBridge extends FakePlatoJobsMeshBridge {
  @override
  Future<bool> connectProvisioning(String deviceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return false;
  }
}
