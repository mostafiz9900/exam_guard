// An exam session. Storage-agnostic: `toJson`/`fromJson` let any storage
// persist it without generated adapters.

import 'package:meta/meta.dart';

import 'package:exam_guard/features/session/model/action_log_model.dart';

@immutable
class SessionModel {
  final String id;
  final String instituteName;
  final String teacherName;
  final String roomNumber;
  final DateTime startTime;
  final DateTime? endTime;
  final List<ActionLogModel> deviceLogs;

  /// Device ids (BLE/classic address, Wi-Fi BSSID) marked as belonging to
  /// the room or the invigilator, so they never raise "new device" alerts.
  final Set<String> trustedDeviceIds;

  /// When the empty-room baseline scan was taken, if it was.
  final DateTime? baselineAt;

  /// Optional seat layout of the room (rows × columns) for the seat map.
  final int? seatRows;
  final int? seatCols;

  bool get hasBaseline => baselineAt != null;
  bool get hasSeatLayout => (seatRows ?? 0) > 0 && (seatCols ?? 0) > 0;

  /// True while the exam is running.
  bool get isActive => endTime == null;

  /// Exam length so far (until now while it is still running).
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  const SessionModel({
    required this.id,
    required this.instituteName,
    required this.teacherName,
    required this.roomNumber,
    required this.startTime,
    this.endTime,
    this.deviceLogs = const [],
    this.trustedDeviceIds = const {},
    this.baselineAt,
    this.seatRows,
    this.seatCols,
  });

  SessionModel copyWith({
    String? id,
    String? instituteName,
    String? teacherName,
    String? roomNumber,
    DateTime? startTime,
    DateTime? endTime,
    List<ActionLogModel>? deviceLogs,
    Set<String>? trustedDeviceIds,
    DateTime? baselineAt,
    int? seatRows,
    int? seatCols,
  }) {
    return SessionModel(
      id: id ?? this.id,
      instituteName: instituteName ?? this.instituteName,
      teacherName: teacherName ?? this.teacherName,
      roomNumber: roomNumber ?? this.roomNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      deviceLogs: deviceLogs ?? this.deviceLogs,
      trustedDeviceIds: trustedDeviceIds ?? this.trustedDeviceIds,
      baselineAt: baselineAt ?? this.baselineAt,
      seatRows: seatRows ?? this.seatRows,
      seatCols: seatCols ?? this.seatCols,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'instituteName': instituteName,
    'teacherName': teacherName,
    'roomNumber': roomNumber,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime?.millisecondsSinceEpoch,
    'deviceLogs': [for (final log in deviceLogs) log.toJson()],
    'trustedDeviceIds': trustedDeviceIds.toList(),
    'baselineAt': baselineAt?.millisecondsSinceEpoch,
    'seatRows': seatRows,
    'seatCols': seatCols,
  };

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final start = json['startTime'] as int?;
    final end = json['endTime'] as int?;
    final baseline = json['baselineAt'];
    final trusted = json['trustedDeviceIds'];

    final rawLogs = json['deviceLogs'];
    final logs = <ActionLogModel>[
      if (rawLogs is List)
        for (final e in rawLogs)
          if (e is Map) ActionLogModel.fromJson(Map<String, dynamic>.from(e)),
    ];

    return SessionModel(
      id: json['id'] as String,
      instituteName: json['instituteName'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(start ?? 0),
      endTime: end != null ? DateTime.fromMillisecondsSinceEpoch(end) : null,
      deviceLogs: logs,
      trustedDeviceIds: {
        if (trusted is List)
          for (final id in trusted)
            if (id is String) id,
      },
      baselineAt: baseline is int
          ? DateTime.fromMillisecondsSinceEpoch(baseline)
          : null,
      seatRows: json['seatRows'] as int?,
      seatCols: json['seatCols'] as int?,
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
            other.deviceLogs.length == deviceLogs.length &&
            other.baselineAt == baselineAt &&
            other.seatRows == seatRows &&
            other.seatCols == seatCols &&
            other.trustedDeviceIds.length == trustedDeviceIds.length &&
            other.trustedDeviceIds.containsAll(trustedDeviceIds));
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
    trustedDeviceIds.length,
    baselineAt,
    seatRows,
    seatCols,
  );
}
