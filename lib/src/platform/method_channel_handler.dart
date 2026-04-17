import 'dart:async';
import 'package:flutter/services.dart';

import '../models/unprovisioned_device.dart';
import '../models/mesh_message.dart';

class MethodChannelHandler {
  static const MethodChannel _channel = MethodChannel('nrf_mesh_flutter');
  static const EventChannel _scanEventChannel = EventChannel(
    'nrf_mesh_flutter/scan',
  );
  static const EventChannel _messageEventChannel = EventChannel(
    'nrf_mesh_flutter/message',
  );

  late StreamSubscription<dynamic> _scanSubscription;
  late StreamSubscription<dynamic> _messageSubscription;

  Function(UnprovisionedDevice)? _scanCallback;
  Function(MeshMessage)? _messageCallback;

  /// Initialize the method channel handler
  Future<void> initialize() async {
    // Set up event channels
    _scanSubscription = _scanEventChannel.receiveBroadcastStream().listen((
      event,
    ) {
      if (_scanCallback != null && event is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        final Map<String, dynamic> map = event.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        _scanCallback!(UnprovisionedDevice.fromMap(map));
      }
    });

    _messageSubscription = _messageEventChannel.receiveBroadcastStream().listen(
      (event) {
        if (_messageCallback != null && event is Map) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final Map<String, dynamic> map = event.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          _messageCallback!(MeshMessage.fromMap(map));
        }
      },
    );
  }

  /// Set the scan callback
  void setScanCallback(Function(UnprovisionedDevice) callback) {
    _scanCallback = callback;
  }

  /// Set the message callback
  void setMessageCallback(Function(MeshMessage) callback) {
    _messageCallback = callback;
  }

  /// Invoke a method on the platform
  Future<dynamic> invokeMethod(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod(method, arguments);
    } on PlatformException {
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _scanSubscription.cancel();
    _messageSubscription.cancel();
  }
}
