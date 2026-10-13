import 'package:meta/meta.dart';

@immutable
class ScannedDeviceModel {
  final String id;
  final String name;
  final String manufacturer;
  final String deviceType;
  final int rssi;
  final int? txPower;
  final bool isConnectable;
  final List<String> serviceUuids;
  final DateTime lastSeen;
  final DateTime firstSeen;
  final bool isConnected;
  final bool isConnecting;
  final int? batteryLevel;
  final String? fullGattName;

  const ScannedDeviceModel({
    required this.id,
    required this.name,
    this.manufacturer = 'Generic BLE Hardware',
    this.deviceType = 'BLE Broadcast Beacon',
    required this.rssi,
    this.txPower,
    this.isConnectable = true,
    this.serviceUuids = const [],
    required this.lastSeen,
    required this.firstSeen,
    this.isConnected = false,
    this.isConnecting = false,
    this.batteryLevel,
    this.fullGattName,
  });

  /// Displays human readable name or manufacturer fallback
  String get displayName {
    if (fullGattName != null && fullGattName!.isNotEmpty) {
      return fullGattName!;
    }
    if (name.isNotEmpty && name != 'Unknown Device') {
      return name;
    }
    if (manufacturer.isNotEmpty && manufacturer != 'Generic BLE Hardware') {
      return '$manufacturer (Hidden Name)';
    }
    return 'Hidden BLE Device (${id.length > 8 ? id.substring(id.length - 8) : id})';
  }

  ScannedDeviceModel copyWith({
    String? id,
    String? name,
    String? manufacturer,
    String? deviceType,
    int? rssi,
    int? txPower,
    bool? isConnectable,
    List<String>? serviceUuids,
    DateTime? lastSeen,
    DateTime? firstSeen,
    bool? isConnected,
    bool? isConnecting,
    int? batteryLevel,
    String? fullGattName,
  }) {
    return ScannedDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      deviceType: deviceType ?? this.deviceType,
      rssi: rssi ?? this.rssi,
      txPower: txPower ?? this.txPower,
      isConnectable: isConnectable ?? this.isConnectable,
      serviceUuids: serviceUuids ?? this.serviceUuids,
      lastSeen: lastSeen ?? this.lastSeen,
      firstSeen: firstSeen ?? this.firstSeen,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      fullGattName: fullGattName ?? this.fullGattName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedDeviceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ScannedDeviceModel(id: $id, name: $name, manufacturer: $manufacturer, rssi: $rssi, isConnected: $isConnected)';
  }
}
