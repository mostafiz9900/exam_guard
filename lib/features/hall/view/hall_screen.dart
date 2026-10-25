import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_alerts_card.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_invite_card.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_members_card.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_node_key_card.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_offline_nodes_card.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_remote_devices_card.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_status_banner.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';

/// Shares one exam hall between invigilator phones and ESP32 sensor nodes:
/// host (QR code) or join (scan it), then see everyone's devices/alerts.
class HallScreen extends ConsumerWidget {
  const HallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hallViewModelProvider);
    final notifier = ref.read(hallViewModelProvider.notifier);

    Future<void> scanAndJoin() async {
      final code = await context.pushTo<String>(AppRoute.hallScan);
      if (code != null) await notifier.join(code);
    }

    Future<void> leave() async {
      final isHost = state.role == HallRole.host;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            (isHost ? 'hall_close_confirm_title' : 'hall_leave_confirm_title')
                .tr(),
          ),
          content: Text(
            (isHost ? 'hall_close_confirm_text' : 'hall_leave_confirm_text')
                .tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text((isHost ? 'hall_close' : 'hall_leave').tr()),
            ),
          ],
        ),
      );
      if (ok == true) await notifier.leave();
    }

    final gap = SizedBox(height: AppDimens.spacingMedium);
    return Scaffold(
      appBar: AppBar(
        title: Text('hall_title'.tr()),
        actions: const [AppSettingsMenu()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: EdgeInsets.all(AppDimens.spacingMedium),
              children: [
                HallStatusBanner(state: state),
                gap,
                if (state.offlineNodes.isNotEmpty) ...[
                  HallOfflineNodesCard(
                    nodes: state.offlineNodes,
                    onDismiss: notifier.dismissOfflineNode,
                  ),
                  gap,
                ],
                if (!state.isActive)
                  _Start(onHost: notifier.host, onJoin: scanAndJoin)
                else ...[
                  if (state.invite case final invite?) ...[
                    HallInviteCard(invite: invite),
                    gap,
                  ],
                  HallMembersCard(members: state.members, selfId: state.selfId),
                  gap,
                  if (state.remoteAlerts.isNotEmpty) ...[
                    HallAlertsCard(
                      alerts: state.remoteAlerts,
                      onAcknowledgeAll: notifier.acknowledgeAllRemoteAlerts,
                    ),
                    gap,
                  ],
                  HallRemoteDevicesCard(devices: state.remoteDevices),
                  gap,
                  if (state.role == HallRole.host) ...[
                    HallNodeKeyCard(
                      nodeKey: state.nodeKey,
                      onRegenerate: notifier.regenerateNodeKey,
                    ),
                    gap,
                  ],
                  OutlinedButton.icon(
                    onPressed: leave,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      (state.role == HallRole.host
                              ? 'hall_close'
                              : 'hall_leave')
                          .tr(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Start extends StatelessWidget {
  const _Start({required this.onHost, required this.onJoin});

  final VoidCallback onHost;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    Widget hint(String key) => Padding(
      padding: EdgeInsets.only(top: 6.h, bottom: AppDimens.spacingMedium),
      child: Text(
        key.tr(),
        textAlign: TextAlign.center,
        style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('hall_intro'.tr(), style: textTheme.bodyMedium),
        SizedBox(height: AppDimens.spacingLarge),
        PrimaryButton(label: 'hall_host'.tr(), onPressed: onHost),
        hint('hall_host_hint'),
        OutlinedButton.icon(
          onPressed: onJoin,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text('hall_join'.tr()),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(AppDimens.buttonHeight),
          ),
        ),
        hint('hall_join_hint'),
        Text(
          'hall_need_network'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
