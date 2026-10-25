import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';

/// Accent of seats that already have incidents, by their highest severity.
Color seatSeverityColor(LogSeverity severity) => switch (severity) {
  LogSeverity.critical => AppColors.error,
  LogSeverity.high => const Color(0xFFF97316),
  LogSeverity.medium => const Color(0xFFF59E0B),
  LogSeverity.low => const Color(0xFF10B981),
};

/// Shows the room's seat map and returns the tapped seat id (e.g. "C4"),
/// or null when dismissed.
Future<String?> showSeatPickerSheet(
  BuildContext context, {
  required int rows,
  required int cols,
  required Map<String, SeatSummary> summaries,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusLarge),
      ),
    ),
    builder: (_) => _SeatPickerSheet(
      rows: rows,
      cols: cols,
      summaries: summaries,
      selected: selected,
    ),
  );
}

class _SeatPickerSheet extends StatelessWidget {
  const _SeatPickerSheet({
    required this.rows,
    required this.cols,
    required this.summaries,
    this.selected,
  });

  final int rows;
  final int cols;
  final Map<String, SeatSummary> summaries;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cell = 44.w.clamp(38.0, 52.0);
    final gap = 4.w;
    final labelWidth = 24.w;

    Widget axisLabel(String text, {double? width, double? height}) => SizedBox(
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
      final isSelected = id == selected;
      final accent = summary == null
          ? null
          : seatSeverityColor(summary.highestSeverity);

      return Padding(
        padding: EdgeInsets.all(gap / 2),
        child: Material(
          color: isSelected
              ? colors.primary
              : accent?.withValues(alpha: 0.18) ??
                    colors.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            side: BorderSide(
              color: isSelected
                  ? colors.primary
                  : accent ?? colors.outlineVariant,
              width: accent != null || isSelected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            onTap: () => Navigator.of(context).pop(id),
            child: SizedBox(
              width: cell,
              height: cell,
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      id,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? colors.onPrimary : colors.onSurface,
                      ),
                    ),
                  ),
                  if (summary != null)
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '${summary.count}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
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

    final gridWidth = labelWidth + cols * (cell + gap);

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Front of the room.
        Container(
          width: gridWidth,
          margin: EdgeInsets.only(bottom: AppDimens.spacingExtraSmall),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.co_present_rounded,
                size: 18.w,
                color: colors.onSecondaryContainer,
              ),
              SizedBox(width: 6.w),
              // Small rooms make the banner narrower than the label.
              Flexible(
                child: Text(
                  'incident_seat_front'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            SizedBox(width: labelWidth),
            for (var c = 0; c < cols; c++)
              axisLabel(SeatId.colLabel(c), width: cell + gap),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              axisLabel(SeatId.rowLabel(r), width: labelWidth),
              for (var c = 0; c < cols; c++) seat(r, c),
            ],
          ),
      ],
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimens.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'incident_seat_map_title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'incident_seat_map_hint'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (summaries.isNotEmpty) ...[
                    SizedBox(height: AppDimens.spacingExtraSmall),
                    Row(
                      children: [
                        Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            color: seatSeverityColor(LogSeverity.high)
                                .withValues(alpha: 0.18),
                            border: Border.all(
                              color: seatSeverityColor(LogSeverity.high),
                            ),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'incident_seat_has_incidents'.tr(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.spacingMedium,
                    0,
                    AppDimens.spacingMedium,
                    AppDimens.spacingLarge,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth:
                            constraints.maxWidth - 2 * AppDimens.spacingMedium,
                      ),
                      child: Center(child: grid),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
