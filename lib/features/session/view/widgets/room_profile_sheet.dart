import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// "Room equipment remembered: N · Manage" under the baseline card, while
/// this exam's room has a saved profile.
class RoomProfileLine extends ConsumerWidget {
  const RoomProfileLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionViewModelProvider.select((s) => s?.roomNumber));
    // A new baseline adds to the profile: re-read after trust changes.
    ref.watch(scannerViewModelProvider.select((s) => s.trustedIds.length));
    final profile = ref.read(sessionViewModelProvider.notifier).roomProfile();
    if (profile == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: AppDimens.spacingExtraSmall),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 16.w, color: colors.primary),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              'room_profile_line'.tr(
                args: {'count': '${profile.items.length}'},
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(
            key: const Key('room_profile_manage'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => showRoomProfileSheet(context),
            child: Text('room_profile_manage'.tr()),
          ),
        ],
      ),
    );
  }
}

Future<void> showRoomProfileSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RoomProfileSheet(),
    );

class _RoomProfileSheet extends HookConsumerWidget {
  const _RoomProfileSheet();

  static IconData _icon(String transport) => switch (transport) {
    'wifi' => transportIcon(DeviceTransport.wifi),
    'classic' => transportIcon(DeviceTransport.classic),
    _ => transportIcon(DeviceTransport.ble),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sessionViewModelProvider.notifier);
    final version = useState(0);
    final RoomProfile? profile = useMemoized(notifier.roomProfile, [
      version.value,
    ]);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Future<void> forgetAll() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('room_profile_forget_title'.tr()),
          content: Text('room_profile_forget_text'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text('room_profile_forget'.tr()),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await notifier.forgetRoomProfile();
      if (context.mounted) Navigator.pop(context);
    }

    if (profile == null) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: Text('room_profile_empty'.tr(), textAlign: TextAlign.center),
        ),
      );
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMedium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'room_profile_title'.tr(args: {'room': profile.room}),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'room_profile_hint'.tr(
                      args: {
                        'date': AppDateFormat.shortDateTime(profile.savedAt),
                      },
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in profile.items)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        _icon(item.transport),
                        color: colors.primary,
                      ),
                      title: Text(
                        item.name.isEmpty ? item.id : item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        deviceTypeShortLabel(item.type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'room_profile_remove'.tr(),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () async {
                          await notifier.forgetRoomEquipment(item.id);
                          version.value++;
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppDimens.spacingMedium),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: forgetAll,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text('room_profile_forget'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
