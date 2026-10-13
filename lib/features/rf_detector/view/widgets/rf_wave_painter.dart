import 'package:flutter/material.dart';

class RfWavePainter extends CustomPainter {
  RfWavePainter({required this.history, required this.color});
  final List<double> history;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final dbm = history[i].clamp(-100.0, -20.0);
      final norm = (dbm - (-100.0)) / 80.0; // 0.0 to 1.0
      final y = size.height - (norm * size.height);
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RfWavePainter oldDelegate) {
    return oldDelegate.history != history || oldDelegate.color != color;
  }
}
