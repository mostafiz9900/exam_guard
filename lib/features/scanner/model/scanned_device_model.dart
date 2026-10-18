import 'package:meta/meta.dart';

/// How a device was found. Only BLE gives live, continuous signal updates;
/// classic Bluetooth and Wi-Fi results arrive every few seconds.
enum DeviceTransport { ble, classic, wifi }

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
  final DeviceTransport transport;

  /// Classic Bluetooth device class says headset / hands-free / headphones:
  /// the profile of the classic "spy" earpieces sold for exam cheating.
  final bool isHighSuspicion;

  bool get isBle => transport == DeviceTransport.ble;

  /// The radio address: the BLE/classic MAC, or the Wi-Fi BSSID (the [id]
  /// of a Wi-Fi network carries a `wifi:` prefix so it never clashes with a
  /// Bluetooth address).
  String get address =>
      id.startsWith(wifiIdPrefix) ? id.substring(wifiIdPrefix.length) : id;

  /// Prefix of [id] for Wi-Fi access points.
  static const String wifiIdPrefix = 'wifi:';

  /// Manufacturer of a classic Bluetooth device whose vendor is unknown.
  static const String genericBluetoothManufacturer = 'Generic Bluetooth';

  /// Manufacturer value of every Wi-Fi access point.
  static const String wifiManufacturer = 'Wi-Fi';

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
    this.transport = DeviceTransport.ble,
    this.isHighSuspicion = false,
  });

  /// Advertised (or GATT) name, otherwise a label built from what the
  /// device is, e.g. "Apple Device (4F:2A)".
  String get displayName {
    final gatt = fullGattName?.trim() ?? '';
    if (gatt.isNotEmpty) return gatt;
    if (name.trim().isNotEmpty) return name.trim();

    final suffix = id.length >= 5 ? id.substring(id.length - 5) : id;
    if (transport == DeviceTransport.wifi) return 'Hidden Wi-Fi ($suffix)';
    if (manufacturer.contains('Apple')) {
      return deviceType.contains('Audio')
          ? 'AirPods / Beats ($suffix)'
          : 'Apple Device ($suffix)';
    }
    if (manufacturer.contains('Samsung')) return 'Samsung Device ($suffix)';
    if (manufacturer.contains('Espressif')) return 'ESP32 Module ($suffix)';
    if (deviceType.contains('Audio')) return 'Wireless Earpiece ($suffix)';
    if (deviceType.contains('Wearable')) return 'Smartband / Watch ($suffix)';
    if (manufacturer != 'Generic BLE Hardware' &&
        manufacturer != genericBluetoothManufacturer) {
      return '$manufacturer ($suffix)';
    }
    return transport == DeviceTransport.classic
        ? 'Bluetooth Device ($suffix)'
        : 'Hidden BLE Device ($suffix)';
  }

  /// True when this device is advertising under a name.
  bool get hasName => name.trim().isNotEmpty || (fullGattName ?? '').isNotEmpty;

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
    DeviceTransport? transport,
    bool? isHighSuspicion,
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
      transport: transport ?? this.transport,
      isHighSuspicion: isHighSuspicion ?? this.isHighSuspicion,
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
