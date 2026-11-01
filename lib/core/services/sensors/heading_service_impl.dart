import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:exam_guard/core/services/sensors/i_heading_service.dart';

/// Native side: android/.../HeadingSensor.kt and ios/Runner/AppDelegate.swift
/// (HeadingStream). Events are `[degrees, accuracy]`.
class HeadingServiceImpl implements IHeadingService {
  static const EventChannel _channel = EventChannel('exam_guard/heading');

  @override
  Stream<HeadingReading> headings() async* {
    try {
      await for (final event in _channel.receiveBroadcastStream()) {
        final reading = parse(event, isIOS: Platform.isIOS);
        if (reading != null) yield reading;
      }
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') throw const HeadingUnavailableException();
      rethrow;
    } on MissingPluginException {
      throw const HeadingUnavailableException();
    }
  }

  /// Android accuracy: 0 unreliable … 3 high. iOS: -1 uncalibrated … 2 high.
  @visibleForTesting
  static HeadingReading? parse(Object? event, {required bool isIOS}) {
    if (event is! List || event.length < 2) return null;
    final deg = event[0];
    final acc = event[1];
    if (deg is! num || acc is! num || deg < 0) return null;
    return HeadingReading(
      degrees: deg.toDouble() % 360,
      needsCalibration: isIOS ? acc <= 0 : acc <= 1,
    );
  }
}
