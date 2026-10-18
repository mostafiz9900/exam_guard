import 'package:meta/meta.dart';

import 'package:exam_guard/features/radar/model/proximity_meter.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// How close a target must be before the walk finder alerts. The RSSI
/// thresholds assume a typical phone-class transmitter (≈ -59 dBm at 1 m);
/// bodies, bags and desks shift them, so the distances are approximate.
enum WalkSensitivity {
  close(-60, 1),
  near(-66, 2),
  room(-74, 4);

  const WalkSensitivity(this.thresholdDbm, this.approxMeters);

  /// Smoothed RSSI at or above which a target counts as "very close".
  final int thresholdDbm;
  final int approxMeters;

  static const WalkSensitivity defaultValue = WalkSensitivity.close;

  String get labelKey => 'walk_sensitivity_$name';
}

/// Alerts once when a target enters the zone, and only re-arms after it
/// has been continuously outside for more than [rearmAfter] — no alarm
/// spam while the inspector hovers at the edge of the zone.
class ZoneAlarm {
  static const Duration rearmAfter = Duration(seconds: 5);

  /// Leaving needs the signal [exitHysteresisDb] below the threshold, so
  /// noise around the threshold does not count as leaving.
  static const double exitHysteresisDb = 3.0;

  bool _inside = false;
  bool _armed = true;
  DateTime? _leftAt;

  bool get isInside => _inside;

  /// Feeds one smoothed reading; returns true when an alert must fire now.
  bool update(double rssi, double threshold, DateTime at) {
    if (_inside) {
      if (rssi < threshold - exitHysteresisDb) _leave(at);
      return false;
    }
    _rearmIfDue(at);
    if (rssi < threshold) return false;
    _inside = true;
    if (!_armed) return false;
    _armed = false;
    return true;
  }

  /// The target went silent: count it as outside since [lastHeard].
  void markLost(DateTime lastHeard) {
    if (_inside) _leave(lastHeard);
  }

  void reset() {
    _inside = false;
    _armed = true;
    _leftAt = null;
  }

  void _leave(DateTime at) {
    _inside = false;
    _leftAt = at;
  }

  void _rearmIfDue(DateTime at) {
    final left = _leftAt;
    if (!_armed && left != null && at.difference(left) > rearmAfter) {
      _armed = true;
    }
  }
}

/// Live reading of one walk-finder target.
@immutable
class WalkTarget {
  const WalkTarget({
    required this.device,
    this.smoothedRssi,
    this.lastHeard,
    this.isVeryClose = false,
  });

  /// Not heard for this long: shown as "not heard" instead of a reading.
  static const Duration lostAfter = Duration(seconds: 5);

  final ScannedDeviceModel device;
  final double? smoothedRssi;
  final DateTime? lastHeard;

  /// Inside the alert zone of the current sensitivity.
  final bool isVeryClose;

  int? get closeness {
    final rssi = smoothedRssi;
    return rssi == null ? null : ProximityMeter.closenessPercent(rssi);
  }

  bool isHeard(DateTime now) {
    final last = lastHeard;
    return last != null && now.difference(last) <= lostAfter;
  }

  WalkTarget copyWith({
    double? Function()? smoothedRssi,
    DateTime? Function()? lastHeard,
    bool? isVeryClose,
  }) => WalkTarget(
    device: device,
    smoothedRssi: smoothedRssi != null ? smoothedRssi() : this.smoothedRssi,
    lastHeard: lastHeard != null ? lastHeard() : this.lastHeard,
    isVeryClose: isVeryClose ?? this.isVeryClose,
  );

  @override
  bool operator ==(Object other) =>
      other is WalkTarget &&
      other.device == device &&
      other.smoothedRssi == smoothedRssi &&
      other.lastHeard == lastHeard &&
      other.isVeryClose == isVeryClose;

  @override
  int get hashCode => Object.hash(device, smoothedRssi, lastHeard, isVeryClose);
}
