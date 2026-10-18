import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/wifi/wifi_scan_service_impl.dart';

/// One Wi-Fi access point seen in a scan.
class WifiNetworkRecord {
  const WifiNetworkRecord({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequencyMhz,
    required this.capabilities,
    required this.timestamp,
  });

  /// Network name; empty for hidden networks.
  final String ssid;

  /// Upper-case access point MAC address.
  final String bssid;
  final int rssi;
  final int frequencyMhz;

  /// Security flags as reported by the OS, e.g. "[WPA2-PSK-CCMP][ESS]".
  final String capabilities;
  final DateTime timestamp;
}

/// Why Wi-Fi scanning isn't producing results right now.
enum WifiScanProblem {
  /// iOS doesn't allow apps to scan for Wi-Fi networks.
  unsupported,
  permissionDenied,
  locationOff,
  wifiOff,
}

/// Periodic Wi-Fi access point scans (Android only), used to spot phone
/// hotspots. Android throttles foreground apps to 4 scans per 2 minutes, so
/// results refresh about every 30 s. Shared with owner keys like the BLE
/// scan.
abstract interface class IWifiScanService {
  bool get isSupported;

  /// The full list of access points from each completed scan.
  Stream<List<WifiNetworkRecord>> get results;

  /// Current problem (null when scanning works); emits current then changes.
  Stream<WifiScanProblem?> get problem;

  Future<void> start(String owner);

  Future<void> stop(String owner);

  /// Skips scans while [key] holds a pause (last results stay as they are).
  /// Finder screens use this so Wi-Fi scans don't disturb BLE tracking.
  Future<void> suspend(String key);

  /// Releases [key]'s pause.
  Future<void> resume(String key);

  Future<void> dispose();
}

final wifiScanServiceProvider = Provider<IWifiScanService>((ref) {
  final service = WifiScanServiceImpl(ref.read(appLoggerProvider));
  ref.onDispose(service.dispose);
  return service;
});
