import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platojobs_nrf_mesh_platform_interface.dart';

class MethodChannelPlatoJobsMesh extends PlatoJobsMeshPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('platojobs_nrf_mesh');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
