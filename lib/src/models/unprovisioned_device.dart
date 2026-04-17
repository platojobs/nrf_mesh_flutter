class UnprovisionedDevice {
  final String deviceId;
  final String name;
  final String serviceUuid;
  final int rssi;
  final List<int> serviceData;

  UnprovisionedDevice({
    required this.deviceId,
    required this.name,
    required this.serviceUuid,
    required this.rssi,
    required this.serviceData,
  });

  factory UnprovisionedDevice.fromMap(Map<String, dynamic> map) {
    return UnprovisionedDevice(
      deviceId: map['deviceId'],
      name: map['name'],
      serviceUuid: map['serviceUuid'],
      rssi: map['rssi'],
      serviceData: List<int>.from(map['serviceData']),
    );
  }

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