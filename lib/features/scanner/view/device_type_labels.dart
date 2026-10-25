import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Display names for the scanner's device categories. The model keeps the
/// English `deviceType` strings because they are matched with `contains()`;
/// these helpers translate them only when shown.

/// Full category name, e.g. "Smart Earpiece / Audio".
String deviceTypeLabel(String type) {
  if (type == ScannedDeviceModel.appleHiddenType) {
    return 'scan_type_apple_hidden'.tr();
  }
  if (type == 'Wi-Fi Access Point') return 'scan_type_wifi_ap'.tr();
  if (type == 'Computer / Laptop') return 'scan_type_computer'.tr();
  if (type == 'Bluetooth Device') return 'scan_type_classic_other'.tr();
  if (type.contains('ESP32')) return 'scan_type_esp32'.tr();
  if (type.contains('Audio')) return 'scan_type_earpiece'.tr();
  if (type.contains('Hotspot') || type.contains('AP')) {
    return 'scan_type_hotspot'.tr();
  }
  if (type.contains('Wearable')) return 'scan_type_wearable'.tr();
  if (type.contains('Smartphone')) return 'scan_type_smartphone'.tr();
  if (type == 'BLE Broadcast Beacon') return 'scan_type_beacon'.tr();
  // Unknown categories (e.g. "Service (180D)") are shown as reported.
  return type;
}

/// Short category name for small badges, e.g. "Smart Earpiece".
String deviceTypeShortLabel(String type) {
  if (type == ScannedDeviceModel.appleHiddenType) {
    return 'scan_short_apple'.tr();
  }
  if (type == 'Wi-Fi Access Point') return 'scan_short_wifi_ap'.tr();
  if (type == 'Computer / Laptop') return 'scan_short_computer'.tr();
  if (type == 'Bluetooth Device') return 'scan_short_classic_other'.tr();
  if (type.contains('ESP32')) return 'scan_short_esp32'.tr();
  if (type.contains('Audio')) return 'scan_short_earpiece'.tr();
  if (type.contains('Hotspot') || type.contains('AP')) {
    return 'scan_short_hotspot'.tr();
  }
  if (type.contains('Wearable')) return 'scan_short_wearable'.tr();
  if (type.contains('Smartphone')) return 'scan_short_smartphone'.tr();
  return 'scan_short_ble'.tr();
}

/// Manufacturer as shown; the generic placeholder is translated, real
/// vendor names are not.
String manufacturerLabel(String manufacturer) => switch (manufacturer) {
  'Generic BLE Hardware' => 'scan_manufacturer_generic'.tr(),
  ScannedDeviceModel.genericBluetoothManufacturer =>
    'scan_manufacturer_generic_bt'.tr(),
  _ => manufacturer,
};

/// Short name of how a device was found: "BLE", "Classic BT", "Wi-Fi".
String transportLabel(DeviceTransport transport) => switch (transport) {
  DeviceTransport.ble => 'scan_transport_ble'.tr(),
  DeviceTransport.classic => 'scan_transport_classic'.tr(),
  DeviceTransport.wifi => 'scan_transport_wifi'.tr(),
};

IconData transportIcon(DeviceTransport transport) => switch (transport) {
  DeviceTransport.ble => Icons.bluetooth_searching_rounded,
  DeviceTransport.classic => Icons.bluetooth_rounded,
  DeviceTransport.wifi => Icons.wifi_rounded,
};
