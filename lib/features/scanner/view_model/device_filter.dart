import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// "Near me" threshold (dBm), about 2 m for a typical phone or earbud.
const int nearMeRssi = -62;

/// Category filters for the scanner list. A grouped device is matched on
/// its primary member. The scanner publishes smoothed RSSI, so signal
/// filters don't flicker.
enum DeviceFilter {
  all,

  /// Smoothed signal ≥ [nearMeRssi]: roughly within 2 m of the phone.
  nearMe,
  connected,
  strongSignal,
  audioDevices,
  wifiHotspots,
  wearables,
  covertEsp,
  smartphones;

  /// Translation key of the filter chip label.
  String get labelKey => switch (this) {
    DeviceFilter.all => 'scan_filter_all',
    DeviceFilter.nearMe => 'scan_filter_near_me',
    DeviceFilter.connected => 'scan_filter_connected',
    DeviceFilter.strongSignal => 'scan_filter_strong',
    DeviceFilter.audioDevices => 'scan_filter_audio',
    DeviceFilter.wifiHotspots => 'scan_filter_hotspots',
    DeviceFilter.wearables => 'scan_filter_wearables',
    DeviceFilter.covertEsp => 'scan_filter_esp32',
    DeviceFilter.smartphones => 'scan_filter_smartphones',
  };

  bool matches(ScannedDeviceModel device) {
    final name = device.name.toLowerCase();
    bool nameHas(List<String> words) => words.any(name.contains);
    return switch (this) {
      DeviceFilter.all => true,
      DeviceFilter.nearMe => device.rssi >= nearMeRssi,
      DeviceFilter.connected => device.isConnected,
      DeviceFilter.strongSignal => device.rssi > -65,
      DeviceFilter.audioDevices =>
        device.deviceType.contains('Audio') ||
            nameHas(const ['headset', 'airpod', 'buds', 'tws']),
      DeviceFilter.wifiHotspots =>
        device.deviceType.contains('Hotspot') ||
            nameHas(const ['hotspot', 'tether', 'direct-']),
      DeviceFilter.wearables =>
        device.deviceType.contains('Wearable') ||
            nameHas(const ['watch', 'band']),
      DeviceFilter.covertEsp =>
        device.deviceType.contains('ESP32') ||
            device.manufacturer.contains('Espressif') ||
            name.contains('esp32'),
      DeviceFilter.smartphones =>
        device.deviceType.contains('Smartphone') ||
            nameHas(const ['iphone', 'galaxy', 'pixel', 'phone']),
    };
  }
}
