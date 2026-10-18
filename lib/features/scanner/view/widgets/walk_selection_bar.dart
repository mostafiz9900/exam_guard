import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Bottom bar of multi-select mode: how many devices are picked and
/// "Walk & find (N)".
class WalkSelectionBar extends StatelessWidget {
  const WalkSelectionBar({
    super.key,
    required this.count,
    required this.max,
    required this.onCancel,
    required this.onWalk,
  });

  final int count;
  final int max;
  final VoidCallback onCancel;
  final VoidCallback onWalk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMedium,
            vertical: 8.h,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'scan_select_cancel'.tr(),
                icon: const Icon(Icons.close_rounded),
                onPressed: onCancel,
              ),
              Expanded(
                child: Text(
                  'scan_selected_count'.tr(
                    args: {'count': '$count', 'max': '$max'},
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: count == 0 ? null : onWalk,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.directions_walk_rounded),
                label: Text(
                  'scan_walk_find'.tr(args: {'count': '$count'}),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
