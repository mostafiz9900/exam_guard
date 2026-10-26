import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:exam_guard/core/services/camera_stream/i_camera_stream_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// [ICameraStreamService] on the `camera` plugin.
///
/// Android streams YUV420 and the Y plane is passed through untouched; iOS
/// streams BGRA (full-range RGB) and is converted to luma here. Start/stop
/// calls run one at a time so a quick close never disposes a camera that
/// is still initialising.
class CameraStreamServiceImpl implements ICameraStreamService {
  CameraStreamServiceImpl(this._logger);

  final AppLogger _logger;
  final StreamController<LumaFrame> _frames =
      StreamController<LumaFrame>.broadcast();
  final Stopwatch _clock = Stopwatch();

  CameraController? _controller;
  Future<void> _queue = Future<void>.value();
  Duration _minFrameInterval = Duration.zero;
  Duration? _lastFrameAt;
  bool _disposed = false;

  /// Camera error codes that mean "no permission" (Android and iOS).
  static const Set<String> _permissionCodes = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
    'cameraPermission',
    'CameraPermissionsRequestInProgress',
  };

  @override
  Stream<LumaFrame> get frames => _frames.stream;

  @override
  bool get isRunning => _controller?.value.isStreamingImages ?? false;

  @override
  Size? get previewSize => _controller?.value.previewSize;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<void> start({Duration minFrameInterval = Duration.zero}) => _serial(
    () async {
      if (_disposed) {
        throw const CameraStreamException(CameraStreamError.failed, 'disposed');
      }
      await _release();
      _minFrameInterval = minFrameInterval;
      _lastFrameAt = null;

      final List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
      } on CameraException catch (e, st) {
        _logger.warning('Listing cameras failed: ${e.code}', e, st);
        throw _map(e);
      }
      if (cameras.isEmpty) {
        throw const CameraStreamException(CameraStreamError.noCamera);
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _controller = controller;
      try {
        await controller.initialize();
        await controller.setFlashMode(FlashMode.off);
        _clock
          ..reset()
          ..start();
        await controller.startImageStream(
          (image) => _onImage(image, description, controller),
        );
      } on CameraException catch (e, st) {
        _logger.warning('Camera start failed: ${e.code}', e, st);
        await _release();
        throw _map(e);
      } on PlatformException catch (e, st) {
        _logger.warning('Camera start failed: ${e.code}', e, st);
        await _release();
        throw CameraStreamException(CameraStreamError.failed, e.code);
      }
    },
  );

  CameraStreamException _map(CameraException e) {
    if (_permissionCodes.contains(e.code)) {
      return CameraStreamException(CameraStreamError.permissionDenied, e.code);
    }
    return CameraStreamException(
      CameraStreamError.failed,
      '${e.code}: ${e.description}',
    );
  }

  void _onImage(
    CameraImage image,
    CameraDescription description,
    CameraController controller,
  ) {
    if (!_frames.hasListener || image.planes.isEmpty) return;
    final now = _clock.elapsed;
    final last = _lastFrameAt;
    if (last != null && now - last < _minFrameInterval) return;
    _lastFrameAt = now;

    try {
      final LumaFrame frame;
      final plane = image.planes.first;
      if (image.format.group == ImageFormatGroup.bgra8888) {
        frame = LumaFrame(
          width: image.width,
          height: image.height,
          bytesPerRow: image.width,
          luma: bgraToLuma(
            plane.bytes,
            image.width,
            image.height,
            plane.bytesPerRow,
          ),
          // iOS rotates the video connection to the device orientation.
          rotationDegrees: 0,
          timestamp: now,
        );
      } else {
        frame = LumaFrame(
          width: image.width,
          height: image.height,
          bytesPerRow: plane.bytesPerRow,
          luma: plane.bytes,
          rotationDegrees: androidRotation(
            description.sensorOrientation,
            controller.value.deviceOrientation,
          ),
          timestamp: now,
        );
      }
      _frames.add(frame);
    } catch (e, st) {
      _logger.warning('Dropped a camera frame', e, st);
    }
  }

  /// Clockwise turn that makes a back-camera buffer upright on screen.
  @visibleForTesting
  static int androidRotation(int sensorOrientation, DeviceOrientation device) {
    final deviceDegrees = switch (device) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return (sensorOrientation - deviceDegrees + 360) % 360;
  }

  /// BT.601 luma from BGRA bytes.
  @visibleForTesting
  static Uint8List bgraToLuma(
    Uint8List bgra,
    int width,
    int height,
    int bytesPerRow,
  ) {
    final out = Uint8List(width * height);
    var o = 0;
    for (var y = 0; y < height; y++) {
      var i = y * bytesPerRow;
      for (var x = 0; x < width; x++, i += 4) {
        out[o++] = (29 * bgra[i] + 150 * bgra[i + 1] + 77 * bgra[i + 2]) >> 8;
      }
    }
    return out;
  }

  @override
  Future<bool> setTorch(bool on) => _serial(() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return false;
    try {
      await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      return true;
    } on CameraException catch (e, st) {
      _logger.warning('Torch unavailable: ${e.code}', e, st);
      return false;
    }
  });

  @override
  Future<void> stop() => _serial(_release);

  Future<void> _release() async {
    final controller = _controller;
    _controller = null;
    _clock.stop();
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      if (controller.value.isInitialized) {
        await controller.setFlashMode(FlashMode.off);
      }
    } on CameraException catch (e, st) {
      _logger.warning('Stopping camera stream failed: ${e.code}', e, st);
    }
    try {
      await controller.dispose();
    } on CameraException catch (e, st) {
      _logger.warning('Disposing camera failed: ${e.code}', e, st);
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return CameraPreview(controller);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _serial(_release);
    await _frames.close();
  }
}
