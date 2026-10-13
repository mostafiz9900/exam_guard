import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Loading indicators. Wraps `flutter_spinkit` so features never import it.
class AppLoader extends StatelessWidget {
  /// Small spinning ring, e.g. inside a button.
  const AppLoader.ring({
    super.key,
    required this.color,
    this.size = 18,
    this.lineWidth = 2,
  }) : _ripple = false;

  /// Expanding ripple, e.g. behind a radar while scanning.
  const AppLoader.ripple({super.key, required this.color, required this.size})
    : lineWidth = 0,
      _ripple = true;

  final Color color;
  final double size;
  final double lineWidth;
  final bool _ripple;

  @override
  Widget build(BuildContext context) {
    return _ripple
        ? SpinKitRipple(color: color, size: size)
        : SpinKitRing(color: color, size: size, lineWidth: lineWidth);
  }
}
