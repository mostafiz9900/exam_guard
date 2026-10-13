import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

/// Design size every screen is laid out against.
const Size kDesignSize = Size(375, 812);

/// Responsive sizing. Wraps `flutter_screenutil_plus` so features never import it.
extension AppSizeExtension on num {
  /// Width scaled to the current screen.
  double get w => ScreenUtilPlus().setWidth(this);

  /// Height scaled to the current screen.
  double get h => ScreenUtilPlus().setHeight(this);

  /// Font size scaled to the current screen.
  double get sp => ScreenUtilPlus().setSp(this);

  /// Radius scaled to the current screen.
  double get r => ScreenUtilPlus().radius(this);
}

/// Initializes responsive sizing for everything below it.
class AppScreenSize extends StatelessWidget {
  const AppScreenSize({super.key, required this.builder});

  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilPlusInit(
      designSize: kDesignSize,
      minTextAdapt: true,
      builder: (context, _) => builder(context),
    );
  }
}
