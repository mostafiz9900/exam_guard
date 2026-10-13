import 'package:permission_handler/permission_handler.dart';

import 'i_permission_service.dart';

class PermissionServiceImpl implements IPermissionService {
  @override
  Future<AppPermissionStatus> requestBluetoothScan() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // permission_handler 13: a permanent denial is only reliable from the
    // result of request(), not from a later `status` read.
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return AppPermissionStatus.permanentlyDenied;
    }
    final scan = statuses[Permission.bluetoothScan];
    final location = statuses[Permission.locationWhenInUse];
    final scanOk = scan == null || scan.isGranted || scan.isLimited;
    final locationOk =
        location == null || location.isGranted || location.isLimited;
    return scanOk && locationOk
        ? AppPermissionStatus.granted
        : AppPermissionStatus.denied;
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
