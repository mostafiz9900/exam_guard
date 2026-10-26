import 'package:meta/meta.dart';

import 'package:exam_guard/features/session/model/incident_evidence.dart';

enum LogSeverity {
  critical('CRITICAL'),
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW');

  const LogSeverity(this.code);

  /// Stored and displayed value.
  final String code;

  static LogSeverity fromCode(String? code) => LogSeverity.values.firstWhere(
    (s) => s.code == code?.toUpperCase(),
    orElse: () => LogSeverity.low,
  );
}

/// One violation incident recorded by the inspector during a session.
@immutable
class ActionLogModel {
  const ActionLogModel({
    required this.deviceName,
    required this.deviceId,
    required this.category,
    required this.severity,
    required this.location,
    required this.notes,
    required this.createdAt,
    this.seat,
    this.photoPaths = const [],
    this.evidence,
  });

  final String deviceName;
  final String deviceId;
  final String category;
  final LogSeverity severity;
  final String location;
  final String notes;
  final DateTime createdAt;

  /// Seat on the room's seat map, e.g. "C4" (row letter + column number).
  final String? seat;

  /// Evidence photos saved on the device (absolute file paths).
  final List<String> photoPaths;

  /// The device's recorded signal when the incident was logged, if known.
  final IncidentEvidence? evidence;

  // Keys match the map format stored by earlier versions, so existing
  // Hive data still loads.
  Map<String, dynamic> toJson() => {
    'name': deviceName,
    'id': deviceId,
    'type': category,
    'severity': severity.code,
    'location': location,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'seat': seat,
    'photoPaths': photoPaths,
    if (evidence != null) 'evidence': evidence!.toJson(),
  };

  factory ActionLogModel.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    final photos = json['photoPaths'];
    return ActionLogModel(
      deviceName: json['name'] as String? ?? 'Unknown Device',
      deviceId: json['id'] as String? ?? 'N/A',
      category: json['type'] as String? ?? '',
      severity: LogSeverity.fromCode(json['severity'] as String?),
      location: json['location'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.fromMillisecondsSinceEpoch(0),
      seat: json['seat'] as String?,
      photoPaths: [
        if (photos is List)
          for (final p in photos)
            if (p is String) p,
      ],
      evidence: IncidentEvidence.fromJson(json['evidence']),
    );
  }
}
