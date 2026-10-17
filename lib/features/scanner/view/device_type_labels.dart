import 'package:exam_guard/core/localization/app_localization.dart';

/// Display names for the scanner's device categories. The model keeps the
/// English `deviceType` strings because they are matched with `contains()`;
/// these helpers translate them only when shown.

/// Full category name, e.g. "Smart Earpiece / Audio".
String deviceTypeLabel(String type) {
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
String manufacturerLabel(String manufacturer) =>
    manufacturer == 'Generic BLE Hardware'
    ? 'scan_manufacturer_generic'.tr()
    : manufacturer;
