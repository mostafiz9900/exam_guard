import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/camera_stream/camera_stream_service_impl.dart';
import 'package:exam_guard/core/services/camera_stream/luma_frame.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

export 'package:exam_guard/core/services/camera_stream/luma_frame.dart';

/// Why the live camera could not start.
enum CameraStreamError {
  /// The user denied (or the OS restricts) camera access.
  permissionDenied,

  /// The device reports no camera.
  noCamera,

  /// Any other camera failure (busy, hardware error).
  failed,
}

class CameraStreamException implements Exception {
  const CameraStreamException(this.error, [this.message = '']);

  final CameraStreamError error;
  final String message;

  @override
  String toString() => 'CameraStreamException(${error.name}): $message';
}

/// Live back-camera frames as brightness only. Features use this instead of
/// the `camera` package.
abstract interface class ICameraStreamService {
  /// Opens the back camera (medium resolution) and starts streaming
  /// [frames]. Frames arriving sooner than [minFrameInterval] after the
  /// previous one are dropped before conversion. Throws
  /// [CameraStreamException].
  Future<void> start({Duration minFrameInterval});

  /// Brightness frames while started (broadcast).
  Stream<LumaFrame> get frames;

  bool get isRunning;

  /// Switches the flashlight. Returns false when the torch is unavailable.
  Future<bool> setTorch(bool on);

  /// Stops the stream, switches the torch off and releases the camera.
  Future<void> stop();

  /// Camera preview size in its native (landscape) orientation, once started.
  Size? get previewSize;

  /// The live preview, or an empty box while not started. Fills the space
  /// it is given; callers size it to [previewSize]'s aspect ratio.
  Widget buildPreview();

  Future<void> dispose();
}

final cameraStreamServiceProvider = Provider<ICameraStreamService>((ref) {
  final service = CameraStreamServiceImpl(ref.read(appLoggerProvider));
  ref.onDispose(service.dispose);
  return service;
});
