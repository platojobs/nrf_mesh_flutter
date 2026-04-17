// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mesh manager initialization test', (WidgetTester tester) async {
    // Initialize the mesh manager
    await NrfMeshManager.instance.initialize();
    
    // Test network creation
    final network = await NrfMeshManager.instance.createNetwork('Test Network');
    expect(network.name, 'Test Network');
  });
}
