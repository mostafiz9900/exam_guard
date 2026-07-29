class DeviceModel {
  const DeviceModel({
    required this.deviceId,
    required this.name,
    required this.status,
    required this.lastSeen,
    required this.signalStrength,
  });

  final String deviceId;
  final String name;
  final String status;
  final DateTime lastSeen;
  final int signalStrength;

  bool get isNearby => signalStrength >= -60;

  DeviceModel copyWith({
    String? deviceId,
    String? name,
    String? status,
    DateTime? lastSeen,
    int? signalStrength,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    if (map['deviceId'] is! String || (map['deviceId'] as String).isEmpty) {
      throw FormatException('DeviceModel requires a valid deviceId');
    }
    if (map['name'] is! String || (map['name'] as String).isEmpty) {
      throw FormatException('DeviceModel requires a valid name');
    }
    if (map['status'] is! String || (map['status'] as String).isEmpty) {
      throw FormatException('DeviceModel requires a valid status');
    }

    final lastSeenValue = map['lastSeen'];
    final signalType = map['signalStrength'];

    return DeviceModel(
      deviceId: map['deviceId'] as String,
      name: map['name'] as String,
      status: map['status'] as String,
      lastSeen: lastSeenValue is DateTime
          ? lastSeenValue
          : DateTime.fromMillisecondsSinceEpoch(
              lastSeenValue is int ? lastSeenValue : 0,
            ),
      signalStrength: signalType is int
          ? signalType
          : int.tryParse('$signalType') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'name': name,
      'status': status,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'signalStrength': signalStrength,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeviceModel &&
            runtimeType == other.runtimeType &&
            deviceId == other.deviceId &&
            name == other.name &&
            status == other.status &&
            lastSeen == other.lastSeen &&
            signalStrength == other.signalStrength;
  }

  @override
  int get hashCode {
    return Object.hash(deviceId, name, status, lastSeen, signalStrength);
  }

  @override
  String toString() {
    return 'DeviceModel(deviceId: $deviceId, name: $name, status: $status, lastSeen: $lastSeen, signalStrength: $signalStrength)';
  }
}
