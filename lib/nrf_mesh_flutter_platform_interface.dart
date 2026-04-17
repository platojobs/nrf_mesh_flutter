import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nrf_mesh_flutter_method_channel.dart';

abstract class NrfMeshFlutterPlatform extends PlatformInterface {
  /// Constructs a NrfMeshFlutterPlatform.
  NrfMeshFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static NrfMeshFlutterPlatform _instance = MethodChannelNrfMeshFlutter();

  /// The default instance of [NrfMeshFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelNrfMeshFlutter].
  static NrfMeshFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NrfMeshFlutterPlatform] when
  /// they register themselves.
  static set instance(NrfMeshFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
