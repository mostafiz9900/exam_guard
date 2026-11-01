import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/node_setup/view/widgets/node_guide_cards.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// Home of the ESP32 sensor nodes: which are live in the hall, whether the
/// hall is ready for them, how to add one, and what to buy.
class SensorNodesScreen extends ConsumerWidget {
  const SensorNodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hall = ref.watch(hallViewModelProvider);
    final examRunning = ref.watch(
      sessionViewModelProvider.select((s) => s?.isActive ?? false),
    );
    final nodes = [
      for (final m in hall.members)
        if (m.kind == HallMemberKind.node) m,
    ];
    final hasAny = nodes.isNotEmpty || hall.offlineNodes.isNotEmpty;
    final gap = SizedBox(height: AppDimens.spacingMedium);

    return Scaffold(
      appBar: AppBar(title: Text('node_title'.tr())),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: EdgeInsets.all(AppDimens.spacingMedium),
              children: [
                _Header(live: nodes.length, offline: hall.offlineNodes.length),
                gap,
                _HallReadiness(state: hall, examRunning: examRunning),
                if (hasAny) ...[gap, _NodeList(state: hall, nodes: nodes)],
                gap,
                FilledButton.icon(
                  key: const Key('node_add_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(AppDimens.buttonHeight),
                  ),
                  onPressed: () => context.pushTo(AppRoute.nodeAdd),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text('node_add'.tr()),
                ),
                if (examRunning) ...[
                  SizedBox(height: AppDimens.spacingSmall),
                  OutlinedButton.icon(
                    key: const Key('node_map_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(AppDimens.buttonHeight),
                    ),
                    onPressed: () => context.pushTo(AppRoute.hallMap),
                    icon: const Icon(Icons.map_outlined),
                    label: Text('hall_map_open'.tr()),
                  ),
                ],
                SizedBox(height: 6.h),
                Text(
                  'node_add_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppDimens.spacingLarge),
                Text(
                  'node_guide_heading'.tr(),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: AppDimens.spacingSmall),
                NodeShoppingCard(initiallyExpanded: !hasAny),
                SizedBox(height: AppDimens.spacingSmall),
                const NodeFirmwareCard(),
                SizedBox(height: AppDimens.spacingSmall),
                const NodeLedCard(),
                SizedBox(height: AppDimens.spacingSmall),
                const NodePlacementCard(),
                SizedBox(height: AppDimens.spacingSmall),
                _NodeKeyRow(nodeKey: hall.nodeKey),
                SizedBox(height: AppDimens.spacingLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.live, required this.offline});

  final int live;
  final int offline;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = offline > 0
        ? colors.error
        : live > 0
        ? AppColors.success
        : colors.primary;
    final text = live == 0 && offline == 0
        ? 'node_header_none'.tr()
        : offline > 0
        ? 'node_header_offline'.tr(
            args: {'live': '$live', 'offline': '$offline'},
          )
        : 'node_header_live'.tr(args: {'count': '$live'});
    return Container(
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), colors.surfaceContainerLow],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              offline > 0 ? Icons.sensors_off_rounded : Icons.sensors_rounded,
              color: color,
              size: 30.w,
            ),
          ),
          SizedBox(width: AppDimens.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'node_header_title'.tr(),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  text,
                  key: const Key('node_header_text'),
                  style: textTheme.bodySmall?.copyWith(
                    color: offline > 0 ? colors.error : colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nodes only report to a hosted hall: say whether this phone is ready.
class _HallReadiness extends ConsumerWidget {
  const _HallReadiness({required this.state, required this.examRunning});

  final HallState state;
  final bool examRunning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hosting = state.role == HallRole.host && state.status.isLive;
    final (IconData icon, Color color, String title, String text) = !examRunning
        ? (
            Icons.schedule_rounded,
            colors.onSurfaceVariant,
            'node_ready_no_exam_title'.tr(),
            'node_ready_no_exam_text'.tr(),
          )
        : hosting
        ? (
            Icons.check_circle_rounded,
            AppColors.success,
            'node_ready_hosting_title'.tr(),
            'node_ready_hosting_text'.tr(),
          )
        : state.role == HallRole.member
        ? (
            Icons.info_outline_rounded,
            colors.primary,
            'node_ready_member_title'.tr(),
            'node_ready_member_text'.tr(),
          )
        : (
            Icons.warning_amber_rounded,
            Colors.orange.shade700,
            'node_ready_not_hosting_title'.tr(),
            'node_ready_not_hosting_text'.tr(),
          );
    final canHost = examRunning && !state.isActive;
    final starting = state.status == HallLinkStatus.starting;

    return Card(
      key: const Key('node_readiness'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        text,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.errorKey != null && !state.isActive) ...[
              SizedBox(height: AppDimens.spacingSmall),
              Text(
                state.errorKey!.tr(),
                style: textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            if (canHost || starting) ...[
              SizedBox(height: AppDimens.spacingSmall),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonalIcon(
                  key: const Key('node_host_button'),
                  onPressed: starting
                      ? null
                      : () => ref.read(hallViewModelProvider.notifier).host(),
                  icon: starting
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.hub_rounded),
                  label: Text('hall_host'.tr()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NodeList extends StatelessWidget {
  const _NodeList({required this.state, required this.nodes});

  final HallState state;
  final List<HallMember> nodes;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget row({
      required String name,
      required String status,
      required Color color,
      required IconData icon,
      VoidCallback? onDismiss,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(status, style: TextStyle(color: color)),
      trailing: onDismiss == null
          ? null
          : IconButton(
              tooltip: 'hall_node_dismiss'.tr(),
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimens.spacingMedium,
          vertical: AppDimens.spacingSmall,
        ),
        child: Consumer(
          builder: (context, ref, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'node_list_title'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final n in nodes)
                row(
                  name: n.name,
                  status: 'node_status_live'.tr(
                    args: {
                      'count':
                          '${state.remoteDevices.where((d) => d.sourceId == n.id).length}',
                    },
                  ),
                  color: AppColors.success,
                  icon: Icons.sensors_rounded,
                ),
              for (final o in state.offlineNodes)
                row(
                  name: o.member.name,
                  status: 'node_status_offline'.tr(
                    args: {
                      'time': TimeOfDay.fromDateTime(o.since).format(context),
                    },
                  ),
                  color: colors.error,
                  icon: Icons.sensors_off_rounded,
                  onDismiss: () => ref
                      .read(hallViewModelProvider.notifier)
                      .dismissOfflineNode(o.member.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The key the app sends to nodes by itself; shown for the web-page
/// fallback setup.
class _NodeKeyRow extends StatelessWidget {
  const _NodeKeyRow({required this.nodeKey});

  final String nodeKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMedium,
        vertical: AppDimens.spacingSmall,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: colors.onSurfaceVariant, size: 20.w),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'hall_node_key'.tr(args: {'key': nodeKey}),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'node_key_auto'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'hall_copy'.tr(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: nodeKey));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('hall_copied'.tr())));
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}
