import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/rf_dial.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/rf_wave_painter.dart';

/// The strongest signal over the last 10 seconds, over the same green /
/// amber / red zones as the dial (scale -100 … -20 dBm, as [RfWavePainter]).
class RfHistoryChart extends StatelessWidget {
  const RfHistoryChart({
    super.key,
    required this.history,
    required this.color,
    required this.isMeasuring,
  });

  final List<double> history;
  final Color color;
  final bool isMeasuring;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'rf_history_title'.tr(),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              (isMeasuring ? 'rf_history_live' : 'rf_history_stopped').tr(),
              style: label?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: AppDimens.spacingSmall),
        SizedBox(
          height: 96.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  child: CustomPaint(
                    painter: _ZonesPainter(dim: !isMeasuring),
                    foregroundPainter: RfWavePainter(
                      history: history,
                      color: color,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('rf_scale_close'.tr(), style: label),
                  Text('rf_scale_far'.tr(), style: label),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        Text('rf_history_window'.tr(), style: label),
      ],
    );
  }
}

class _ZonesPainter extends CustomPainter {
  _ZonesPainter({required this.dim});

  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    // Same scale as RfWavePainter: -100 (bottom) … -20 dBm (top).
    double y(double dbm) => size.height - (dbm + 100) / 80 * size.height;
    final alpha = dim ? 0.05 : 0.12;
    void band(double from, double to, Color c) => canvas.drawRect(
      Rect.fromLTRB(0, y(to), size.width, y(from)),
      Paint()..color = c.withValues(alpha: alpha),
    );
    band(-100, -70, RfColors.quiet);
    band(-70, -50, RfColors.moderate);
    band(-50, -20, RfColors.strong);
  }

  @override
  bool shouldRepaint(_ZonesPainter old) => old.dim != dim;
}
