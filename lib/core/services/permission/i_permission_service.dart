import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/permission/permission_service_impl.dart';

enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// Runtime permission access. Features use this instead of `permission_handler`.
abstract interface class IPermissionService {
  /// Requests everything a BLE scan needs (scan, connect, location).
  Future<AppPermissionStatus> requestBluetoothScan();

  /// Opens the OS settings page for this app.
  Future<bool> openSettings();

  /// Opens the system Location settings (Android). Returns false where that
  /// isn't possible.
  Future<bool> openLocationSettings();
}

final permissionServiceProvider = Provider<IPermissionService>(
  (ref) => PermissionServiceImpl(),
);
