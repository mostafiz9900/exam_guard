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
import 'package:exam_guard/features/report/view/widgets/incident_log_card.dart';
import 'package:exam_guard/features/report/view/widgets/meta_info.dart';
import 'package:exam_guard/features/report/view/widgets/metric_card.dart';
import 'package:exam_guard/features/report/view/widgets/seat_heat_map.dart';
import 'package:exam_guard/features/report/view/widgets/severity_style.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

class ReportSummaryScreen extends ConsumerWidget {
  const ReportSummaryScreen({super.key});

  /// Global rect of the tapped widget, used to anchor the iPad share popover.
  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '-' : value;

  /// Lists the incidents recorded at [seat].
  static Future<void> _showSeatIncidents(
    BuildContext context,
    WidgetRef ref,
    SessionModel session,
    String seat,
  ) {
    final incidents = ref
        .read(reportViewModelProvider.notifier)
        .incidentsAtSeat(session, seat);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
              AppDimens.spacingMedium,
              0,
              AppDimens.spacingMedium,
              AppDimens.spacingLarge,
            ),
            children: [
              Text(
                'report_seat_incidents_title'.tr(
                  args: {'seat': seat, 'count': '${incidents.length}'},
                ),
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppDimens.spacingSmall),
              if (incidents.isEmpty)
                Text('report_seat_no_incidents'.tr())
              else
                for (final log in incidents) ...[
                  IncidentLogCard(log: log),
                  SizedBox(height: AppDimens.spacingExtraSmall),
                ],
            ],
          ),
        ),
      ),
    );
  }

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
                          if (session != null) ...[
                            SizedBox(height: AppDimens.spacingSmall),
                            Row(
                              children: [
                                Icon(
                                  session.hasBaseline
                                      ? Icons.verified_outlined
                                      : Icons.info_outline_rounded,
                                  size: 16.w,
                                  color: session.hasBaseline
                                      ? AppColors.success
                                      : colors.onSurfaceVariant,
                                ),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    session.baselineAt == null
                                        ? 'report_baseline_none'.tr()
                                        : 'report_baseline_taken'.tr(
                                            args: {
                                              'time': AppDateFormat.clock(
                                                session.baselineAt!,
                                              ),
                                              'count':
                                                  '${session.trustedDeviceIds.length}',
                                            },
                                          ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
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
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Threat Breakdown Cards
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'report_critical_violations'.tr(),
                          count: '$criticalCount',
                          color: reportSeverityColor(LogSeverity.critical),
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                      SizedBox(width: AppDimens.spacingSmall),
                      Expanded(
                        child: MetricCard(
                          title: 'report_high_threats'.tr(),
                          count: '$highCount',
                          color: reportSeverityColor(LogSeverity.high),
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

                  if (session != null && session.hasSeatLayout) ...[
                    Text(
                      'report_seat_map'.tr(),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'report_seat_map_hint'.tr(),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    SizedBox(height: AppDimens.spacingSmall),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppDimens.spacingSmall),
                        child: SeatHeatMap(
                          rows: session.seatRows!,
                          cols: session.seatCols!,
                          summaries: ref
                              .read(reportViewModelProvider.notifier)
                              .seatSummaries(session),
                          onSeatTap: (seat) =>
                              _showSeatIncidents(context, ref, session, seat),
                        ),
                      ),
                    ),
                    SizedBox(height: AppDimens.spacingLarge),
                  ],
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
                          itemBuilder: (_, index) =>
                              IncidentLogCard(log: logs[index]),
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
