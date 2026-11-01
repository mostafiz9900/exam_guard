import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';

/// Whether the first-run introduction was seen, and the permission request
/// it ends with.
class OnboardingRepository {
  OnboardingRepository(this._storage, this._permissions);

  final ILocalStorage _storage;
  final IPermissionService _permissions;

  static const String _doneKey = 'onboarding_done_v1';

  bool get isDone => _storage.read<bool>(_doneKey) ?? false;

  /// Throws [StorageException].
  Future<void> markDone() => _storage.write(_doneKey, true);

  Future<AppPermissionStatus> requestScanPermissions() =>
      _permissions.requestBluetoothScan();

  Future<bool> openSettings() => _permissions.openSettings();
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(
    ref.watch(localStorageProvider),
    ref.watch(permissionServiceProvider),
  ),
);
