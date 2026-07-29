import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

/// Standardized app dimensions for paddings, margins, radii, and font sizes.
///
/// This class exposes values through ScreenUtil extensions to prevent magic numbers.
class AppDimens {
  AppDimens._();

  static double get spacingExtraSmall => 6.w;
  static double get spacingSmall => 12.w;
  static double get spacingMedium => 16.w;
  static double get spacingLarge => 24.w;
  static double get spacingExtraLarge => 32.w;

  static double get radiusSmall => 8.r;
  static double get radiusMedium => 12.r;
  static double get radiusLarge => 18.r;

  static double get buttonHeight => 50.h;
  static double get inputFieldHeight => 54.h;

  static double get heading1 => 28.sp;
  static double get heading2 => 24.sp;
  static double get heading3 => 20.sp;
  static double get bodyLarge => 16.sp;
  static double get bodyMedium => 14.sp;
  static double get bodySmall => 12.sp;
}
