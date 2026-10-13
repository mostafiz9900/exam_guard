import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/core/navigation/app_router.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionViewModelProvider).value;
    final logs = session?.deviceLogs ?? const <ActionLogModel>[];
    final reportState = ref.watch(reportViewModelProvider);

    ref.listen(reportViewModelProvider, (previous, next) {
      final message = next.message;
      if (message != null && message != previous?.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
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
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export PDF Report',
            onPressed: session == null
                ? null
                : () => ref
                      .read(reportViewModelProvider.notifier)
                      .exportPdf(session),
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
                                  session?.instituteName ?? 'No session',
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
                                      ? 'VIOLATIONS FOUND'
                                      : 'NO MAJOR VIOLATIONS',
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              MetaInfo(
                                label: 'Room Number',
                                value: session?.roomNumber ?? '-',
                              ),
                              MetaInfo(
                                label: 'Inspector',
                                value: session?.teacherName ?? '-',
                              ),
                              MetaInfo(
                                label: 'Total Logs',
                                value: '${logs.length} Incidents',
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
                          title: 'Critical Violations',
                          count: '$criticalCount',
                          color: const Color(0xFFEF4444),
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                      SizedBox(width: AppDimens.spacingSmall),
                      Expanded(
                        child: MetricCard(
                          title: 'High Threats',
                          count: '$highCount',
                          color: const Color(0xFFF97316),
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      SizedBox(width: AppDimens.spacingSmall),
                      Expanded(
                        child: MetricCard(
                          title: 'Total Logged',
                          count: '${logs.length}',
                          color: Theme.of(context).colorScheme.primary,
                          icon: Icons.assignment_turned_in_rounded,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  Text(
                    'Incident Audit Logs (${logs.length})',
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
                                  'No Incidents Logged',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Exam session conducted smoothly with zero reported violations.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey),
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
                                        log.severity.code,
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
                                      'Location: ${log.location.isEmpty ? 'Desk N/A' : log.location} • MAC: ${log.deviceId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey.shade700,
                                          ),
                                    ),
                                    if (log.notes.isNotEmpty) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Note: ${log.notes}',
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
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  SizedBox(height: AppDimens.spacingLarge),

                  PrimaryButton(
                    label: 'Export & Share PDF Report',
                    isLoading: reportState.isExporting,
                    onPressed: session == null
                        ? null
                        : () => ref
                              .read(reportViewModelProvider.notifier)
                              .exportPdf(session),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  if (session?.endTime == null)
                    OutlinedButton.icon(
                      onPressed: () => context.pushTo(AppRoute.actionNew),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create New Incident Entry'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => context.goTo(AppRoute.sessionSetup),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start New Exam Session'),
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
