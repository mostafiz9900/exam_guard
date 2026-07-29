class SessionModel {
  const SessionModel({
    required this.sessionId,
    required this.instituteName,
    required this.teacherName,
    required this.roomNumber,
    required this.startTime,
    required this.isActive,
  });

  final String sessionId;
  final String instituteName;
  final String teacherName;
  final String roomNumber;
  final DateTime startTime;
  final bool isActive;

  SessionModel copyWith({
    String? sessionId,
    String? instituteName,
    String? teacherName,
    String? roomNumber,
    DateTime? startTime,
    bool? isActive,
  }) {
    return SessionModel(
      sessionId: sessionId ?? this.sessionId,
      instituteName: instituteName ?? this.instituteName,
      teacherName: teacherName ?? this.teacherName,
      roomNumber: roomNumber ?? this.roomNumber,
      startTime: startTime ?? this.startTime,
      isActive: isActive ?? this.isActive,
    );
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    if (map['sessionId'] is! String || (map['sessionId'] as String).isEmpty) {
      throw FormatException('SessionModel requires a valid sessionId');
    }
    if (map['instituteName'] is! String ||
        (map['instituteName'] as String).isEmpty) {
      throw FormatException('SessionModel requires a valid instituteName');
    }
    if (map['teacherName'] is! String ||
        (map['teacherName'] as String).isEmpty) {
      throw FormatException('SessionModel requires a valid teacherName');
    }
    if (map['roomNumber'] is! String || (map['roomNumber'] as String).isEmpty) {
      throw FormatException('SessionModel requires a valid roomNumber');
    }

    final startTimeValue = map['startTime'];

    return SessionModel(
      sessionId: map['sessionId'] as String,
      instituteName: map['instituteName'] as String,
      teacherName: map['teacherName'] as String,
      roomNumber: map['roomNumber'] as String,
      startTime: startTimeValue is DateTime
          ? startTimeValue
          : DateTime.fromMillisecondsSinceEpoch(
              startTimeValue is int ? startTimeValue : 0,
            ),
      isActive: map['isActive'] is bool ? map['isActive'] as bool : false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'instituteName': instituteName,
      'teacherName': teacherName,
      'roomNumber': roomNumber,
      'startTime': startTime.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionModel &&
            runtimeType == other.runtimeType &&
            sessionId == other.sessionId &&
            instituteName == other.instituteName &&
            teacherName == other.teacherName &&
            roomNumber == other.roomNumber &&
            startTime == other.startTime &&
            isActive == other.isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      sessionId,
      instituteName,
      teacherName,
      roomNumber,
      startTime,
      isActive,
    );
  }

  @override
  String toString() {
    return 'SessionModel(sessionId: $sessionId, instituteName: $instituteName, teacherName: $teacherName, roomNumber: $roomNumber, startTime: $startTime, isActive: $isActive)';
  }
}
