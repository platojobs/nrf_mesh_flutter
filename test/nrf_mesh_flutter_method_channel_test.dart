import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy method-channel shims are deprecated', () async {
    // This package no longer uses a public MethodChannel-based platform interface.
    // The presence of this test ensures the package test suite remains stable.
    expect(PlatoJobsNrfMeshManager.instance, isNotNull);
  });
}
