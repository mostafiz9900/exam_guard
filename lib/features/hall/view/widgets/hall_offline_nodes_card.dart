import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';

/// Sensor nodes that left the hall: switched off, unplugged, out of Wi-Fi,
/// or tampered with. Red until they return or are dismissed on purpose.
class HallOfflineNodesCard extends StatelessWidget {
  const HallOfflineNodesCard({
    super.key,
    required this.nodes,
    required this.onDismiss,
  });

  final List<OfflineNode> nodes;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.errorContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMedium,
              ),
              child: Text(
                'hall_nodes_offline_title'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            for (final n in nodes)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.sensors_off_rounded,
                  color: colors.onErrorContainer,
                ),
                title: Text(
                  n.member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
                subtitle: Text(
                  'hall_node_offline_since'.tr(
                    args: {'time': AppDateFormat.clock(n.since)},
                  ),
                  style: TextStyle(color: colors.onErrorContainer),
                ),
                trailing: IconButton(
                  tooltip: 'hall_node_dismiss'.tr(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.onErrorContainer,
                  ),
                  onPressed: () => onDismiss(n.member.id),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMedium,
              ),
              child: Text(
                'hall_nodes_offline_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
