import 'package:flutter/material.dart';

/// One expanding ring of the status card's radar animation.
class RadarRing extends StatelessWidget {
  const RadarRing({
    super.key,
    required this.size,
    required this.color,
    required this.scale,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
