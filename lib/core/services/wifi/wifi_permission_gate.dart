import 'package:permission_handler/permission_handler.dart';

/// Requests the runtime permission Wi-Fi scan results need. Kept inside the
/// Wi-Fi service (instead of `IPermissionService`) so the scan can ask for
/// it on start and report a denial through `IWifiScanService.problem`.
class WifiPermissionGate {
  const WifiPermissionGate();

  /// Android 13+ (API 33): NEARBY_WIFI_DEVICES; older: fine location.
  /// Returns whether the permission is granted afterwards.
  Future<bool> request(int sdkInt) async {
    final permission = sdkInt >= 33
        ? Permission.nearbyWifiDevices
        : Permission.locationWhenInUse;
    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }
}
