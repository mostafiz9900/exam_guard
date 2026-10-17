import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/report/view_model/report_view_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/report/view/widgets/meta_info.dart';
import 'package:exam_guard/features/report/view/widgets/metric_card.dart';

class ReportSummaryScreen extends ConsumerWidget {
  const ReportSummaryScreen({super.key});

  Color _getSeverityColor(LogSeverity severity) {
    switch (severity) {
      case LogSeverity.critical:
        return const Color(0xFFEF4444);
      case LogSeverity.high:
        return const Color(0xFFF97316);
      case LogSeverity.medium:
        return const Color(0xFFF59E0B);
      case LogSeverity.low:
        return const Color(0xFF10B981);
    }
  }

  /// Global rect of the tapped widget, used to anchor the iPad share popover.
  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static String _severityLabel(LogSeverity severity) => switch (severity) {
    LogSeverity.critical => 'report_severity_critical'.tr(),
    LogSeverity.high => 'report_severity_high'.tr(),
    LogSeverity.medium => 'report_severity_medium'.tr(),
    LogSeverity.low => 'report_severity_low'.tr(),
  };

  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '-' : value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final session = ref.watch(sessionViewModelProvider);
    final logs = session?.deviceLogs ?? const <ActionLogModel>[];
    final reportState = ref.watch(reportViewModelProvider);

    ref.listen(reportViewModelProvider, (previous, next) {
      final messageKey = next.messageKey;
      if (messageKey != null && messageKey != previous?.messageKey) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messageKey.tr()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    final criticalCount = logs
        .where((l) => l.severity == LogSeverity.critical)
        .length;
    final highCount = logs.where((l) => l.severity == LogSeverity.high).length;
    final hasViolations = criticalCount + highCount > 0;
    final statusColor = hasViolations ? AppColors.error : AppColors.success;

    return Scaffold(
      appBar: AppBar(
        title: Text('report_summary'.tr()),
        actions: [
          Builder(
            builder: (buttonContext) => IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'report_export_tooltip'.tr(),
              onPressed: session == null
                  ? null
                  : () => ref
                        .read(reportViewModelProvider.notifier)
                        .exportPdf(session, origin: _originOf(buttonContext)),
            ),
          ),
          const AppSettingsMenu(),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Session Overview Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusLarge,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppDimens.spacingMedium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.school_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24.w,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  session == null
                                      ? 'report_no_session'.tr()
                                      : _orDash(session.instituteName),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  hasViolations
                                      ? 'report_status_violations'.tr()
                                      : 'report_status_clear'.tr(),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Wrap(
                            spacing: AppDimens.spacingLarge,
                            runSpacing: AppDimens.spacingSmall,
                            children: [
                              MetaInfo(
                                label: 'room_number'.tr(),
                                value: _orDash(session?.roomNumber),
                              ),
                              MetaInfo(
                                label: 'report_inspector'.tr(),
                                value: _orDash(session?.teacherName),
                              ),
                              MetaInfo(
                                label: 'report_started'.tr(),
                                value: session == null
                                    ? '-'
                                    : AppDateFormat.shortDateTime(
                                        session.startTime,
                                      ),
                              ),
                              MetaInfo(
                                label: 'report_ended'.tr(),
                                value: session == null
                                    ? '-'
                                    : session.endTime == null
                                    ? 'report_in_progress'.tr()
                                    : AppDateFormat.shortDateTime(
                                        session.endTime!,
                                      ),
                              ),
                              MetaInfo(
                                label: 'report_duration'.tr(),
                                value: session == null
                                    ? '-'
                                    : AppDateFormat.duration(session.duration),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Threat Breakdown Cards
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'report_critical_violations'.tr(),
                          count: '$criticalCount',
                          color: _getSeverityColor(LogSeverity.critical),
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                      SizedBox(width: AppDimens.spacingSmall),
                      Expanded(
                        child: MetricCard(
                          title: 'report_high_threats'.tr(),
                          count: '$highCount',
                          color: _getSeverityColor(LogSeverity.high),
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      SizedBox(width: AppDimens.spacingSmall),
                      Expanded(
                        child: MetricCard(
                          title: 'report_total_logged'.tr(),
                          count: '${logs.length}',
                          color: colors.primary,
                          icon: Icons.assignment_turned_in_rounded,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  Text(
                    'report_incident_logs'.tr(
                      args: {'count': '${logs.length}'},
                    ),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: AppDimens.spacingSmall),

                  logs.isEmpty
                      ? Card(
                          elevation: 1,
                          child: Padding(
                            padding: EdgeInsets.all(
                              AppDimens.spacingExtraLarge,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 48.w,
                                  color: AppColors.success,
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'report_empty_title'.tr(),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'report_empty_message'.tr(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: logs.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: AppDimens.spacingSmall),
                          itemBuilder: (_, index) {
                            final log = logs[index];
                            final color = _getSeverityColor(log.severity);

                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusMedium,
                                ),
                                side: BorderSide(
                                  color: color.withValues(alpha: 0.2),
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: 0.12),
                                  ),
                                  child: Icon(
                                    Icons.report_problem_rounded,
                                    color: color,
                                    size: 20.w,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log.deviceName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      child: Text(
                                        _severityLabel(log.severity),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4.h),
                                    Text(
                                      'report_log_details'.tr(
                                        args: {
                                          'location':
                                              log.location.trim().isEmpty
                                              ? 'report_not_recorded'.tr()
                                              : log.location,
                                          'id': _orDash(log.deviceId),
                                        },
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    if (log.notes.isNotEmpty) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        'report_note'.tr(
                                          args: {'note': log.notes},
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ],
                                    SizedBox(height: 4.h),
                                    Text(
                                      AppDateFormat.shortDateTime(
                                        log.createdAt,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  SizedBox(height: AppDimens.spacingLarge),

                  Builder(
                    builder: (buttonContext) => PrimaryButton(
                      label: 'report_export_share'.tr(),
                      isLoading: reportState.isExporting,
                      onPressed: session == null
                          ? null
                          : () => ref
                                .read(reportViewModelProvider.notifier)
                                .exportPdf(
                                  session,
                                  origin: _originOf(buttonContext),
                                ),
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  if (session?.endTime == null)
                    OutlinedButton.icon(
                      onPressed: () => context.pushTo(AppRoute.actionNew),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('report_new_incident'.tr()),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => context.goTo(AppRoute.sessionSetup),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('report_new_session'.tr()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
