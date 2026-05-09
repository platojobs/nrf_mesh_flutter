import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  group('MeshBearerPhase.fromNativeFlags', () {
    test('disconnected when both false', () {
      expect(
        MeshBearerPhase.fromNativeFlags(
          proxyConnected: false,
          provisioningConnected: false,
        ),
        MeshBearerPhase.disconnected,
      );
    });

    test('proxyReady when only proxy true', () {
      expect(
        MeshBearerPhase.fromNativeFlags(
          proxyConnected: true,
          provisioningConnected: false,
        ),
        MeshBearerPhase.proxyReady,
      );
    });

    test('provisioning when only provisioning true', () {
      expect(
        MeshBearerPhase.fromNativeFlags(
          proxyConnected: false,
          provisioningConnected: true,
        ),
        MeshBearerPhase.provisioning,
      );
    });

    test('provisioning wins when both true', () {
      expect(
        MeshBearerPhase.fromNativeFlags(
          proxyConnected: true,
          provisioningConnected: true,
        ),
        MeshBearerPhase.provisioning,
      );
    });
  });

  group('MeshBearerSnapshot.fromNativeFlags', () {
    test('carries raw flags', () {
      final s = MeshBearerSnapshot.fromNativeFlags(
        proxyConnected: true,
        provisioningConnected: false,
      );
      expect(s.phase, MeshBearerPhase.proxyReady);
      expect(s.proxyConnected, true);
      expect(s.provisioningConnected, false);
    });
  });
}
