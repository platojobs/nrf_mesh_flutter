import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mesh manager initialization test', (WidgetTester tester) async {
    await PlatoJobsNrfMeshManager.instance.initialize();

    final network = await PlatoJobsNrfMeshManager.instance.createNetwork(
      'Test Network',
    );
    expect(network.name, 'Test Network');
  });
}
