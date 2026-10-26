import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/wireless_classifier.dart';

/// Fixed room equipment worth remembering for the next exam in the room:
/// Wi-Fi access points, classic Bluetooth fixtures and named BLE gear
/// (printers, projectors, TVs). Never phones, earpieces, watches, hotspots
/// or anything suspicious — those change address and are exactly what an
/// exam must flag.
bool isRoomEquipment(ScannedDeviceModel d) {
  if (d.isHighSuspicion) return false;
  final type = d.deviceType;
  bool personal() =>
      type.contains('Smartphone') ||
      type.contains('Audio') ||
      type.contains('Wearable') ||
      type.contains('ESP32') ||
      type == ScannedDeviceModel.appleHiddenType ||
      type == WirelessClassifier.hotspotType;
  return switch (d.transport) {
    DeviceTransport.wifi => type != WirelessClassifier.hotspotType,
    DeviceTransport.classic => !personal(),
    DeviceTransport.ble => d.hasName && !personal(),
  };
}
