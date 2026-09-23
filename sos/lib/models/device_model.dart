class DeviceModel {
  final int? id;
  final String deviceName;
  final String deviceIdentifier;
  final String deviceType;
  final bool isActive;
  final int batteryLevel;

  DeviceModel({
    this.id,
    required this.deviceName,
    required this.deviceIdentifier,
    this.deviceType = 'ble_button',
    this.isActive = true,
    this.batteryLevel = 100,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'],
      deviceName: json['device_name'] ?? json['deviceName'] ?? 'SOS Button',
      deviceIdentifier: json['device_identifier'] ?? json['deviceIdentifier'] ?? '',
      deviceType: json['device_type'] ?? json['deviceType'] ?? 'ble_button',
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      batteryLevel: json['battery_level'] ?? json['batteryLevel'] ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'deviceIdentifier': deviceIdentifier,
      'deviceType': deviceType,
      'isActive': isActive,
      'batteryLevel': batteryLevel,
    };
  }
}

class AlertModel {
  final int id;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String triggerSource;
  final String status;
  final int smsCount;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    this.latitude,
    this.longitude,
    this.address,
    required this.triggerSource,
    required this.status,
    required this.smsCount,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] is int ? json['id'] : 0,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      address: json['address'],
      triggerSource: json['trigger_source'] ?? json['triggerSource'] ?? 'app_button',
      status: json['status'] ?? 'triggered',
      smsCount: json['sms_count'] ?? json['smsCount'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
