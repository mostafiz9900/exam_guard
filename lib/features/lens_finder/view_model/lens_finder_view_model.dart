import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/camera_stream/i_camera_stream_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/lens_finder/model/lens_detector.dart';
import 'package:exam_guard/features/lens_finder/repository/lens_finder_repository.dart';

export 'package:exam_guard/features/lens_finder/model/lens_detector.dart'
    show LensCandidate, LensSensitivity;

enum LensFinderStatus {
  /// Opening the camera.
  starting,

  /// Camera running, frames analysed.
  live,

  /// Camera access denied — not scanning.
  permissionDenied,

  /// The phone has no camera — the finder can't work here.
  noCamera,

  /// The camera failed to start or stopped with an error.
  error,

  /// Stopped by the user or because the app went to the background.
  paused,
}

class LensFinderState {
  const LensFinderState({
    this.status = LensFinderStatus.starting,
    this.candidates = const [],
    this.sensitivity = LensSensitivity.normal,
    this.isTorchOn = true,
    this.isTorchAvailable = true,
    this.isSceneTooBright = false,
    this.previewSize,
  });

  final LensFinderStatus status;

  /// Confirmed glints in upright screen coordinates (0..1 of the preview).
  final List<LensCandidate> candidates;
  final LensSensitivity sensitivity;

  /// The user wants the torch on (it is on while [isLive]).
  final bool isTorchOn;

  /// False once switching the torch failed (no flash on this camera).
  final bool isTorchAvailable;

  /// Too many near-saturated areas to judge points: dim the lights.
  final bool isSceneTooBright;

  /// Camera preview size in its native (landscape) orientation.
  final Size? previewSize;

  /// Only a live camera measures. Every other status is "not scanning",
  /// never "no lens".
  bool get isLive => status == LensFinderStatus.live;

  LensFinderState copyWith({
    LensFinderStatus? status,
    List<LensCandidate>? candidates,
    LensSensitivity? sensitivity,
    bool? isTorchOn,
    bool? isTorchAvailable,
    bool? isSceneTooBright,
    Size? Function()? previewSize,
  }) {
    return LensFinderState(
      status: status ?? this.status,
      candidates: candidates ?? this.candidates,
      sensitivity: sensitivity ?? this.sensitivity,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      isTorchAvailable: isTorchAvailable ?? this.isTorchAvailable,
      isSceneTooBright: isSceneTooBright ?? this.isSceneTooBright,
      previewSize: previewSize != null ? previewSize() : this.previewSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LensFinderState &&
      other.status == status &&
      listEquals(other.candidates, candidates) &&
      other.sensitivity == sensitivity &&
      other.isTorchOn == isTorchOn &&
      other.isTorchAvailable == isTorchAvailable &&
      other.isSceneTooBright == isSceneTooBright &&
      other.previewSize == previewSize;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(candidates),
    sensitivity,
    isTorchOn,
    isTorchAvailable,
    isSceneTooBright,
    previewSize,
  );
}

/// Owns the camera while the lens finder is open: analyses ≤ 8 frames per
/// second, keeps the torch on and vibrates when a new glint is confirmed.
class LensFinderViewModel extends Notifier<LensFinderState> {
  /// At most this often a frame is analysed (≈ 8 fps).
  static const Duration frameInterval = Duration(milliseconds: 125);

  /// Minimum gap between two "new lens" vibrations.
  static const Duration hapticCooldown = Duration(milliseconds: 1500);

  late LensFinderRepository _repository;
  late IHapticService _haptics;
  late AppLogger _logger;
  final LensDetector _detector = LensDetector();

  StreamSubscription<LumaFrame>? _subscription;
  int _generation = 0;
  bool _busy = false;
  Duration? _lastProcessed;
  Duration? _lastHaptic;
  final Set<int> _announced = {};

  /// The camera was running when the app went to the background.
  bool _resumeOnForeground = false;

  @override
  LensFinderState build() {
    _repository = ref.watch(lensFinderRepositoryProvider);
    _haptics = ref.watch(hapticServiceProvider);
    _logger = ref.watch(appLoggerProvider);
    ref.onDispose(() {
      _generation++;
      unawaited(_subscription?.cancel());
      _subscription = null;
      unawaited(_repository.stop());
    });
    Future.microtask(start);
    return const LensFinderState();
  }

  /// Opens the camera (again) and starts analysing frames.
  Future<void> start() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    await _cancelStream();
    _resetTracking();
    state = state.copyWith(
      status: LensFinderStatus.starting,
      candidates: const [],
      isSceneTooBright: false,
    );
    try {
      await _repository.start(minFrameInterval: frameInterval);
    } on CameraStreamException catch (e) {
      _logger.warning('Lens finder camera: ${e.error.name} ${e.message}');
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        status: switch (e.error) {
          CameraStreamError.permissionDenied =>
            LensFinderStatus.permissionDenied,
          CameraStreamError.noCamera => LensFinderStatus.noCamera,
          CameraStreamError.failed => LensFinderStatus.error,
        },
      );
      return;
    } catch (e, st) {
      _logger.error('Lens finder camera failed', e, st);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(status: LensFinderStatus.error);
      return;
    }
    if (!ref.mounted || generation != _generation) {
      // Closed or paused while the camera was opening.
      if (!ref.mounted) unawaited(_repository.stop());
      return;
    }
    _subscription = _repository.frames.listen(
      _onFrame,
      onError: (Object e, StackTrace st) {
        _logger.warning('Lens finder frame stream error', e, st);
      },
    );
    state = state.copyWith(
      status: LensFinderStatus.live,
      previewSize: () => _repository.previewSize,
    );
    if (state.isTorchOn) await _applyTorch(true, generation);
  }

  /// Stops the camera; the screen shows "paused — not scanning".
  Future<void> pause() async {
    _resumeOnForeground = false;
    await _stop();
  }

  /// The app went to the background: release the camera.
  Future<void> onAppBackgrounded() async {
    if (!ref.mounted) return;
    final running =
        state.status == LensFinderStatus.live ||
        state.status == LensFinderStatus.starting;
    if (!running) return;
    _resumeOnForeground = true;
    await _stop();
  }

  /// The app is visible again: restart if the background stopped it.
  Future<void> onAppForegrounded() async {
    if (!ref.mounted || !_resumeOnForeground) return;
    _resumeOnForeground = false;
    await start();
  }

  Future<void> toggleTorch() async {
    if (!ref.mounted) return;
    final on = !state.isTorchOn;
    state = state.copyWith(isTorchOn: on);
    if (state.isLive) await _applyTorch(on, _generation);
  }

  void setSensitivity(LensSensitivity sensitivity) {
    if (!ref.mounted || sensitivity == state.sensitivity) return;
    _detector.sensitivity = sensitivity;
    _announced.clear();
    state = state.copyWith(sensitivity: sensitivity, candidates: const []);
  }

  Future<void> openAppSettings() => _repository.openAppSettings();

  /// The live camera picture (empty while not started).
  Widget buildPreview() => _repository.buildPreview();

  Future<void> _applyTorch(bool on, int generation) async {
    final ok = await _repository.setTorch(on);
    if (!ref.mounted || generation != _generation) return;
    if (on) state = state.copyWith(isTorchAvailable: ok);
  }

  Future<void> _stop() async {
    _generation++;
    await _cancelStream();
    if (!ref.mounted) return;
    state = state.copyWith(
      status: LensFinderStatus.paused,
      candidates: const [],
      isSceneTooBright: false,
    );
    await _repository.stop();
  }

  Future<void> _cancelStream() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
  }

  void _resetTracking() {
    _detector.reset();
    _announced.clear();
    _lastProcessed = null;
    _lastHaptic = null;
  }

  void _onFrame(LumaFrame frame) {
    if (_busy || !ref.mounted || !state.isLive) return;
    final last = _lastProcessed;
    if (last != null && frame.timestamp - last < frameInterval) return;
    _busy = true;
    try {
      _lastProcessed = frame.timestamp;
      final result = _detector.process(frame);
      final candidates = [
        for (final c in result.candidates) c.rotated(frame.rotationDegrees),
      ];
      final fresh = candidates.where((c) => !_announced.contains(c.id));
      if (fresh.isNotEmpty) {
        _announced.addAll(fresh.map((c) => c.id));
        final lastHaptic = _lastHaptic;
        if (lastHaptic == null ||
            frame.timestamp - lastHaptic >= hapticCooldown) {
          _lastHaptic = frame.timestamp;
          unawaited(_haptics.pulse(HapticStrength.heavy));
        }
      }
      state = state.copyWith(
        candidates: candidates,
        isSceneTooBright: result.sceneTooBright,
      );
    } catch (e, st) {
      _logger.warning('Lens frame analysis failed', e, st);
    } finally {
      _busy = false;
    }
  }
}

final lensFinderViewModelProvider =
    NotifierProvider.autoDispose<LensFinderViewModel, LensFinderState>(
      LensFinderViewModel.new,
    );
