import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_bottom_sheet.dart';
import 'package:exam_guard/features/radar/model/direction_finder.dart';
import 'package:exam_guard/features/radar/view_model/direction_finder_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Opens "Find the direction" for [device] over the radar.
Future<void> showDirectionFinder(
  BuildContext context,
  ScannedDeviceModel device,
) => showAppBottomSheet<void>(
  context: context,
  maxHeightFraction: 0.95,
  builder: (_) => DirectionFinderSheet(device: device),
);

const _compassKeys = [
  'dir_n',
  'dir_ne',
  'dir_e',
  'dir_se',
  'dir_s',
  'dir_sw',
  'dir_w',
  'dir_nw',
];
const _hallKeys = [
  'hall_dir_front',
  'hall_dir_front_right',
  'hall_dir_right',
  'hall_dir_back_right',
  'hall_dir_back',
  'hall_dir_back_left',
  'hall_dir_left',
  'hall_dir_front_left',
];

class DirectionFinderSheet extends ConsumerWidget {
  const DirectionFinderSheet({super.key, required this.device});

  final ScannedDeviceModel device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(directionFinderViewModelProvider);
    final vm = ref.read(directionFinderViewModelProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final dial = math.min(MediaQuery.sizeOf(context).width - 64, 300.0);

    Future<void> setFront() async {
      final ok = await vm.setFront();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((ok ? 'dir_front_saved' : 'dir_front_failed').tr()),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spacingMedium,
        0,
        AppDimens.spacingMedium,
        AppDimens.spacingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dir_title'.tr(),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      device.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'close'.tr(),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (s.headingUnavailable)
            _Note(
              icon: Icons.explore_off_rounded,
              color: colors.error,
              text: 'dir_no_compass'.tr(),
            )
          else ...[
            if (s.needsCalibration)
              _Note(
                icon: Icons.screen_rotation_alt_rounded,
                color: Colors.orange.shade700,
                text: 'dir_calibrate'.tr(),
              ),
            SizedBox(height: AppDimens.spacingSmall),
            Center(
              child: SizedBox(
                width: dial,
                height: dial,
                child: CustomPaint(
                  key: const Key('dir_dial'),
                  painter: CompassRosePainter(
                    heading: s.heading,
                    frontHeading: s.frontHeading,
                    levels: s.levels,
                    bearing: s.phase == DirectionPhase.done
                        ? s.result?.bearing
                        : null,
                    arrowColor: _confidenceColor(s.result?.confidence, colors),
                    ring: colors.outlineVariant,
                    text: colors.onSurfaceVariant,
                    accent: colors.primary,
                    letters: [
                      for (final k in const [
                        'dir_letter_n',
                        'dir_letter_e',
                        'dir_letter_s',
                        'dir_letter_w',
                      ])
                        k.tr(),
                    ],
                    frontLabel: 'dir_front_short'.tr(),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            switch (s.phase) {
              DirectionPhase.ready => _Ready(
                state: s,
                onStart: () => vm.start(device.id),
                onSetFront: setFront,
              ),
              DirectionPhase.turning => _Turning(state: s, onStop: vm.finish),
              DirectionPhase.done => _Done(
                state: s,
                onAgain: () => vm.start(device.id),
                onSetFront: setFront,
                onClose: () => Navigator.of(context).pop(),
              ),
            },
          ],
        ],
      ),
    );
  }
}

Color _confidenceColor(DirectionConfidence? c, ColorScheme colors) =>
    switch (c) {
      DirectionConfidence.good => AppColors.success,
      DirectionConfidence.fair => Colors.orange.shade700,
      _ => colors.outline,
    };

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: AppDimens.spacingSmall),
    padding: EdgeInsets.all(AppDimens.spacingSmall),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20.w),
        SizedBox(width: AppDimens.spacingSmall),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(height: 1.35),
          ),
        ),
      ],
    ),
  );
}

ButtonStyle _big() => FilledButton.styleFrom(
  minimumSize: Size.fromHeight(AppDimens.buttonHeight),
);

class _Ready extends StatelessWidget {
  const _Ready({
    required this.state,
    required this.onStart,
    required this.onSetFront,
  });

  final DirectionState state;
  final VoidCallback onStart;
  final VoidCallback onSetFront;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget step(int n, String key) => Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10.r,
            child: Text('$n', style: textTheme.labelSmall),
          ),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(child: Text(key.tr(), style: textTheme.bodySmall)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        step(1, 'dir_step_hold'),
        step(2, 'dir_step_turn'),
        step(3, 'dir_step_follow'),
        SizedBox(height: AppDimens.spacingSmall),
        FilledButton.icon(
          key: const Key('dir_start'),
          style: _big(),
          onPressed: state.heading == null ? null : onStart,
          icon: const Icon(Icons.threesixty_rounded),
          label: Text('dir_start'.tr()),
        ),
        SizedBox(height: 6.h),
        _FrontButton(state: state, onSetFront: onSetFront),
      ],
    );
  }
}

class _FrontButton extends StatelessWidget {
  const _FrontButton({required this.state, required this.onSetFront});

  final DirectionState state;
  final VoidCallback onSetFront;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        key: const Key('dir_set_front'),
        onPressed: state.heading == null ? null : onSetFront,
        icon: const Icon(Icons.co_present_rounded),
        label: Text(
          (state.frontHeading == null ? 'dir_set_front' : 'dir_reset_front')
              .tr(),
        ),
      ),
      Text(
        'dir_front_hint'.tr(),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _Turning extends StatelessWidget {
  const _Turning({required this.state, required this.onStop});

  final DirectionState state;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'dir_turning'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: LinearProgressIndicator(
            key: const Key('dir_progress'),
            value: state.coverage,
            minHeight: 8.h,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'dir_covered'.tr(args: {'pct': '${(state.coverage * 100).round()}'}),
          textAlign: TextAlign.center,
          style: textTheme.labelSmall,
        ),
        if (state.tooFast)
          _Note(
            icon: Icons.slow_motion_video_rounded,
            color: Colors.orange.shade700,
            text: 'dir_too_fast'.tr(),
          ),
        if (state.noSignal)
          _Note(
            icon: Icons.signal_cellular_off_rounded,
            color: colors.error,
            text: 'dir_no_signal'.tr(),
          ),
        SizedBox(height: AppDimens.spacingSmall),
        OutlinedButton(
          key: const Key('dir_stop'),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(AppDimens.buttonHeight),
          ),
          onPressed: onStop,
          child: Text('dir_stop'.tr()),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.state,
    required this.onAgain,
    required this.onSetFront,
    required this.onClose,
  });

  final DirectionState state;
  final VoidCallback onAgain;
  final VoidCallback onSetFront;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final r = state.result;
    final clear = r != null && r.confidence != DirectionConfidence.unclear;
    final heading = state.heading;
    final front = state.frontHeading;

    String? turnHint;
    if (clear && heading != null) {
      final d = turnTo(heading, r.bearing);
      turnHint = d.abs() <= 20
          ? 'dir_facing_it'.tr()
          : (d > 0 ? 'dir_turn_right' : 'dir_turn_left').tr(
              args: {'deg': '${d.abs().round()}'},
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!clear)
          _Note(
            icon: Icons.help_outline_rounded,
            color: Colors.orange.shade700,
            text: (r == null ? 'dir_incomplete' : 'dir_unclear').tr(),
          )
        else ...[
          if (front != null)
            Text(
              _hallKeys[hallPoint(r.bearing, front)].tr(),
              key: const Key('dir_hall_word'),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            'dir_compass'.tr(
              args: {
                'dir': _compassKeys[compassPoint(r.bearing)].tr(),
                'deg': '${r.bearing.round()}',
              },
            ),
            key: const Key('dir_compass_word'),
            textAlign: TextAlign.center,
            style:
                (front == null ? textTheme.headlineSmall : textTheme.titleSmall)
                    ?.copyWith(
                      fontWeight: front == null ? FontWeight.w800 : null,
                      color: front == null ? null : colors.onSurfaceVariant,
                    ),
          ),
          SizedBox(height: 6.h),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: _confidenceColor(
                  r.confidence,
                  colors,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                (r.confidence == DirectionConfidence.good
                        ? 'dir_conf_good'
                        : 'dir_conf_fair')
                    .tr(),
                style: textTheme.labelMedium?.copyWith(
                  color: _confidenceColor(r.confidence, colors),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (turnHint != null) ...[
            SizedBox(height: AppDimens.spacingSmall),
            Text(
              turnHint,
              key: const Key('dir_turn_hint'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: 4.h),
          Text(
            'dir_then_walk'.tr(),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (front == null) ...[
            SizedBox(height: 6.h),
            _FrontButton(state: state, onSetFront: onSetFront),
          ],
        ],
        SizedBox(height: AppDimens.spacingSmall),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('dir_again'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(AppDimens.buttonHeight),
                ),
                onPressed: onAgain,
                icon: const Icon(Icons.replay_rounded),
                label: Text('dir_again'.tr()),
              ),
            ),
            SizedBox(width: AppDimens.spacingSmall),
            Expanded(
              child: FilledButton(
                key: const Key('dir_done'),
                style: _big(),
                onPressed: onClose,
                child: Text('dir_done'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Heading-up compass: the top of the dial is where the phone points.
/// Shows N/E/S/W, the front of the hall, the signal measured per
/// direction, and (when done) an arrow towards the device.
class CompassRosePainter extends CustomPainter {
  CompassRosePainter({
    required this.heading,
    required this.frontHeading,
    required this.levels,
    required this.bearing,
    required this.arrowColor,
    required this.ring,
    required this.text,
    required this.accent,
    required this.letters,
    required this.frontLabel,
  });

  final double? heading;
  final double? frontHeading;
  final List<double?> levels;
  final double? bearing;
  final Color arrowColor;
  final Color ring;
  final Color text;
  final Color accent;

  /// N, E, S, W in the current language.
  final List<String> letters;
  final String frontLabel;

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final h = heading ?? 0;
    // World angle → screen angle: heading-up, 0° at the top.
    double screen(double worldDeg) => _rad(worldDeg - h - 90);
    Offset at(double worldDeg, double radius) =>
        c +
        Offset(math.cos(screen(worldDeg)), math.sin(screen(worldDeg))) * radius;

    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
    for (var d = 0; d < 360; d += 10) {
      final major = d % 90 == 0;
      canvas.drawLine(
        at(d.toDouble(), r - 4),
        at(d.toDouble(), r - (major ? 16 : 10)),
        Paint()
          ..strokeWidth = major ? 2.5 : 1
          ..color = major ? text : ring,
      );
    }
    for (var i = 0; i < 4; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: TextStyle(
            color: i == 0 ? Colors.red.shade400 : text,
            fontWeight: FontWeight.bold,
            fontSize: r * 0.11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at(i * 90.0, r - 30) - tp.size.center(Offset.zero));
    }

    // Signal per direction: longer = stronger.
    final known = [for (final l in levels) ?l];
    if (known.length >= 2) {
      final lo = known.reduce(math.min);
      final hi = known.reduce(math.max);
      final span = math.max(hi - lo, 3.0);
      final inner = r * 0.18;
      final outer = r * 0.66;
      for (var i = 0; i < levels.length; i++) {
        final l = levels[i];
        if (l == null) continue;
        final t = ((l - lo) / span).clamp(0.0, 1.0);
        final len = inner + (outer - inner) * (0.15 + 0.85 * t);
        final mid = (i + 0.5) * DirectionFinder.binDegrees;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..arcTo(
            Rect.fromCircle(center: c, radius: len),
            screen(mid - DirectionFinder.binDegrees / 2),
            _rad(DirectionFinder.binDegrees),
            false,
          )
          ..close();
        canvas.drawPath(
          path,
          Paint()..color = accent.withValues(alpha: 0.18 + 0.5 * t),
        );
      }
    }

    // Front of the hall.
    final front = frontHeading;
    if (front != null) {
      final p = at(front, r - 46);
      final tp = TextPainter(
        text: TextSpan(
          text: frontLabel,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: r * 0.08,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromCenter(
        center: p,
        width: tp.width + 10,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(6)),
        Paint()..color = accent.withValues(alpha: 0.15),
      );
      tp.paint(canvas, p - tp.size.center(Offset.zero));
    }

    // Arrow towards the device.
    final b = bearing;
    if (b != null) {
      final tip = at(b, r * 0.78);
      final base = at(b + 180, r * 0.12);
      final paint = Paint()
        ..color = arrowColor
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(base, tip, paint);
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(at(b - 8, r * 0.6).dx, at(b - 8, r * 0.6).dy)
        ..lineTo(at(b + 8, r * 0.6).dx, at(b + 8, r * 0.6).dy)
        ..close();
      canvas.drawPath(head, Paint()..color = arrowColor);
    }

    // "You face here" marker, fixed at the top.
    final top = Path()
      ..moveTo(c.dx, 20)
      ..lineTo(c.dx - 10, 0)
      ..lineTo(c.dx + 10, 0)
      ..close();
    canvas.drawPath(top, Paint()..color = accent);
    canvas.drawCircle(c, 5, Paint()..color = text);
  }

  @override
  bool shouldRepaint(CompassRosePainter old) =>
      old.heading != heading ||
      old.frontHeading != frontHeading ||
      old.levels != levels ||
      old.bearing != bearing ||
      old.arrowColor != arrowColor;
}
