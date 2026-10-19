import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:exam_guard/core/widgets/app_shimmer.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_colors.dart';

/// What the gauge is showing.
enum GaugeMode {
  /// Live measurement: coloured arc, pulse, peak marker.
  live,

  /// Waiting for the first packet: shimmering skeleton arc.
  acquiring,

  /// No packet for a while: the last value, greyed out, no pulse.
  lost,

  /// Not measuring (Location off, scan failed): empty grey arc.
  off,
}

/// 270° hot/cold arc gauge: animated value arc (cold → hot gradient), a
/// "best so far" marker and a soft pulse whose speed follows closeness.
/// [centerBuilder] gets the animated 0–1 value for a count-up number.
class ClosenessGauge extends HookWidget {
  const ClosenessGauge({
    super.key,
    required this.diameter,
    required this.mode,
    required this.closeness,
    required this.peak,
    required this.centerBuilder,
  });

  final double diameter;
  final GaugeMode mode;

  /// 0–100; current value when live, last value when lost.
  final int? closeness;

  /// 0–100 "best so far" marker; hidden when null.
  final int? peak;
  final Widget Function(BuildContext context, double value) centerBuilder;

  static const Duration valueTween = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isLive = mode == GaugeMode.live;
    final target = (closeness ?? 0).clamp(0, 100) / 100;

    // Pulse period: ~1.8 s when cold, ~0.5 s when hot. Bucketed so the
    // controller is not restarted on every packet.
    final band = isLive ? ((closeness ?? 0) ~/ 10).clamp(0, 10) : -1;
    final pulse = useAnimationController();
    useEffect(() {
      if (band < 0 || reduceMotion) {
        pulse
          ..stop()
          ..value = 0;
        return null;
      }
      final ms = (1800 - band * 130).clamp(500, 1800);
      pulse
        ..duration = Duration(milliseconds: ms)
        ..repeat();
      return null;
    }, [pulse, band, reduceMotion]);

    final tween = reduceMotion ? Duration.zero : valueTween;
    final track = colors.surfaceContainerHighest;

    Widget arc(double value, double? peakValue) => CustomPaint(
      size: Size.square(diameter),
      painter: GaugePainter(
        value: mode == GaugeMode.acquiring || mode == GaugeMode.off ? 0 : value,
        peak: mode == GaugeMode.off ? null : peakValue,
        trackColor: track,
        tickColor: colors.outlineVariant,
        markerColor: colors.onSurface,
        markerRingColor: colors.surface,
        greyColor: colors.outline,
        desaturated: mode == GaugeMode.lost,
        glow: isLive,
      ),
    );

    return SizedBox.square(
      dimension: diameter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: tween,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final peakTarget = peak == null ? null : peak!.clamp(0, 100) / 100;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (isLive && !reduceMotion)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => CustomPaint(
                    size: Size.square(diameter),
                    painter: _PulsePainter(
                      progress: pulse.value,
                      color: closenessColorAt(value),
                    ),
                  ),
                ),
              if (mode == GaugeMode.acquiring && !reduceMotion)
                AppShimmer(
                  baseColor: track,
                  highlightColor: colors.primary.withValues(alpha: 0.45),
                  child: arc(0, null),
                )
              else
                arc(value, peakTarget),
              Padding(
                padding: EdgeInsets.all(diameter * 0.17),
                child: centerBuilder(context, value),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Paints the gauge track, ticks, value arc and peak marker.
class GaugePainter extends CustomPainter {
  GaugePainter({
    required this.value,
    required this.peak,
    required this.trackColor,
    required this.tickColor,
    required this.markerColor,
    required this.markerRingColor,
    required this.greyColor,
    required this.desaturated,
    required this.glow,
  });

  static const double startAngle = 0.75 * math.pi;
  static const double sweepAngle = 1.5 * math.pi;

  /// 0–1.
  final double value;

  /// 0–1, or null for no marker.
  final double? peak;
  final Color trackColor;
  final Color tickColor;
  final Color markerColor;
  final Color markerRingColor;
  final Color greyColor;
  final bool desaturated;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final stroke = side * 0.075;
    final center = size.center(Offset.zero);
    final radius = side / 2 - stroke / 2 - side * 0.03;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Quarter ticks inside the track.
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = math.max(1.5, side * 0.008)
      ..strokeCap = StrokeCap.round;
    for (final f in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final a = startAngle + sweepAngle * f;
      final dir = Offset(math.cos(a), math.sin(a));
      final inner = radius - stroke / 2 - side * 0.045;
      final outer = radius - stroke / 2 - side * 0.02;
      canvas.drawLine(center + dir * inner, center + dir * outer, tickPaint);
    }

    final v = value.clamp(0.0, 1.0);
    if (v > 0.004) {
      final shader = desaturated
          ? null
          : SweepGradient(
              colors: [...closenessStops, closenessStops.first],
              stops: const [0, 0.1875, 0.375, 0.5625, 0.75, 1],
              transform: const GradientRotation(startAngle),
            ).createShader(rect);
      final valuePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      if (shader != null) {
        valuePaint.shader = shader;
      } else {
        valuePaint.color = greyColor.withValues(alpha: 0.55);
      }
      if (glow) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.2
          ..strokeCap = StrokeCap.round
          ..color = closenessColorAt(v).withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.5);
        canvas.drawArc(rect, startAngle, sweepAngle * v, false, glowPaint);
      }
      canvas.drawArc(rect, startAngle, sweepAngle * v, false, valuePaint);

      // Knob at the current value.
      if (!desaturated) {
        final a = startAngle + sweepAngle * v;
        final p = center + Offset(math.cos(a), math.sin(a)) * radius;
        canvas.drawCircle(
          p,
          stroke * 0.26,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
      }
    }

    final pk = peak;
    if (pk != null) {
      final a = startAngle + sweepAngle * pk.clamp(0.0, 1.0);
      final dir = Offset(math.cos(a), math.sin(a));
      // Notch outside the arc + ringed dot on it.
      canvas.drawLine(
        center + dir * (radius + stroke * 0.62),
        center + dir * (radius + stroke * 1.05),
        Paint()
          ..color = markerColor
          ..strokeWidth = math.max(2, side * 0.012)
          ..strokeCap = StrokeCap.round,
      );
      final p = center + dir * radius;
      canvas.drawCircle(p, stroke * 0.42, Paint()..color = markerRingColor);
      canvas.drawCircle(p, stroke * 0.3, Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(covariant GaugePainter old) =>
      old.value != value ||
      old.peak != peak ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor ||
      old.markerColor != markerColor ||
      old.markerRingColor != markerRingColor ||
      old.greyColor != greyColor ||
      old.desaturated != desaturated ||
      old.glow != glow;
}

/// Two staggered soft rings expanding inside the gauge.
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = size.center(Offset.zero);
    for (final offset in const [0.0, 0.5]) {
      final t = (progress + offset) % 1.0;
      final r = lerpDouble(side * 0.22, side * 0.4, t)!;
      final alpha = (1 - t) * 0.22;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.02,
      );
    }
    canvas.drawCircle(
      center,
      side * 0.22,
      Paint()..color = color.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.progress != progress || old.color != color;
}
