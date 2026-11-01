import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';

/// Android: `TYPE_MAGNETIC_FIELD` via sensors_plus — already calibrated.
/// iOS: Core Motion's calibrated field through ios/Runner/AppDelegate.swift
/// (sensors_plus would give the raw sensor with the phone's own bias, often
/// hundreds of µT). If that channel is unavailable, falls back to the raw
/// sensor and marks readings as not calibrated.
class MagnetometerServiceImpl implements IMagnetometerService {
  static const EventChannel _calibrated = EventChannel(
    'exam_guard/magnetometer',
  );

  @override
  Stream<MagnetometerReading> readings() =>
      Platform.isIOS ? _iosCalibrated() : _plugin(isCalibrated: true);

  Stream<MagnetometerReading> _plugin({required bool isCalibrated}) =>
      magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval).map(
        (e) => MagnetometerReading(
          x: e.x,
          y: e.y,
          z: e.z,
          timestamp: e.timestamp,
          isCalibrated: isCalibrated,
        ),
      );

  Stream<MagnetometerReading> _iosCalibrated() async* {
    try {
      await for (final event in _calibrated.receiveBroadcastStream()) {
        final reading = parseCalibrated(event);
        if (reading != null) yield reading;
      }
    } on PlatformException catch (e) {
      if (e.code != 'unavailable') rethrow;
      yield* _plugin(isCalibrated: false);
    } on MissingPluginException {
      yield* _plugin(isCalibrated: false);
    }
  }

  /// Parses one `[x, y, z, accuracy, timestamp]` event from the native side.
  @visibleForTesting
  static MagnetometerReading? parseCalibrated(Object? event) {
    if (event is! List || event.length < 4) return null;
    final v = [for (final e in event) e is num ? e.toDouble() : null];
    if (v.take(4).contains(null)) return null;
    final accuracy = switch (v[3]!.toInt()) {
      -1 => MagnetometerAccuracy.uncalibrated,
      0 => MagnetometerAccuracy.low,
      1 => MagnetometerAccuracy.medium,
      2 => MagnetometerAccuracy.high,
      _ => MagnetometerAccuracy.unknown,
    };
    // Before the first calibration Core Motion reports an all-zero field.
    final zero = v[0] == 0 && v[1] == 0 && v[2] == 0;
    return MagnetometerReading(
      x: v[0]!,
      y: v[1]!,
      z: v[2]!,
      timestamp: DateTime.now(),
      isCalibrated: !zero,
      accuracy: zero ? MagnetometerAccuracy.uncalibrated : accuracy,
    );
  }
}
