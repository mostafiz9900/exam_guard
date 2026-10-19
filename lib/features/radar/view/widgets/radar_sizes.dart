import 'dart:math' as math;

import 'package:exam_guard/core/utils/size_extensions.dart';

/// Radius-scaled size that never shrinks below 90 % of the design value
/// (`.r` follows the short side, so landscape would make icons tiny).
extension RadarSize on num {
  double get rc => math.max(r, toDouble() * 0.9);
}
