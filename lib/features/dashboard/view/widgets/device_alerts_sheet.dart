import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/features/scanner/view/distance_text.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/model/incident_categories.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Lists every new-device alert with Track / Log incident / Trust /
/// Acknowledge actions. [context] is the dashboard's, used to navigate after
/// the sheet closes.
Future<void> showDeviceAlertsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (sheetContext, controller) => _AlertsSheetBody(
        scrollController: controller,
        onNavigate: (route, extra) {
          Navigator.of(sheetContext).pop();
          if (context.mounted) context.pushTo(route, extra: extra);
        },
      ),
    ),
  );
}

class _AlertsSheetBody extends ConsumerWidget {
  const _AlertsSheetBody({
    required this.scrollController,
    required this.onNavigate,
  });

  final ScrollController scrollController;
  final void Function(String route, Object? extra) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scannerViewModelProvider);
    final notifier = ref.read(scannerViewModelProvider.notifier);
    final alerts = [...state.alerts]
      ..sort((a, b) {
        // Unacknowledged first, then newest first.
        if (a.acknowledged != b.acknowledged) return a.acknowledged ? 1 : -1;
        return b.detectedAt.compareTo(a.detectedAt);
      });
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ScannedDeviceModel? liveDevice(String id) {
      for (final d in state.devices) {
        if (d.id == id) return d;
      }
      return null;
    }

    Future<void> trust(NewDeviceAlert alert) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await Future<void>.sync(() => notifier.trustDevice(alert.deviceId));
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'dash_alert_trusted'.tr(args: {'name': alert.displayName}),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('dash_alert_trust_failed'.tr()),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    void logIncident(NewDeviceAlert alert) {
      final device =
          liveDevice(alert.deviceId) ??
          ScannedDeviceModel(
            id: alert.deviceId,
            name: alert.displayName,
            manufacturer: 'Unknown',
            deviceType: alert.deviceType,
            rssi: alert.rssi,
            lastSeen: alert.detectedAt,
            firstSeen: alert.detectedAt,
            transport: alert.transport,
          );
      notifier.acknowledgeAlert(alert.deviceId);
      onNavigate(
        AppRoute.actionNew,
        ActionEntryArgs(
          device: device,
          category: IncidentCategory.forDevice(device),
        ),
      );
    }

    final pad = AppDimens.spacingMedium;
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(pad, 0, pad, AppDimens.spacingLarge),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notification_important_rounded, color: colors.error),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'dash_alerts_title'.tr(
                  args: {'count': '${state.unacknowledgedAlertCount}'},
                ),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          'dash_alerts_subtitle'.tr(),
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (state.unacknowledgedAlertCount > 0)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: notifier.acknowledgeAll,
              icon: const Icon(Icons.done_all_rounded),
              label: Text('dash_alerts_ack_all'.tr()),
            ),
          )
        else
          SizedBox(height: AppDimens.spacingSmall),
        if (alerts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.spacingLarge),
            child: Text(
              'dash_alerts_empty'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        for (final alert in alerts) ...[
          Builder(
            builder: (context) {
              final device = liveDevice(alert.deviceId);
              final canTrack =
                  alert.transport == DeviceTransport.ble && device != null;
              return _AlertTile(
                alert: alert,
                onTrack: canTrack
                    ? () => onNavigate(AppRoute.radar, device)
                    : null,
                onLogIncident: () => logIncident(alert),
                onTrust: () => trust(alert),
                onAcknowledge: alert.acknowledged
                    ? null
                    : () => notifier.acknowledgeAlert(alert.deviceId),
              );
            },
          ),
          SizedBox(height: AppDimens.spacingSmall),
        ],
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.onTrack,
    required this.onLogIncident,
    required this.onTrust,
    required this.onAcknowledge,
  });

  final NewDeviceAlert alert;

  /// Null when the device can't be tracked (not BLE, or no longer heard).
  final VoidCallback? onTrack;
  final VoidCallback onLogIncident;
  final VoidCallback onTrust;

  /// Null once acknowledged.
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNew = !alert.acknowledged;
    final accent = isNew ? colors.error : colors.onSurfaceVariant;
    final icon = switch (alert.transport) {
      DeviceTransport.ble => Icons.bluetooth_searching_rounded,
      DeviceTransport.classic => Icons.bluetooth_rounded,
      DeviceTransport.wifi => Icons.wifi_tethering_rounded,
    };
    final time = TimeOfDay.fromDateTime(alert.detectedAt).format(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: isNew ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(
          color: isNew
              ? colors.error.withValues(alpha: 0.6)
              : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 22.w),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'dash_alert_tile_detail'.tr(
                          args: {
                            'type': alert.deviceType,
                            'signal': signalSummaryText(
                              alert.rssi,
                              alert.transport,
                            ),
                            'time': time,
                          },
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    isNew
                        ? 'dash_alert_new_badge'.tr()
                        : 'dash_alert_acknowledged'.tr(),
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 4.w,
              runSpacing: 0,
              children: [
                if (alert.transport == DeviceTransport.ble)
                  _Action(
                    icon: Icons.radar_rounded,
                    label: 'track'.tr(),
                    tooltip: onTrack == null
                        ? 'dash_alert_track_unavailable'.tr()
                        : null,
                    onPressed: onTrack,
                  ),
                _Action(
                  icon: Icons.report_problem_rounded,
                  label: 'log_incident'.tr(),
                  color: colors.error,
                  onPressed: onLogIncident,
                ),
                _Action(
                  icon: Icons.verified_user_outlined,
                  label: 'dash_alert_trust'.tr(),
                  onPressed: onTrust,
                ),
                if (onAcknowledge != null)
                  _Action(
                    icon: Icons.check_rounded,
                    label: 'dash_alert_acknowledge'.tr(),
                    onPressed: onAcknowledge,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
      ),
      icon: Icon(icon, size: 16.w),
      label: Text(label),
    );
    final message = tooltip;
    return message == null ? button : Tooltip(message: message, child: button);
  }
}
