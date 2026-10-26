// LensDetector on synthetic brightness frames: steady glints are confirmed,
// flickering ones and big bright areas are not, sensitivity matters.

import 'dart:typed_data';

import 'package:exam_guard/core/services/camera_stream/luma_frame.dart';
import 'package:exam_guard/features/lens_finder/model/lens_detector.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 320;
const _h = 240;

/// Dark frame (with [rowPadding] bytes of padding per row) and optional
/// bright squares: (centerX, centerY, size, value).
LumaFrame _frame({
  int background = 30,
  List<(int, int, int, int)> spots = const [],
  int rowPadding = 0,
  int rotation = 0,
}) {
  final stride = _w + rowPadding;
  final bytes = Uint8List(stride * _h)..fillRange(0, stride * _h, background);
  for (final (cx, cy, size, value) in spots) {
    final half = size ~/ 2;
    for (var y = cy - half; y < cy - half + size; y++) {
      for (var x = cx - half; x < cx - half + size; x++) {
        if (x < 0 || y < 0 || x >= _w || y >= _h) continue;
        bytes[y * stride + x] = value;
      }
    }
  }
  return LumaFrame(
    width: _w,
    height: _h,
    bytesPerRow: stride,
    luma: bytes,
    rotationDegrees: rotation,
  );
}

LensDetectionResult _run(
  LensDetector d,
  int frames,
  LumaFrame Function(int) f,
) {
  var result = LensDetectionResult.empty;
  for (var i = 0; i < frames; i++) {
    result = d.process(f(i));
  }
  return result;
}

void main() {
  group('blob finding', () {
    test('finds a tiny near-saturated point at the right place', () {
      final blobs = LensDetector().findBlobs(_frame(spots: [(80, 60, 3, 255)]));
      expect(blobs, hasLength(1));
      expect(blobs.single.x, closeTo(80 / _w, 0.01));
      expect(blobs.single.y, closeTo(60 / _h, 0.01));
      expect(blobs.single.contrast, greaterThan(200));
    });

    test('ignores row padding', () {
      final blobs = LensDetector().findBlobs(
        _frame(spots: [(200, 100, 3, 255)], rowPadding: 64),
      );
      expect(blobs, hasLength(1));
      expect(blobs.single.x, closeTo(200 / _w, 0.01));
    });

    test('a large bright area (lamp) is not a point', () {
      final d = LensDetector();
      expect(d.findBlobs(_frame(spots: [(160, 120, 60, 255)])), isEmpty);
      final r = _run(d, 10, (_) => _frame(spots: [(160, 120, 60, 255)]));
      expect(r.candidates, isEmpty);
    });

    test('a point inside a bright surface has no contrast', () {
      final blobs = LensDetector().findBlobs(
        _frame(background: 200, spots: [(80, 60, 3, 255)]),
      );
      expect(blobs, isEmpty);
    });

    test('a point right next to a lamp is rejected', () {
      // Glint at y=100; the lamp starts 8 px (4 cells) below it.
      final d = LensDetector();
      expect(d.findBlobs(_frame(spots: [(100, 100, 3, 255)])), hasLength(1));
      final blobs = d.findBlobs(
        _frame(spots: [(100, 100, 3, 255), (100, 120, 24, 250)]),
      );
      expect(blobs, isEmpty);
    });

    test('a very bright scene is flagged', () {
      final r = LensDetector().process(
        _frame(spots: [(80, 60, 80, 255), (240, 180, 80, 255)]),
      );
      expect(r.sceneTooBright, isTrue);
      expect(LensDetector().process(_frame()).sceneTooBright, isFalse);
    });
  });

  group('tracking', () {
    test('a steady glint is confirmed after enough frames', () {
      final d = LensDetector();
      final confirm = LensSensitivity.normal.confirmFrames;
      LumaFrame f(int i) => _frame(spots: [(80 + i % 2, 60, 3, 255)]);

      expect(_run(d, confirm - 1, f).candidates, isEmpty);
      final r = d.process(f(confirm));
      expect(r.candidates, hasLength(1));
      final c = r.candidates.single;
      expect(c.x, closeTo(80 / _w, 0.01));
      expect(c.y, closeTo(60 / _h, 0.01));
      expect(c.confidence, inInclusiveRange(0.0, 1.0));
      expect(c.confidence, greaterThan(0.5));
    });

    test('keeps the same id and survives a single dropout', () {
      final d = LensDetector();
      final first = _run(d, 6, (_) => _frame(spots: [(80, 60, 3, 255)]));
      final id = first.candidates.single.id;
      final gap = d.process(_frame());
      expect(gap.candidates.single.id, id);
      final back = d.process(_frame(spots: [(80, 60, 3, 255)]));
      expect(back.candidates.single.id, id);
    });

    test('a confirmed glint disappears after several missing frames', () {
      final d = LensDetector();
      _run(d, 6, (_) => _frame(spots: [(80, 60, 3, 255)]));
      final r = _run(d, LensDetector.confirmedMaxMisses + 1, (_) => _frame());
      expect(r.candidates, isEmpty);
    });

    test('a flickering glint (every other frame) is never confirmed', () {
      final d = LensDetector();
      final r = _run(
        d,
        40,
        (i) => i.isEven ? _frame(spots: [(80, 60, 3, 255)]) : _frame(),
      );
      expect(r.candidates, isEmpty);
    });

    test('a glint jumping around (random speculars) is never confirmed', () {
      final d = LensDetector();
      const spots = [(40, 40), (250, 60), (120, 200), (290, 210), (60, 150)];
      final r = _run(d, 30, (i) {
        final (x, y) = spots[i % spots.length];
        return _frame(spots: [(x, y, 3, 255)]);
      });
      expect(r.candidates, isEmpty);
    });

    test('candidates are capped', () {
      final d = LensDetector(sensitivity: LensSensitivity.high);
      final spots = [
        for (var y = 30; y < 240; y += 45)
          for (var x = 30; x < 320; x += 45) (x, y, 3, 255),
      ];
      expect(spots.length, greaterThan(LensDetector.maxCandidates));
      final r = _run(d, 8, (_) => _frame(spots: spots));
      expect(r.candidates, hasLength(LensDetector.maxCandidates));
    });
  });

  group('sensitivity', () {
    LumaFrame dim(int _) => _frame(background: 100, spots: [(120, 90, 3, 210)]);

    test('a dimmer glint is only found on high', () {
      final normal = _run(LensDetector(), 10, dim);
      expect(normal.candidates, isEmpty);
      final high = _run(
        LensDetector(sensitivity: LensSensitivity.high),
        10,
        dim,
      );
      expect(high.candidates, hasLength(1));
    });

    test('low needs more frames than high', () {
      LumaFrame f(int _) => _frame(spots: [(80, 60, 3, 255)]);
      final high = LensDetector(sensitivity: LensSensitivity.high);
      final low = LensDetector(sensitivity: LensSensitivity.low);
      final n = LensSensitivity.high.confirmFrames;
      expect(_run(high, n, f).candidates, hasLength(1));
      expect(_run(low, n, f).candidates, isEmpty);
    });

    test('a medium-size reflection passes high but not low', () {
      // 5x5 px at factor 2 covers 9 cells: a point on high, too big on low.
      LumaFrame f(int _) => _frame(spots: [(81, 61, 5, 255)]);
      final lowBlobs = LensDetector(sensitivity: LensSensitivity.low)
          .findBlobs(f(0));
      final highBlobs = LensDetector(sensitivity: LensSensitivity.high)
          .findBlobs(f(0));
      expect(lowBlobs, isEmpty);
      expect(highBlobs, hasLength(1));
    });

    test('changing sensitivity forgets tracked points', () {
      final d = LensDetector();
      _run(d, 6, (_) => _frame(spots: [(80, 60, 3, 255)]));
      d.sensitivity = LensSensitivity.high;
      expect(d.process(_frame()).candidates, isEmpty);
    });
  });

  group('LensCandidate.rotated', () {
    const c = LensCandidate(id: 1, x: 0.2, y: 0.1, confidence: 1);

    test('turns clockwise', () {
      final r90 = c.rotated(90);
      expect(r90.x, closeTo(0.9, 1e-9));
      expect(r90.y, closeTo(0.2, 1e-9));
      final r180 = c.rotated(180);
      expect(r180.x, closeTo(0.8, 1e-9));
      expect(r180.y, closeTo(0.9, 1e-9));
      final r270 = c.rotated(270);
      expect(r270.x, closeTo(0.1, 1e-9));
      expect(r270.y, closeTo(0.8, 1e-9));
      expect(c.rotated(0), c);
    });
  });
}
