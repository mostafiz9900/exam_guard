import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/wireless_classifier.dart';

/// Raises new-device alerts for what ESP32 nodes hear, with the same rules
/// as the phone scanner: only after the room baseline, only untrusted
/// devices first heard after it, strong enough to be in the room, and BLE
/// heard over at least 3 s. A device that only changed its random address
/// (phones and earbuds do every few minutes) is not "new".
class NodeAlertTracker {
  NodeAlertTracker();

  static const int alertRssi = -75;
  static const int hotspotAlertRssi = -80;
  static const Duration confirmSpan = Duration(seconds: 3);

  /// An address silent at least this long may reappear as a new one.
  static const Duration rotationGap = Duration(seconds: 5);

  /// Older entries are forgotten (and can't be matched as rotations).
  static const Duration forgetAfter = Duration(minutes: 15);

  static const String _nodePrefix = 'examguard';

  final Map<String, Map<String, _Track>> _nodes = {};

  void reset() => _nodes.clear();

  /// Forgets one node (it left the hall).
  void forgetNode(String nodeId) => _nodes.remove(nodeId);

  /// Feeds one batch from [nodeId]; returns the alerts it raises.
  List<NewDeviceAlert> onSightings({
    required String nodeId,
    required List<ScannedDeviceModel> devices,
    required DateTime now,
    required DateTime? baselineAt,
    required bool Function(String deviceId) isTrusted,
  }) {
    final tracks = _nodes.putIfAbsent(nodeId, () => {});
    tracks.removeWhere((_, t) => now.difference(t.lastSeen) > forgetAfter);

    final alerts = <NewDeviceAlert>[];
    for (final d in devices) {
      var t = tracks[d.id];
      if (t == null) {
        final rotated = _rotatedFrom(tracks, d, now);
        t = _Track(
          device: d,
          firstSeen: now,
          lastSeen: now,
          // Before a baseline everything heard is part of the room.
          known: baselineAt == null || (rotated?.known ?? false),
          alerted: rotated?.alerted ?? false,
        );
        tracks[d.id] = t;
      } else {
        t
          ..device = d
          ..lastSeen = now;
      }
      if (baselineAt == null) {
        t.known = true;
        continue;
      }
      if (!t.firstSeen.isAfter(baselineAt)) t.known = true;
      if (t.known || t.alerted || isTrusted(d.id)) continue;
      if (d.name.trim().toLowerCase().startsWith(_nodePrefix)) continue;
      if (!_strongEnough(d)) continue;
      if (d.isBle && t.lastSeen.difference(t.firstSeen) < confirmSpan) {
        continue;
      }
      t.alerted = true;
      alerts.add(
        NewDeviceAlert(
          deviceId: d.id,
          displayName: d.displayName,
          deviceType: d.deviceType,
          transport: d.transport,
          rssi: d.rssi,
          detectedAt: now,
        ),
      );
    }
    return alerts;
  }

  static bool _strongEnough(ScannedDeviceModel d) => switch (d.transport) {
    DeviceTransport.wifi =>
      d.deviceType == WirelessClassifier.hotspotType &&
          d.rssi >= hotspotAlertRssi,
    _ => d.rssi >= alertRssi,
  };

  /// The silent entry [seen] most likely is, after an address change.
  static _Track? _rotatedFrom(
    Map<String, _Track> tracks,
    ScannedDeviceModel seen,
    DateTime now,
  ) {
    if (!seen.isBle) return null;
    _Track? match;
    for (final t in tracks.values) {
      final d = t.device;
      if (!d.isBle || now.difference(t.lastSeen) < rotationGap) continue;
      final same = seen.hasName || d.hasName
          ? seen.name.trim() == d.name.trim()
          : seen.manufacturer == d.manufacturer &&
                seen.manufacturer != 'Generic BLE Hardware' &&
                seen.deviceType == d.deviceType &&
                _sameServices(seen.serviceUuids, d.serviceUuids);
      if (same && (match == null || t.lastSeen.isAfter(match.lastSeen))) {
        match = t;
      }
    }
    return match;
  }

  static bool _sameServices(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}

class _Track {
  _Track({
    required this.device,
    required this.firstSeen,
    required this.lastSeen,
    required this.known,
    required this.alerted,
  });

  ScannedDeviceModel device;
  final DateTime firstSeen;
  DateTime lastSeen;

  /// Part of the room (heard before the baseline, or a rotation of such).
  bool known;
  bool alerted;
}
