/// BLE advertiser discovered during Mesh **Provisioning Service** scan.
class UnprovisionedDevice {
  /// Peripheral identifier from the native BLE stack (UUID string on most platforms).
  final String deviceId;

  /// Human-readable device name when advertisement includes it.
  final String name;

  /// Primary service UUID detected for provisioning (hex string without braces).
  final String serviceUuid;

  /// Advertised RSSI in dBm when available.
  final int rssi;

  /// Raw service data bytes from mesh advertisement (vendor-specific layout).
  final List<int> serviceData;

  /// Constructs scan result passed to [PlatoJobsNrfMeshManager.provisionDevice].
  UnprovisionedDevice({
    required this.deviceId,
    required this.name,
    required this.serviceUuid,
    required this.rssi,
    required this.serviceData,
  });

  /// Parses cached discovery payloads (maps JSON-style fields).
  factory UnprovisionedDevice.fromMap(Map<String, dynamic> map) {
    return UnprovisionedDevice(
      deviceId: map['deviceId'],
      name: map['name'],
      serviceUuid: map['serviceUuid'],
      rssi: map['rssi'],
      serviceData: List<int>.from(map['serviceData']),
    );
  }

  /// Serialize for debugging / persistence helpers.
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'name': name,
      'serviceUuid': serviceUuid,
      'rssi': rssi,
      'serviceData': serviceData,
    };
  }
}
