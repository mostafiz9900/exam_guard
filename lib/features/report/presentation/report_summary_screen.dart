import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/logger/app_logger.dart';
import '../../../core/services/report/session_report_pdf_service.dart';
import '../../../core/services/share/i_share_service.dart';
import '../../session/application/session_provider.dart';
import '../../session/domain/session_model.dart';

class ReportSummaryScreen extends ConsumerWidget {
  const ReportSummaryScreen({super.key});

  Color _getSeverityColor(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFEF4444);
      case 'HIGH':
        return const Color(0xFFF97316);
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      case 'LOW':
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final logs = session?.deviceLogs ?? const [];

    final criticalCount = logs.where((l) => l['severity'] == 'CRITICAL').length;
    final highCount = logs.where((l) => l['severity'] == 'HIGH').length;
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
                : () => _exportPdf(context, ref, session),
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
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusLarge),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
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
                                  hasViolations ? 'VIOLATIONS FOUND' : 'NO MAJOR VIOLATIONS',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
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
                              _MetaInfo(
                                label: 'Room Number',
                                value: session?.roomNumber ?? '-',
                              ),
                              _MetaInfo(
                                label: 'Inspector',
                                value: session?.teacherName ?? '-',
                              ),
                              _MetaInfo(
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
                        child: _MetricCard(
                          title: 'Critical Violations',
                          count: '$criticalCount',
                          color: const Color(0xFFEF4444),
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                      SizedBox(width: AppDimens.spacingSmall),
                      Expanded(
                        child: _MetricCard(
                          title: 'High Threats',
                          count: '$highCount',
                          color: const Color(0xFFF97316),
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      SizedBox(width: AppDimens.spacingSmall),
                      Expanded(
                        child: _MetricCard(
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: AppDimens.spacingSmall),

                  logs.isEmpty
                      ? Card(
                          elevation: 1,
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingExtraLarge),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Exam session conducted smoothly with zero reported violations.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
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
                            final severity = log['severity'] as String? ?? 'LOW';
                            final color = _getSeverityColor(severity);
                            final timestamp = log['createdAt'] != null
                                ? DateTime.fromMillisecondsSinceEpoch(
                                    log['createdAt'] as int,
                                  )
                                : DateTime.now();

                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppDimens.radiusMedium),
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
                                        log['name'] as String? ?? 'Unknown Device',
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
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        severity,
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
                                      'Location: ${log['location'] ?? 'Desk N/A'} • MAC: ${log['id'] ?? 'N/A'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey.shade700),
                                    ),
                                    if (log['notes'] != null &&
                                        (log['notes'] as String).isNotEmpty) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Note: ${log['notes']}',
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
                                      DateFormat('MMM d, hh:mm a')
                                          .format(timestamp),
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
                    onPressed: session == null
                        ? null
                        : () => _exportPdf(context, ref, session),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  if (session?.endTime == null)
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoute.actionNew),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create New Incident Entry'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoute.sessionSetup),
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

Future<void> _exportPdf(
  BuildContext context,
  WidgetRef ref,
  SessionModel session,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes =
        await ref.read(sessionReportPdfServiceProvider).build(session);
    final date = session.startTime.toIso8601String().substring(0, 10);
    final outcome = await ref.read(shareServiceProvider).shareFile(
          bytes: bytes,
          fileName: 'examguard_room_${session.roomNumber}_$date.pdf',
          mimeType: 'application/pdf',
          subject: 'ExamGuard report — Room ${session.roomNumber}',
        );
    if (outcome == ShareOutcome.unavailable) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sharing is not available on this device')),
      );
    }
  } catch (e, st) {
    ref.read(appLoggerProvider).error('PDF export failed', e, st);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not export report: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

class _MetaInfo extends StatelessWidget {
  const _MetaInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final String count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22.w),
            SizedBox(height: 6.h),
            Text(
              count,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            SizedBox(height: 2.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
