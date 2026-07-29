import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/action_card.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/device_list_tile.dart';
import '../../../core/widgets/primary_button.dart';
import '../../session/application/session_provider.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now());

    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => now.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);

    final session = ref.watch(sessionProvider).valueOrNull;
    final room = session?.roomNumber ?? '—';
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(
        title: Text('dashboard'.tr()),
        actions: const [AppSettingsMenu()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Monitoring Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusLarge ?? 16,
                      ),
                      side: BorderSide(
                        color: AppColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppDimens.spacingLarge),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 38,
                              color: colors.primary,
                            ),
                          ),
                          SizedBox(width: AppDimens.spacingMedium),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'room'.tr(namedArgs: {'room': room}),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: AppDimens.spacingExtraSmall),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'monitoring_active'.tr(),
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat.Hms(
                              context.locale.toString(),
                            ).format(now.value),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Quick Actions Title
                  Text(
                    'quick_actions'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),

                  // Grid View for Actions
                  GridView.count(
                    crossAxisCount: screenWidth >= 600 ? 3 : 2,
                    // মোবাইলের জন্য 0.85, বড় স্ক্রিনের জন্য 1.0 (Responsive Aspect Ratio)
                    childAspectRatio: screenWidth >= 600 ? 1.0 : 0.85,
                    crossAxisSpacing: AppDimens.spacingMedium,
                    mainAxisSpacing: AppDimens.spacingMedium,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _action(
                        context,
                        'wireless_scan',
                        'wireless_scan_subtitle',
                        Icons.wifi_tethering,
                        '/scanner',
                        colors.primary,
                      ),
                      _action(
                        context,
                        'magnetic_scan',
                        'magnetic_scan_subtitle',
                        Icons.sensors_outlined,
                        '/magnetic',
                        colors.primary,
                      ),
                      _action(
                        context,
                        'tracking_radar',
                        'radar_description',
                        Icons.radar_outlined,
                        '/radar',
                        colors.primary,
                      ),
                      _action(
                        context,
                        'activity_log',
                        'log_intro',
                        Icons.note_add_outlined,
                        '/action/new',
                        colors.primary,
                      ),
                      _action(
                        context,
                        'report',
                        'report_empty',
                        Icons.summarize_outlined,
                        '/report',
                        colors.primary,
                      ),
                    ],
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Recent Activity Title
                  Text(
                    'recent_activity'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingSmall),

                  // Recent Activity List
                  if (session == null || session.deviceLogs.isEmpty)
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: EdgeInsets.all(AppDimens.spacingLarge),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              color: colors.outline,
                              size: 28,
                            ),
                            SizedBox(width: AppDimens.spacingMedium),
                            Expanded(
                              child: Text(
                                'no_activity'.tr(),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: session.deviceLogs.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: AppDimens.spacingSmall),
                      itemBuilder: (_, index) {
                        final log = session.deviceLogs.reversed.toList()[index];
                        return DeviceListTile(
                          deviceName: log['name'] as String? ?? '',
                          deviceId: log['id'] as String? ?? '',
                          deviceStatus: 'active',
                        );
                      },
                    ),
                  SizedBox(height: AppDimens.spacingExtraLarge),

                  // End Session Button
                  PrimaryButton(
                    label: 'end_session'.tr(),
                    backgroundColor: AppColors.error,
                    onPressed: () async {
                      await ref
                          .read(sessionProvider.notifier)
                          .endCurrentSession();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('end_session_message'.tr())),
                        );
                        context.go('/');
                      }
                    },
                  ),
                  SizedBox(height: AppDimens.spacingLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    String route,
    Color iconColor,
  ) => ActionCard(
    title: title.tr(),
    subtitle: subtitle.tr(),
    icon: Icon(icon, color: iconColor, size: 28),
    onTap: () => context.push(route),
  );
}

class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Icon icon;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium ?? 12.0),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingMedium ?? 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
              SizedBox(height: AppDimens.spacingMedium ?? 12.0),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1, // লেখা ১ লাইনের বেশি হবে না
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4.0),
              Expanded(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 2, // সাবটাইটেল সর্বোচ্চ ২ লাইন হবে
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
