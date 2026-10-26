import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/session/model/activity_sample.dart';

/// Devices in range (and how many not trusted) over the whole exam.
class ActivityChartCard extends StatelessWidget {
  const ActivityChartCard({
    super.key,
    required this.samples,
    required this.start,
    required this.end,
  });

  final List<ActivitySample> samples;
  final DateTime start;
  final DateTime end;

  static const Color untrustedColor = Color(0xFFD9363E);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final peak = samples.map((s) => s.devices).reduce((a, b) => a > b ? a : b);
    final label = textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    Widget legend(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10.w, height: 3.h, color: c),
        SizedBox(width: 4.w),
        Text(text, style: label),
      ],
    );
    return Card(
      key: const Key('report_activity_chart'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'report_activity_peak'.tr(args: {'count': '$peak'}),
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _ActivityPainter(
                  samples: samples,
                  start: start,
                  end: end,
                  maxY: peak + 1,
                  devices: colors.primary,
                  untrusted: untrustedColor,
                  grid: colors.outlineVariant,
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Text(AppDateFormat.clock(start), style: label),
                const Spacer(),
                Text(AppDateFormat.clock(end), style: label),
              ],
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 14.w,
              runSpacing: 4.h,
              children: [
                legend(colors.primary, 'report_activity_in_range'.tr()),
                legend(untrustedColor, 'report_activity_untrusted'.tr()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({
    required this.samples,
    required this.start,
    required this.end,
    required this.maxY,
    required this.devices,
    required this.untrusted,
    required this.grid,
  });

  final List<ActivitySample> samples;
  final DateTime start;
  final DateTime end;
  final int maxY;
  final Color devices;
  final Color untrusted;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final span = end.difference(start).inMilliseconds;
    if (span <= 0 || maxY <= 0) return;
    double x(DateTime t) =>
        (t.difference(start).inMilliseconds / span).clamp(0.0, 1.0) *
        size.width;
    double y(int v) => size.height - (v / maxY).clamp(0.0, 1.0) * size.height;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = grid,
    );
    void line(int Function(ActivitySample) value, Color color, bool fill) {
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final p = Offset(x(samples[i].at), y(value(samples[i])));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      if (fill) {
        final area = Path.from(path)
          ..lineTo(x(samples.last.at), size.height)
          ..lineTo(x(samples.first.at), size.height)
          ..close();
        canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line((s) => s.devices, devices, true);
    line((s) => s.untrusted, untrusted, false);
  }

  @override
  bool shouldRepaint(_ActivityPainter old) =>
      old.samples != samples || old.devices != devices;
}
