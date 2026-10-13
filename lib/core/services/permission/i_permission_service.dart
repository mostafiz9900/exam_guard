import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'permission_service_impl.dart';

enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// Runtime permission access. Features use this instead of `permission_handler`.
abstract interface class IPermissionService {
  /// Requests everything a BLE scan needs (scan, connect, location).
  Future<AppPermissionStatus> requestBluetoothScan();

  /// Opens the OS settings page for this app.
  Future<bool> openSettings();
}

final permissionServiceProvider = Provider<IPermissionService>(
  (ref) => PermissionServiceImpl(),
);
