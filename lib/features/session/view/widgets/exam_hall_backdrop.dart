import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Illustration behind the setup header: an exam hall seen from the
/// invigilator's desk — rows of desks in perspective — with a radar sweep
/// scanning the room and a few glowing detected signals. Drawn in code so it
/// is sharp at any size and follows the theme.
class ExamHallBackdrop extends StatelessWidget {
  const ExamHallBackdrop({super.key, required this.sweep, required this.dark});

  /// Radar sweep angle, 0–1 of a turn.
  final Animation<double> sweep;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final top = dark
        ? Color.lerp(primary, Colors.black, 0.62)!
        : Color.lerp(primary, Colors.black, 0.12)!;
    final bottom = dark
        ? Color.lerp(primary, Colors.black, 0.80)!
        : Color.lerp(primary, const Color(0xFF0B1B4D), 0.55)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _HallPainter(sweep: sweep),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _HallPainter extends CustomPainter {
  _HallPainter({required this.sweep}) : super(repaint: sweep);

  final Animation<double> sweep;

  // Detected "devices" as fractions of the canvas (x, y).
  static const List<Offset> _signals = [
    Offset(0.22, 0.70),
    Offset(0.63, 0.82),
    Offset(0.80, 0.58),
    Offset(0.41, 0.93),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _desks(canvas, size);
    _radar(canvas, size);
    _signalDots(canvas, size);
    _vignette(canvas, size);
  }

  /// Rows of desks shrinking towards a horizon near the top.
  void _desks(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Room starts below the title so the text stays clear.
    final horizon = size.height * 0.44;
    final vanishX = size.width * 0.5;
    const rows = 6;
    const cols = 7;
    for (var r = 0; r < rows; r++) {
      // 0 = far, 1 = near; squared for perspective spacing.
      final t = (r + 1) / rows;
      final y = horizon + (size.height - horizon) * t * t;
      final scale = 0.25 + 0.75 * t;
      final rowWidth = size.width * 1.5 * scale;
      final deskW = rowWidth / cols * 0.62;
      final deskH = 10 * scale + 4;
      for (var c = 0; c < cols; c++) {
        final cx = vanishX - rowWidth / 2 + rowWidth * (c + 0.5) / cols;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y), width: deskW, height: deskH),
          Radius.circular(3 * scale + 1),
        );
        canvas
          ..drawRRect(rect, fill)
          ..drawRRect(rect, edge);
      }
    }
  }

  /// Rings and a rotating sweep from the invigilator's corner.
  void _radar(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.86, size.height * 0.22);
    final maxR = size.longestSide * 0.9;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 1; i <= 5; i++) {
      final r = maxR * i / 5;
      ring.color = Colors.white.withValues(alpha: 0.14 - i * 0.02);
      canvas.drawCircle(center, r, ring);
    }

    final angle = sweep.value * 2 * math.pi;
    const width = math.pi / 3.2;
    final rect = Rect.fromCircle(center: center, radius: maxR);
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: width,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.16),
      ],
      transform: GradientRotation(angle - width),
    ).createShader(rect);
    canvas.drawArc(rect, angle - width, width, true, Paint()..shader = shader);
    // Leading edge of the sweep.
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * maxR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      center,
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  /// Signals light up as the sweep passes over them, then fade.
  void _signalDots(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.86, size.height * 0.22);
    final sweepAngle = sweep.value * 2 * math.pi;
    for (final s in _signals) {
      final p = Offset(s.dx * size.width, s.dy * size.height);
      final a = math.atan2(p.dy - center.dy, p.dx - center.dx);
      // Turns since the sweep last passed this dot (0 = just now).
      final since = ((sweepAngle - a) / (2 * math.pi)) % 1;
      final glow = math.max(0.25, 1 - since * 1.6);
      canvas
        ..drawCircle(
          p,
          13,
          Paint()
            ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.22 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        )
        ..drawCircle(
          p,
          3.5,
          Paint()..color = const Color(0xFFFFB4B4).withValues(alpha: glow),
        );
    }
  }

  /// Darker bottom so white text and the overlapping card read well.
  void _vignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_HallPainter old) => old.sweep != sweep;
}
