import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/history/model/history_entry.dart';

/// One past exam: room, institute, date, duration and incident counts.
class HistoryEntryCard extends StatelessWidget {
  const HistoryEntryCard({super.key, required this.entry, this.onTap});

  final HistoryEntry entry;

  /// Null when the report can't be opened (exam still running).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final room = entry.roomNumber.isEmpty
        ? '—'
        : 'room'.tr(args: {'room': entry.roomNumber});

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingMedium),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.meeting_room_rounded,
                  size: 22.w,
                  color: colors.primary,
                ),
              ),
              SizedBox(width: AppDimens.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            room,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (entry.isRunning) ...[
                          SizedBox(width: 6.w),
                          _Pill(
                            label: 'history_running'.tr(),
                            color: AppColors.success,
                            icon: Icons.circle,
                          ),
                        ],
                      ],
                    ),
                    if (entry.instituteName.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        entry.instituteName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Meta(
                          icon: Icons.event_rounded,
                          text: AppDateFormat.shortDateTime(entry.startTime),
                        ),
                        _Meta(
                          icon: Icons.timer_outlined,
                          text: AppDateFormat.duration(entry.duration),
                        ),
                        _Meta(
                          icon: Icons.assignment_outlined,
                          text: 'incidents_count'.tr(
                            args: {'count': '${entry.incidentCount}'},
                          ),
                        ),
                        if (entry.criticalCount > 0)
                          _Pill(
                            label: 'history_critical_count'.tr(
                              args: {'count': '${entry.criticalCount}'},
                            ),
                            color: colors.error,
                            icon: Icons.priority_high_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.w, color: color),
        SizedBox(width: 3.w),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9.w, color: color),
          SizedBox(width: 3.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
