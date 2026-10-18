import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/features/history/view/widgets/history_entry_card.dart';
import 'package:exam_guard/features/history/view_model/history_view_model.dart';

/// Past exams, newest first. Tapping one opens its (read-only) report.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyViewModelProvider);
    final colors = Theme.of(context).colorScheme;

    void open(HistoryEntry entry) {
      final opened = ref
          .read(historyViewModelProvider.notifier)
          .openReport(entry.sessionId);
      if (opened) {
        context.pushTo(AppRoute.report);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('history_open_failed'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('history_title'.tr()),
        actions: const [AppSettingsMenu()],
      ),
      body: SafeArea(
        child: state.isEmpty
            ? const _EmptyHistory()
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.read(historyViewModelProvider.notifier).refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(AppDimens.spacingMedium),
                  itemCount: state.entries.length + 1,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: AppDimens.spacingSmall),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        'history_subtitle'.tr(
                          args: {'count': '${state.entries.length}'},
                        ),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      );
                    }
                    final entry = state.entries[i - 1];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: HistoryEntryCard(
                          entry: entry,
                          onTap: entry.isRunning || state.examRunning
                              ? null
                              : () => open(entry),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 56.w, color: colors.outline),
            SizedBox(height: AppDimens.spacingMedium),
            Text(
              'history_empty_title'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppDimens.spacingExtraSmall),
            Text(
              'history_empty_message'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
