import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Host only: the key ExamGuard ESP32 nodes use to join this phone's hall.
class HallNodeKeyCard extends StatelessWidget {
  const HallNodeKeyCard({
    super.key,
    required this.nodeKey,
    required this.onRegenerate,
  });

  final String nodeKey;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors_rounded, color: colors.tertiary),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: Text(
                    'hall_nodes_title'.tr(),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimens.spacingSmall),
            SelectableText(
              'hall_node_key'.tr(args: {'key': nodeKey}),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 4.h),
            for (final (i, step) in const [
              'hall_node_step1',
              'hall_node_step2',
              'hall_node_step3',
              'hall_node_step4',
            ].indexed)
              Padding(
                padding: EdgeInsets.only(top: 6.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 10.r,
                      backgroundColor: colors.tertiaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: AppDimens.spacingSmall),
                    Expanded(
                      child: Text(
                        step.tr(args: {'key': nodeKey}),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: AppDimens.spacingSmall,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: nodeKey));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('hall_copied'.tr())));
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text('hall_copy'.tr()),
                ),
                TextButton.icon(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('hall_node_key_new'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
