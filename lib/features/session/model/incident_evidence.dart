import 'package:meta/meta.dart';

/// One signal reading saved with an incident.
@immutable
class EvidencePoint {
  const EvidencePoint(this.at, this.rssi);

  final DateTime at;
  final int rssi;
}

/// A stretch of time the device was in range.
@immutable
class EvidenceSpan {
  const EvidenceSpan(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

/// What the scanner had recorded about the incident's device when it was
/// logged: its signal over the last minutes and how it came and went.
/// Shown as a chart in the report — evidence the device was really there.
@immutable
class IncidentEvidence {
  const IncidentEvidence({
    required this.trace,
    required this.spans,
    required this.firstSeen,
    required this.peakRssi,
    required this.reappearances,
    required this.timePresent,
  });

  /// How far back an incident's trace reaches.
  static const Duration window = Duration(minutes: 10);

  final List<EvidencePoint> trace;
  final List<EvidenceSpan> spans;
  final DateTime firstSeen;
  final int peakRssi;
  final int reappearances;
  final Duration timePresent;

  Map<String, dynamic> toJson() => {
    'trace': [
      for (final p in trace) [p.at.millisecondsSinceEpoch, p.rssi],
    ],
    'spans': [
      for (final s in spans)
        [s.start.millisecondsSinceEpoch, s.end.millisecondsSinceEpoch],
    ],
    'first': firstSeen.millisecondsSinceEpoch,
    'peak': peakRssi,
    'returns': reappearances,
    'presentMs': timePresent.inMilliseconds,
  };

  static IncidentEvidence? fromJson(Object? json) {
    if (json is! Map) return null;
    DateTime? time(Object? v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    final first = time(json['first']);
    if (first == null) return null;
    return IncidentEvidence(
      trace: [
        for (final p in (json['trace'] as List?) ?? const [])
          if (p is List && p.length == 2 && p[0] is num && p[1] is num)
            EvidencePoint(time(p[0])!, (p[1] as num).toInt()),
      ],
      spans: [
        for (final s in (json['spans'] as List?) ?? const [])
          if (s is List && s.length == 2 && s[0] is num && s[1] is num)
            EvidenceSpan(time(s[0])!, time(s[1])!),
      ],
      firstSeen: first,
      peakRssi: (json['peak'] as num?)?.toInt() ?? 0,
      reappearances: (json['returns'] as num?)?.toInt() ?? 0,
      timePresent: Duration(
        milliseconds: (json['presentMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
