import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

/// Uses wall-clock delays only (`dart:async` + `flutter_test`) — no extra pub deps.
void main() {
  const quiet = Duration(milliseconds: 50);

  test('debounceMeshNetworkUpdates forwards latest after quiet period', () async {
    final source = StreamController<int>.broadcast();
    final out = <int>[];
    final sub = debounceMeshNetworkUpdates(source.stream, quiet).listen(out.add);

    source.add(1);
    source.add(2);
    await Future<void>.delayed(quiet + const Duration(milliseconds: 25));
    expect(out, [2]);

    await sub.cancel();
    await source.close();
  });

  test('debounceMeshNetworkUpdates emits again after a later burst', () async {
    final source = StreamController<int>.broadcast();
    final out = <int>[];
    final sub = debounceMeshNetworkUpdates(source.stream, quiet).listen(out.add);

    source.add(1);
    await Future<void>.delayed(quiet + const Duration(milliseconds: 25));
    expect(out, [1]);

    source.add(5);
    await Future<void>.delayed(quiet + const Duration(milliseconds: 25));
    expect(out, [1, 5]);

    await sub.cancel();
    await source.close();
  });
}
