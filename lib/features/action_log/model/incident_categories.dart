import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Stored incident categories. The values are English and saved with every
/// incident (and printed in the PDF), so they must never change.
abstract final class IncidentCategory {
  static const bluetooth = 'Bluetooth Device';
  static const classicEarpiece = 'Classic Bluetooth Earpiece';
  static const wifiHotspot = 'Wi-Fi Hotspot';
  static const magnetic = 'Magnetic Anomaly';
  static const rf = 'RF Transmitter';
  static const simCall = 'Active Cellular SIM Call';
  static const voipCall = 'Online VoIP Call';
  static const mobileData = 'Mobile 4G/5G Data Usage';
  static const suspicious = 'Suspicious Activity';

  /// Offered in the form: stored value → label translation key.
  static const labelKeys = <String, String>{
    bluetooth: 'incident_cat_bluetooth',
    classicEarpiece: 'incident_cat_classic_earpiece',
    wifiHotspot: 'incident_cat_wifi_hotspot',
    magnetic: 'incident_cat_magnetic',
    rf: 'incident_cat_rf',
    simCall: 'incident_cat_sim_call',
    voipCall: 'incident_cat_voip_call',
    mobileData: 'incident_cat_mobile_data',
    suspicious: 'incident_cat_suspicious',
  };

  /// Sensible default category for a device picked in a scanner.
  static String forDevice(ScannedDeviceModel device) {
    final type = device.deviceType;
    final isHotspot = type.contains('Hotspot') || type.contains('Wi-Fi');
    switch (device.transport) {
      case DeviceTransport.wifi:
        return wifiHotspot;
      case DeviceTransport.classic:
        final isAudio =
            type.contains('Audio') ||
            type.contains('Earpiece') ||
            type.contains('Headset');
        return isAudio ? classicEarpiece : bluetooth;
      case DeviceTransport.ble:
        return isHotspot ? wifiHotspot : bluetooth;
    }
  }

  /// Category the form starts with: an explicit one from the caller wins,
  /// then the device's default, then [bluetooth].
  static String initial({String? category, ScannedDeviceModel? device}) {
    final explicit = category?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    if (device != null) return forDevice(device);
    return bluetooth;
  }
}
