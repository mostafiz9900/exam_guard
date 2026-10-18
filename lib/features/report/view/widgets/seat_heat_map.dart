import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/report/view/widgets/severity_style.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';

/// The room's seats colored by their highest incident severity, with the
/// incident count. Seats with incidents can be tapped.
class SeatHeatMap extends StatelessWidget {
  const SeatHeatMap({
    super.key,
    required this.rows,
    required this.cols,
    required this.summaries,
    required this.onSeatTap,
  });

  final int rows;
  final int cols;
  final Map<String, SeatSummary> summaries;
  final ValueChanged<String> onSeatTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelWidth = 22.w;
    const gap = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the width when possible; otherwise scroll sideways.
        final fit = (constraints.maxWidth - labelWidth) / cols - gap;
        final cell = math.max(30.0, math.min(48.0, fit));
        final gridWidth = labelWidth + cols * (cell + gap);

        Widget axis(String text, double width, double height) => SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

        Widget seat(int r, int c) {
          final id = SeatId.format(r, c);
          final summary = summaries[id];
          final accent = summary == null
              ? null
              : reportSeverityColor(summary.highestSeverity);
          return Padding(
            padding: const EdgeInsets.all(gap / 2),
            child: Tooltip(
              message: id,
              child: Material(
                color:
                    accent?.withValues(alpha: 0.85) ??
                    colors.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                  side: BorderSide(color: accent ?? colors.outlineVariant),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6.r),
                  onTap: summary == null ? null : () => onSeatTap(id),
                  child: SizedBox(
                    width: cell,
                    height: cell,
                    child: Center(
                      child: Text(
                        summary == null ? '' : '${summary.count}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: gridWidth,
              padding: EdgeInsets.symmetric(vertical: 6.h),
              margin: EdgeInsets.only(bottom: 4.h),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.co_present_rounded,
                    size: 16.w,
                    color: colors.onSecondaryContainer,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'report_seat_front'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                SizedBox(width: labelWidth),
                for (var c = 0; c < cols; c++)
                  axis(SeatId.colLabel(c), cell + gap, 18),
              ],
            ),
            for (var r = 0; r < rows; r++)
              Row(
                children: [
                  axis(SeatId.rowLabel(r), labelWidth, cell + gap),
                  for (var c = 0; c < cols; c++) seat(r, c),
                ],
              ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: grid,
            ),
            SizedBox(height: AppDimens.spacingSmall),
            Wrap(
              spacing: AppDimens.spacingSmall,
              runSpacing: 4.h,
              children: [
                for (final s in LogSeverity.values)
                  _LegendItem(
                    color: reportSeverityColor(s),
                    label: reportSeverityLabel(s),
                  ),
                _LegendItem(
                  color: colors.surfaceContainerHighest,
                  border: colors.outlineVariant,
                  label: 'report_legend_none'.tr(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: border ?? color),
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
