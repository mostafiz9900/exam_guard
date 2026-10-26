import 'package:flutter/material.dart';

import 'package:exam_guard/features/lens_finder/view_model/lens_finder_view_model.dart';

/// Marks confirmed glints on the camera picture. [area] is the rectangle
/// the (cover-fitted) preview occupies inside this widget's box; candidates
/// are 0..1 of that rectangle.
class LensGlintOverlay extends StatelessWidget {
  const LensGlintOverlay({
    super.key,
    required this.candidates,
    required this.area,
    required this.pulse,
  });

  final List<LensCandidate> candidates;
  final Rect area;
  final Animation<double> pulse;

  /// Ring diameter in logical pixels (fixed, so it never hides the point
  /// on a small preview nor grows huge on a tablet).
  static const double ringSize = 56;

  static const Color ringColor = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Offset.zero & constraints.biggest;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var i = 0; i < candidates.length; i++)
              if (box.contains(_point(candidates[i])))
                Positioned(
                  left: _point(candidates[i]).dx - ringSize / 2,
                  top: _point(candidates[i]).dy - ringSize / 2,
                  width: ringSize,
                  height: ringSize,
                  child: LensRing(
                    key: ValueKey(candidates[i].id),
                    index: i + 1,
                    confidence: candidates[i].confidence,
                    pulse: pulse,
                  ),
                ),
          ],
        );
      },
    );
  }

  Offset _point(LensCandidate c) =>
      Offset(area.left + c.x * area.width, area.top + c.y * area.height);
}

/// A pulsing ring with its number, centred on a glint.
class LensRing extends StatelessWidget {
  const LensRing({
    super.key,
    required this.index,
    required this.confidence,
    required this.pulse,
  });

  final int index;
  final double confidence;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _RingPainter(pulse, confidence),
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: LensGlintOverlay.ringColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.pulse, this.confidence) : super(repaint: pulse);

  final Animation<double> pulse;
  final double confidence;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2 - 2;
    final t = pulse.value;
    const color = LensGlintOverlay.ringColor;

    // Expanding, fading halo.
    canvas.drawCircle(
      center,
      maxR * (0.45 + 0.55 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * 0.8),
    );
    // Steady ring; thicker when more confident.
    canvas.drawCircle(
      center,
      maxR * 0.45,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 2 * confidence
        ..color = color,
    );
    // Dark outline keeps the ring visible on bright backgrounds.
    canvas.drawCircle(
      center,
      maxR * 0.45 + 2 + confidence,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pulse != pulse || old.confidence != confidence;
}
