import 'package:meta/meta.dart';

import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// A device that showed up close by after the empty-room baseline was taken
/// and is not trusted. Raised once per device.
@immutable
class NewDeviceAlert {
  const NewDeviceAlert({
    required this.deviceId,
    required this.displayName,
    required this.deviceType,
    required this.transport,
    required this.rssi,
    required this.detectedAt,
    this.acknowledged = false,
  });

  /// [ScannedDeviceModel.id] of the device (Wi-Fi ids start with `wifi:`).
  final String deviceId;
  final String displayName;

  /// English category string, as in [ScannedDeviceModel.deviceType].
  final String deviceType;
  final DeviceTransport transport;

  /// Signal strength when the alert was raised (dBm).
  final int rssi;
  final DateTime detectedAt;

  /// True once the invigilator has seen it.
  final bool acknowledged;

  NewDeviceAlert copyWith({bool? acknowledged}) => NewDeviceAlert(
    deviceId: deviceId,
    displayName: displayName,
    deviceType: deviceType,
    transport: transport,
    rssi: rssi,
    detectedAt: detectedAt,
    acknowledged: acknowledged ?? this.acknowledged,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewDeviceAlert &&
          other.deviceId == deviceId &&
          other.detectedAt == detectedAt &&
          other.acknowledged == acknowledged;

  @override
  int get hashCode => Object.hash(deviceId, detectedAt, acknowledged);

  @override
  String toString() =>
      'NewDeviceAlert($deviceId, $displayName, $transport, $rssi dBm'
      '${acknowledged ? ', acknowledged' : ''})';
}
