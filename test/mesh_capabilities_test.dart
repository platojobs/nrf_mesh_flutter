import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  test('MeshCapabilities maps automatic proxy filter support', () {
    final caps = MeshCapabilities.fromSupportFlags(
      rxSourceAddress: true,
      rxAppKeyIndex: false,
      supportsProxyFilter: false,
      supportsAutomaticProxyFilter: true,
    );

    expect(caps.rxSourceAddress, true);
    expect(caps.rxAppKeyIndex, false);
    expect(caps.proxyFilter, MeshProxyFilterCapability.automaticOnly);
  });

  test('explicit proxy filter support wins over automatic support', () {
    final caps = MeshCapabilities.fromSupportFlags(
      rxSourceAddress: true,
      rxAppKeyIndex: false,
      supportsProxyFilter: true,
      supportsAutomaticProxyFilter: true,
    );

    expect(caps.proxyFilter, MeshProxyFilterCapability.explicitControl);
  });
}
