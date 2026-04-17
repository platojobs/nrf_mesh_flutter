import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_mesh_flutter/platojobs_nrf_mesh_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelPlatoJobsMesh();
  const MethodChannel channel = MethodChannel('platojobs_nrf_mesh');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
