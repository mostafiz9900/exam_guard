import 'package:meta/meta.dart';

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
  });

  final String deviceName;
  final String deviceId;
  final String category;
  final LogSeverity severity;
  final String location;
  final String notes;
  final DateTime createdAt;

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
  };

  factory ActionLogModel.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
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
    );
  }
}
