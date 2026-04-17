import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'platojobs_nrf_mesh_method_channel.dart';

abstract class PlatoJobsMeshPlatform extends PlatformInterface {
  PlatoJobsMeshPlatform() : super(token: _token);

  static final Object _token = Object();

  static PlatoJobsMeshPlatform _instance = MethodChannelPlatoJobsMesh();

  static PlatoJobsMeshPlatform get instance => _instance;

  static set instance(PlatoJobsMeshPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
