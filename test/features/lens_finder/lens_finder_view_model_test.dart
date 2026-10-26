// Lens finder view model with a fake camera: confirmation, haptics,
// throttling, not-scanning states, pause/background and disposal.

import 'dart:async';
import 'dart:typed_data';

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/camera_stream/i_camera_stream_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/lens_finder/view_model/lens_finder_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _w = 320;
const _h = 240;

class FakeCamera implements ICameraStreamService {
  CameraStreamError? failWith;
  bool torchWorks = true;
  final frameController = StreamController<LumaFrame>.broadcast();
  int starts = 0;
  int stops = 0;
  final torch = <bool>[];
  bool _running = false;

  @override
  Future<void> start({Duration minFrameInterval = Duration.zero}) async {
    starts++;
    if (failWith case final e?) throw CameraStreamException(e);
    _running = true;
  }

  @override
  Stream<LumaFrame> get frames => frameController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> setTorch(bool on) async {
    torch.add(on);
    return torchWorks;
  }

  @override
  Future<void> stop() async {
    stops++;
    _running = false;
  }

  @override
  Size? get previewSize => const Size(640, 480);

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<void> dispose() async {}
}

class _Haptics implements IHapticService {
  int pulses = 0;

  @override
  Future<void> pulse(HapticStrength strength) async => pulses++;

  @override
  Future<void> alertPattern() async {}
}

class _Permissions implements IPermissionService {
  int settings = 0;

  @override
  Future<AppPermissionStatus> requestBluetoothScan() async =>
      AppPermissionStatus.granted;

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async => true;
}

/// A dark frame with one small bright glint at (x, y).
LumaFrame glintFrame(int ms, {int x = 160, int y = 120}) {
  final bytes = Uint8List(_w * _h)..fillRange(0, _w * _h, 25);
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      bytes[(y + dy) * _w + x + dx] = 255;
    }
  }
  return LumaFrame(
    width: _w,
    height: _h,
    bytesPerRow: _w,
    luma: bytes,
    timestamp: Duration(milliseconds: ms),
  );
}

void main() {
  late FakeCamera camera;
  late _Haptics haptics;
  late _Permissions permissions;
  late ProviderContainer container;

  LensFinderState read() => container.read(lensFinderViewModelProvider);
  LensFinderViewModel vm() =>
      container.read(lensFinderViewModelProvider.notifier);

  Future<void> boot() async {
    container.listen(lensFinderViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  Future<void> feed(Iterable<LumaFrame> frames) async {
    for (final f in frames) {
      camera.frameController.add(f);
      await pumpEventQueue();
    }
  }

  setUp(() {
    camera = FakeCamera();
    haptics = _Haptics();
    permissions = _Permissions();
    container = ProviderContainer(
      overrides: [
        cameraStreamServiceProvider.overrideWithValue(camera),
        hapticServiceProvider.overrideWithValue(haptics),
        permissionServiceProvider.overrideWithValue(permissions),
      ],
    );
    addTearDown(container.dispose);
  });

  test('starts live with the torch on', () async {
    await boot();
    expect(read().status, LensFinderStatus.live);
    expect(camera.torch, [true]);
    expect(read().candidates, isEmpty);
  });

  test('a steady glint is confirmed and vibrates once', () async {
    await boot();
    await feed([for (var i = 0; i < 12; i++) glintFrame(i * 200)]);
    expect(read().candidates, hasLength(1));
    final c = read().candidates.single;
    expect(c.x, closeTo(0.5, 0.02));
    expect(c.y, closeTo(0.5, 0.02));
    expect(haptics.pulses, 1);
  });

  test('frames faster than the analysis rate are skipped', () async {
    await boot();
    // 40 ms apart: only about every 4th frame is analysed, so 8 frames are
    // not enough to confirm.
    await feed([for (var i = 0; i < 8; i++) glintFrame(i * 40)]);
    expect(read().candidates, isEmpty);
  });

  test(
    'camera refused or missing is "not scanning", never "no lens"',
    () async {
      camera.failWith = CameraStreamError.permissionDenied;
      await boot();
      expect(read().status, LensFinderStatus.permissionDenied);
      expect(read().isLive, isFalse);
      await vm().openAppSettings();
      expect(permissions.settings, 1);

      camera.failWith = CameraStreamError.noCamera;
      await vm().start();
      expect(read().status, LensFinderStatus.noCamera);
    },
  );

  test('pause and background release the camera; foreground resumes', () async {
    await boot();
    await vm().pause();
    expect(read().status, LensFinderStatus.paused);
    expect(camera.stops, 1);

    await vm().start();
    await vm().onAppBackgrounded();
    expect(camera.stops, 2);
    await vm().onAppForegrounded();
    expect(read().status, LensFinderStatus.live);
    expect(camera.starts, 3);
  });

  test('closing the screen stops the camera', () async {
    await boot();
    container.dispose();
    await pumpEventQueue();
    expect(camera.stops, greaterThanOrEqualTo(1));
  });

  test('torch toggle and a missing torch', () async {
    camera.torchWorks = false;
    await boot();
    expect(read().isTorchAvailable, isFalse);
    await vm().toggleTorch();
    expect(read().isTorchOn, isFalse);
    expect(camera.torch.last, isFalse);
  });

  test('changing sensitivity starts confirmation over', () async {
    await boot();
    await feed([for (var i = 0; i < 12; i++) glintFrame(i * 200)]);
    expect(read().candidates, isNotEmpty);
    vm().setSensitivity(LensSensitivity.high);
    expect(read().sensitivity, LensSensitivity.high);
    expect(read().candidates, isEmpty);
  });
}
