import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../session/application/session_provider.dart';

class ReportSummaryScreen extends ConsumerWidget {
  const ReportSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(sessionProvider).valueOrNull?.deviceLogs ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text('report_summary'.tr()),
        actions: const [AppSettingsMenu()],
      ),
      body: Padding(
        padding: EdgeInsets.all(AppDimens.spacingLarge),
        child: logs.isEmpty
            ? Center(
                child: Text('report_empty'.tr(), textAlign: TextAlign.center),
              )
            : ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, _) =>
                    SizedBox(height: AppDimens.spacingSmall),
                itemBuilder: (_, index) {
                  final log = logs[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(log['name'] as String? ?? '—'),
                      subtitle: Text(log['location'] as String? ?? ''),
                      trailing: Text(log['id'] as String? ?? ''),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
