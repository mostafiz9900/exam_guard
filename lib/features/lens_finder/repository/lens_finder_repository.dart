import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/camera_stream/i_camera_stream_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';

/// Camera access for the lens finder.
class LensFinderRepository {
  LensFinderRepository(this._camera, this._permissions);

  final ICameraStreamService _camera;
  final IPermissionService _permissions;

  /// Throws [CameraStreamException].
  Future<void> start({required Duration minFrameInterval}) =>
      _camera.start(minFrameInterval: minFrameInterval);

  Stream<LumaFrame> get frames => _camera.frames;

  Future<bool> setTorch(bool on) => _camera.setTorch(on);

  Future<void> stop() => _camera.stop();

  Size? get previewSize => _camera.previewSize;

  Widget buildPreview() => _camera.buildPreview();

  Future<bool> openAppSettings() => _permissions.openSettings();
}

final lensFinderRepositoryProvider = Provider<LensFinderRepository>(
  (ref) => LensFinderRepository(
    ref.watch(cameraStreamServiceProvider),
    ref.watch(permissionServiceProvider),
  ),
);
