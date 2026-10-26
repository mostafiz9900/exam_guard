import 'package:meta/meta.dart';

/// How busy the hall was at one moment: devices in range (untrusted ones
/// separately) and alerts so far. Recorded about once a minute.
@immutable
class ActivitySample {
  const ActivitySample({
    required this.at,
    required this.devices,
    required this.untrusted,
    required this.alerts,
  });

  final DateTime at;
  final int devices;
  final int untrusted;
  final int alerts;

  List<int> toJson() => [at.millisecondsSinceEpoch, devices, untrusted, alerts];

  static ActivitySample? fromJson(Object? json) {
    if (json is! List || json.length < 4) return null;
    final v = [for (final x in json.take(4)) x is num ? x.toInt() : null];
    if (v.contains(null)) return null;
    return ActivitySample(
      at: DateTime.fromMillisecondsSinceEpoch(v[0]!),
      devices: v[1]!,
      untrusted: v[2]!,
      alerts: v[3]!,
    );
  }
}
