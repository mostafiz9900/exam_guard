import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/sensors/heading_service_impl.dart';

/// Which way the top edge of the phone points.
class HeadingReading {
  const HeadingReading({required this.degrees, required this.needsCalibration});

  /// 0–360, clockwise from magnetic north.
  final double degrees;

  /// The compass is poorly calibrated: ask for a figure-8.
  final bool needsCalibration;
}

/// Thrown (as a stream error) when the phone has no compass heading.
class HeadingUnavailableException implements Exception {
  const HeadingUnavailableException();
}

/// Tilt-compensated compass heading from the OS sensor fusion
/// (Android rotation vector, iOS Core Motion).
abstract interface class IHeadingService {
  /// About 20 readings a second while listened to.
  Stream<HeadingReading> headings();
}

final headingServiceProvider = Provider<IHeadingService>(
  (ref) => HeadingServiceImpl(),
);
