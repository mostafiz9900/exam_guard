import 'package:flutter/widgets.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder while content loads. Wraps `shimmer`.
class AppShimmer extends StatelessWidget {
  const AppShimmer({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    required this.child,
  });

  final Color baseColor;
  final Color highlightColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}
