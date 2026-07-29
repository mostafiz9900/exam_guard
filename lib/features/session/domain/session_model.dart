// Domain model representing an exam session.
// This model is deliberately storage-agnostic: it provides `toJson`/`fromJson`
// helpers so infrastructure code can persist it using Hive, SQLite, or plain
// JSON storage without requiring generated Hive adapters.

import 'package:meta/meta.dart';

@immutable
class SessionModel {
  final String id;
  final String instituteName;
  final String teacherName;
  final String roomNumber;
  final DateTime startTime;
  final DateTime? endTime;
  // Device logs are stored as generic maps here so the domain remains decoupled
  // from the concrete ActionLog/DeviceLog implementations. Replace with
  // `List<DeviceLogModel>` once that model is available.
  final List<Map<String, dynamic>> deviceLogs;

  const SessionModel({
    required this.id,
    required this.instituteName,
    required this.teacherName,
    required this.roomNumber,
    required this.startTime,
    this.endTime,
    this.deviceLogs = const [],
  });

  SessionModel copyWith({
    String? id,
    String? instituteName,
    String? teacherName,
    String? roomNumber,
    DateTime? startTime,
    DateTime? endTime,
    List<Map<String, dynamic>>? deviceLogs,
  }) {
    return SessionModel(
      id: id ?? this.id,
      instituteName: instituteName ?? this.instituteName,
      teacherName: teacherName ?? this.teacherName,
      roomNumber: roomNumber ?? this.roomNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      deviceLogs: deviceLogs ?? this.deviceLogs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'instituteName': instituteName,
    'teacherName': teacherName,
    'roomNumber': roomNumber,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime?.millisecondsSinceEpoch,
    'deviceLogs': deviceLogs,
  };

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final start = json['startTime'] as int?;
    final end = json['endTime'] as int?;

    final rawLogs = json['deviceLogs'];
    final logs = <Map<String, dynamic>>[];
    if (rawLogs is List) {
      for (final e in rawLogs) {
        if (e is Map) logs.add(Map<String, dynamic>.from(e));
      }
    }

    return SessionModel(
      id: json['id'] as String,
      instituteName: json['instituteName'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(start ?? 0),
      endTime: end != null ? DateTime.fromMillisecondsSinceEpoch(end) : null,
      deviceLogs: logs,
    );
  }

  @override
  String toString() {
    return 'SessionModel(id: $id, institute: $instituteName, teacher: $teacherName, room: $roomNumber, start: $startTime, end: $endTime, logs: ${deviceLogs.length})';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SessionModel &&
            other.id == id &&
            other.instituteName == instituteName &&
            other.teacherName == teacherName &&
            other.roomNumber == roomNumber &&
            other.startTime == startTime &&
            other.endTime == endTime &&
            other.deviceLogs.length == deviceLogs.length);
  }

  @override
  int get hashCode => Object.hash(
    id,
    instituteName,
    teacherName,
    roomNumber,
    startTime,
    endTime,
    deviceLogs.length,
  );
}
