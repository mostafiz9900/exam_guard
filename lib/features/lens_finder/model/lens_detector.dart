import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exam_guard/core/services/camera_stream/luma_frame.dart';

/// How eagerly the finder reports glints.
enum LensSensitivity {
  /// Only very bright, very sharp points; fewest false alarms.
  low(
    brightThreshold: 235,
    minContrast: 110,
    maxBlobCells: 6,
    confirmFrames: 5,
  ),

  normal(
    brightThreshold: 220,
    minContrast: 90,
    maxBlobCells: 9,
    confirmFrames: 4,
  ),

  /// Dimmer / slightly larger points too; more false alarms.
  high(
    brightThreshold: 200,
    minContrast: 70,
    maxBlobCells: 14,
    confirmFrames: 3,
  );

  const LensSensitivity({
    required this.brightThreshold,
    required this.minContrast,
    required this.maxBlobCells,
    required this.confirmFrames,
  });

  /// Peak luma (0–255) a cell needs to count as "near-saturated".
  final int brightThreshold;

  /// Peak must be at least this much brighter than the ring around it.
  final int minContrast;

  /// Largest blob (in downsampled cells) still treated as a point. Bigger
  /// bright areas are lamps, windows or screens.
  final int maxBlobCells;

  /// Frames a point must be seen (in about the same place) to be confirmed.
  final int confirmFrames;
}

/// A confirmed glint. [x], [y] are 0..1 in the frame's own orientation
/// (see [rotated] for the on-screen position).
class LensCandidate {
  const LensCandidate({
    required this.id,
    required this.x,
    required this.y,
    required this.confidence,
  });

  /// Stable while the same point keeps being tracked.
  final int id;
  final double x;
  final double y;

  /// 0..1: how steady, bright and sharp the point has been.
  final double confidence;

  /// This candidate with its position turned clockwise by [degrees]
  /// (0/90/180/270), i.e. in upright screen coordinates.
  LensCandidate rotated(int degrees) {
    final (rx, ry) = switch (((degrees % 360) + 360) % 360) {
      90 => (1 - y, x),
      180 => (1 - x, 1 - y),
      270 => (y, 1 - x),
      _ => (x, y),
    };
    return LensCandidate(id: id, x: rx, y: ry, confidence: confidence);
  }

  @override
  bool operator ==(Object other) =>
      other is LensCandidate &&
      other.id == id &&
      other.x == x &&
      other.y == y &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(id, x, y, confidence);

  @override
  String toString() =>
      'LensCandidate(#$id, ${x.toStringAsFixed(3)}, '
      '${y.toStringAsFixed(3)}, ${confidence.toStringAsFixed(2)})';
}

/// One small bright spot found in a single frame.
class LensBlob {
  const LensBlob({
    required this.x,
    required this.y,
    required this.cells,
    required this.peak,
    required this.contrast,
  });

  final double x;
  final double y;
  final int cells;
  final int peak;
  final double contrast;
}

class LensDetectionResult {
  const LensDetectionResult({
    required this.candidates,
    required this.blobCount,
    required this.sceneTooBright,
  });

  static const empty = LensDetectionResult(
    candidates: [],
    blobCount: 0,
    sceneTooBright: false,
  );

  /// Confirmed glints, most confident first, at most
  /// [LensDetector.maxCandidates].
  final List<LensCandidate> candidates;

  /// Small bright spots in this frame (confirmed or not).
  final int blobCount;

  /// Too much of the picture is near-saturated to judge points — the user
  /// should dim the lights or point away from lamps/windows.
  final bool sceneTooBright;
}

class _Track {
  _Track(this.id, this.x, this.y, double contrast) : contrastSum = contrast;

  final int id;
  double x;
  double y;
  int seen = 1;
  int age = 1;
  int misses = 0;
  double contrastSum;
  bool confirmed = false;

  double get presence => seen / age;
}

/// Finds lens glints in brightness frames: small, near-saturated points
/// much brighter than their surroundings that stay in the same place over
/// several consecutive frames.
///
/// Pure Dart, no I/O: feed it frames with [process].
class LensDetector {
  LensDetector({LensSensitivity sensitivity = LensSensitivity.normal})
    : _sensitivity = sensitivity;

  /// Frames are reduced to about this many cells across. Each cell keeps
  /// the brightest pixel of its block (so a 1–2 px glint survives) and the
  /// block's mean (for the background).
  static const int targetWidth = 160;

  /// Ring around a blob used as its background, in cells beyond the blob's
  /// bounding box. The first cell is skipped (glow around the glint).
  static const int ringInner = 2;
  static const int ringOuter = 3;

  /// A point this close (in cells) to a large bright area — lamp, window,
  /// screen — is part of that light, not a lens.
  static const int nearLightCells = 5;

  /// A blob whose surrounding ring has more bright cells than this share is
  /// part of a bright area (lamp halo, window), not an isolated point.
  static const double maxBrightRingShare = 0.2;

  /// Above this share of near-saturated cells the scene is too bright.
  static const double tooBrightShare = 0.08;

  /// Per-frame blobs kept (brightest contrast first).
  static const int maxBlobsPerFrame = 12;

  /// Points tracked at once.
  static const int maxTracks = 16;

  /// Confirmed points reported.
  static const int maxCandidates = 6;

  /// A point in the next frame within this distance (0..1 of the frame) is
  /// the same point.
  static const double matchRadius = 0.035;

  /// Share of frames since a point appeared in which it must be seen to be
  /// confirmed. Flickering speculars stay below this.
  static const double minPresence = 0.75;

  /// Consecutive misses tolerated before a point is forgotten.
  static const int pendingMaxMisses = 1;
  static const int confirmedMaxMisses = 3;

  /// Unconfirmed points older than this many confirm-windows are dropped.
  static const int pendingMaxAgeWindows = 3;

  /// Weight of the newest position when smoothing a track.
  static const double positionSmoothing = 0.4;

  LensSensitivity _sensitivity;
  final List<_Track> _tracks = [];
  int _nextId = 1;

  LensSensitivity get sensitivity => _sensitivity;

  set sensitivity(LensSensitivity value) {
    if (value == _sensitivity) return;
    _sensitivity = value;
    reset();
  }

  /// Forgets every tracked point (e.g. after the camera restarts).
  void reset() => _tracks.clear();

  LensDetectionResult process(LumaFrame frame) {
    final scan = _scan(frame);
    _track(scan.blobs);
    return LensDetectionResult(
      candidates: _confirmed(),
      blobCount: scan.blobs.length,
      sceneTooBright: scan.brightShare > tooBrightShare,
    );
  }

  /// Small bright blobs in one frame (no tracking). Public for tests.
  List<LensBlob> findBlobs(LumaFrame frame) => _scan(frame).blobs;

  ({List<LensBlob> blobs, double brightShare}) _scan(LumaFrame frame) {
    final s = _sensitivity;
    if (frame.width <= 0 || frame.height <= 0) {
      return (blobs: const [], brightShare: 0);
    }
    final factor = math.max(1, (frame.width / targetWidth).ceil());
    final gw = frame.width ~/ factor;
    final gh = frame.height ~/ factor;
    if (gw < 3 || gh < 3) return (blobs: const [], brightShare: 0);

    // Max- and mean-pool the frame into gw x gh cells.
    final maxMap = Uint8List(gw * gh);
    final sumMap = Uint32List(gw * gh);
    final luma = frame.luma;
    final usedW = gw * factor;
    final usedH = gh * factor;
    for (var y = 0; y < usedH; y++) {
      final row = y * frame.bytesPerRow;
      final cellRow = (y ~/ factor) * gw;
      for (var x = 0; x < usedW; x++) {
        final v = luma[row + x];
        final c = cellRow + x ~/ factor;
        if (v > maxMap[c]) maxMap[c] = v;
        sumMap[c] += v;
      }
    }
    final area = factor * factor;
    double meanAt(int c) => sumMap[c] / area;

    final threshold = s.brightThreshold;
    var brightCells = 0;
    for (final v in maxMap) {
      if (v >= threshold) brightCells++;
    }

    // 8-connected components of bright cells.
    final visited = Uint8List(gw * gh);
    final queue = Int32List(gw * gh);
    final points = <(LensBlob, int, int, int, int)>[];
    final lights = <(int, int, int, int)>[];
    for (var start = 0; start < maxMap.length; start++) {
      if (visited[start] == 1 || maxMap[start] < threshold) continue;
      var head = 0;
      var tail = 0;
      queue[tail++] = start;
      visited[start] = 1;
      var minX = gw, minY = gh, maxX = 0, maxY = 0;
      var peak = 0;
      double wx = 0, wy = 0, wSum = 0;
      while (head < tail) {
        final c = queue[head++];
        final cx = c % gw;
        final cy = c ~/ gw;
        final v = maxMap[c];
        if (v > peak) peak = v;
        final w = (v - threshold + 1).toDouble();
        wx += (cx + 0.5) * w;
        wy += (cy + 0.5) * w;
        wSum += w;
        if (cx < minX) minX = cx;
        if (cx > maxX) maxX = cx;
        if (cy < minY) minY = cy;
        if (cy > maxY) maxY = cy;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = cy + dy;
          if (ny < 0 || ny >= gh) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = cx + dx;
            if (nx < 0 || nx >= gw) continue;
            final n = ny * gw + nx;
            if (visited[n] == 1 || maxMap[n] < threshold) continue;
            visited[n] = 1;
            queue[tail++] = n;
          }
        }
      }
      final cells = tail;
      // A point is compact: its box can't be a long streak.
      final span = math.max(maxX - minX, maxY - minY) + 1;
      if (cells > s.maxBlobCells || span * span > s.maxBlobCells * 2) {
        lights.add((minX, minY, maxX, maxY));
        continue;
      }

      // Background: mean brightness of a ring around the bounding box.
      double ringSum = 0;
      var ringCount = 0;
      var ringBright = 0;
      for (var y = minY - ringOuter; y <= maxY + ringOuter; y++) {
        if (y < 0 || y >= gh) continue;
        for (var x = minX - ringOuter; x <= maxX + ringOuter; x++) {
          if (x < 0 || x >= gw) continue;
          final d = math.max(
            math.max(minX - x, x - maxX),
            math.max(minY - y, y - maxY),
          );
          if (d < ringInner) continue;
          final c = y * gw + x;
          ringSum += meanAt(c);
          ringCount++;
          if (maxMap[c] >= threshold) ringBright++;
        }
      }
      if (ringCount == 0) continue;
      if (ringBright > ringCount * maxBrightRingShare) continue;
      final contrast = peak - ringSum / ringCount;
      if (contrast < s.minContrast) continue;

      points.add((
        LensBlob(
          x: wx / wSum / gw,
          y: wy / wSum / gh,
          cells: cells,
          peak: peak,
          contrast: contrast,
        ),
        minX,
        minY,
        maxX,
        maxY,
      ));
    }
    // Box-to-box gap in cells (0 when they touch or overlap).
    int gap((int, int, int, int) a, (int, int, int, int) b) => math.max(
      math.max(a.$1 - b.$3, b.$1 - a.$3),
      math.max(a.$2 - b.$4, b.$2 - a.$4),
    );
    final blobs = [
      for (final (blob, x0, y0, x1, y1) in points)
        if (lights.every((l) => gap((x0, y0, x1, y1), l) > nearLightCells))
          blob,
    ]..sort((a, b) => b.contrast.compareTo(a.contrast));
    return (
      blobs: blobs.length > maxBlobsPerFrame
          ? blobs.sublist(0, maxBlobsPerFrame)
          : blobs,
      brightShare: brightCells / maxMap.length,
    );
  }

  void _track(List<LensBlob> blobs) {
    // Greedy nearest matching of blobs to tracks.
    final pairs = <(double, int, int)>[];
    for (var t = 0; t < _tracks.length; t++) {
      for (var b = 0; b < blobs.length; b++) {
        final dx = _tracks[t].x - blobs[b].x;
        final dy = _tracks[t].y - blobs[b].y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d <= matchRadius) pairs.add((d, t, b));
      }
    }
    pairs.sort((a, b) => a.$1.compareTo(b.$1));
    final trackUsed = List<bool>.filled(_tracks.length, false);
    final blobUsed = List<bool>.filled(blobs.length, false);
    for (final (_, t, b) in pairs) {
      if (trackUsed[t] || blobUsed[b]) continue;
      trackUsed[t] = true;
      blobUsed[b] = true;
      final track = _tracks[t];
      final blob = blobs[b];
      track
        ..x += (blob.x - track.x) * positionSmoothing
        ..y += (blob.y - track.y) * positionSmoothing
        ..seen += 1
        ..age += 1
        ..misses = 0
        ..contrastSum += blob.contrast;
    }

    final confirmFrames = _sensitivity.confirmFrames;
    final removed = <_Track>{};
    for (var t = 0; t < _tracks.length; t++) {
      final track = _tracks[t];
      if (!trackUsed[t]) {
        track
          ..age += 1
          ..misses += 1;
        final limit = track.confirmed ? confirmedMaxMisses : pendingMaxMisses;
        if (track.misses > limit) {
          removed.add(track);
          continue;
        }
      }
      if (!track.confirmed) {
        if (track.seen >= confirmFrames && track.presence >= minPresence) {
          track.confirmed = true;
        } else if (track.age >= confirmFrames * pendingMaxAgeWindows) {
          removed.add(track);
        }
      }
    }
    _tracks.removeWhere(removed.contains);

    for (var b = 0; b < blobs.length; b++) {
      if (blobUsed[b] || _tracks.length >= maxTracks) continue;
      _tracks.add(_Track(_nextId++, blobs[b].x, blobs[b].y, blobs[b].contrast));
    }
  }

  List<LensCandidate> _confirmed() {
    final s = _sensitivity;
    final out = [
      for (final t in _tracks)
        if (t.confirmed)
          LensCandidate(
            id: t.id,
            x: t.x.clamp(0.0, 1.0),
            y: t.y.clamp(0.0, 1.0),
            confidence: _confidence(t, s),
          ),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
    return out.length > maxCandidates ? out.sublist(0, maxCandidates) : out;
  }

  static double _confidence(_Track t, LensSensitivity s) {
    final stability = (t.seen / (s.confirmFrames * 2)).clamp(0.0, 1.0);
    final contrast =
        ((t.contrastSum / t.seen - s.minContrast) / (255 - s.minContrast))
            .clamp(0.0, 1.0);
    return (0.4 * stability + 0.3 * contrast + 0.3 * t.presence).clamp(
      0.0,
      1.0,
    );
  }
}
