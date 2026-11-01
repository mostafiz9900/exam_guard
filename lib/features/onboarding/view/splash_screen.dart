import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/utils/app_brand.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/onboarding/view/widgets/brand_colors.dart';
import 'package:exam_guard/features/onboarding/view_model/onboarding_view_model.dart';

/// Brand intro after the native splash (same navy and emblem, so the hand
/// over is seamless): a radar sweep over the emblem, the name, then the
/// introduction (first run) or exam setup.
class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  /// How long the intro stays. Tests set it to zero.
  @visibleForTesting
  static Duration hold = const Duration(milliseconds: 1600);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sweep = useAnimationController(
      duration: const Duration(milliseconds: 1800),
    );
    final intro = useAnimationController(
      duration: const Duration(milliseconds: 700),
    );
    useEffect(() {
      if (!reduceMotion) {
        sweep.repeat();
        intro.forward();
      } else {
        intro.value = 1;
      }
      final target = ref.read(launchRouteProvider);
      void go() {
        if (context.mounted) context.goTo(target);
      }

      if (hold == Duration.zero) {
        WidgetsBinding.instance.addPostFrameCallback((_) => go());
        return null;
      }
      final timer = Timer(hold, go);
      return timer.cancel;
    }, const []);

    final size = math.min(170.w, 220.0);
    final fade = CurvedAnimation(parent: intro, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: BrandColors.navy,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 0.9,
            colors: [BrandColors.navyLight, BrandColors.navy],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size * 1.45,
                  height: size * 1.45,
                  child: AnimatedBuilder(
                    animation: sweep,
                    builder: (context, child) => CustomPaint(
                      painter: _RadarPainter(
                        progress: sweep.value,
                        emblemRadius: size / 2,
                      ),
                      child: child,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/pahara_emblem.png',
                        key: const Key('splash_emblem'),
                        width: size,
                        height: size,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(fade),
                    child: Column(
                      children: [
                        Text(
                          AppBrand.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'app_tagline'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BrandColors.cyan.withValues(alpha: 0.9),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanding pulse rings and a rotating sweep around the emblem.
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress, required this.emblemRadius});

  final double progress;
  final double emblemRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (final offset in const [0.0, 0.5]) {
      final t = (progress + offset) % 1.0;
      final r = emblemRadius + (maxR - emblemRadius) * t;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = BrandColors.cyan.withValues(alpha: 0.45 * (1 - t)),
      );
    }
    final sweepRect = Rect.fromCircle(center: c, radius: maxR * 0.98);
    final start = progress * 2 * math.pi;
    canvas.drawArc(
      sweepRect,
      start,
      0.9,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + 0.9,
          colors: [
            BrandColors.cyan.withValues(alpha: 0),
            BrandColors.cyan.withValues(alpha: 0.22),
          ],
        ).createShader(sweepRect),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}
