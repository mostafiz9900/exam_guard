import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/device_list_tile.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/scanner_provider.dart';

class WirelessScannerScreen extends HookConsumerWidget {
  const WirelessScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulse = useAnimationController(duration: const Duration(seconds: 2));
    final scanner = ref.watch(scannerNotifierProvider);
    final notifier = ref.read(scannerNotifierProvider.notifier);
    final data = scanner.valueOrNull ?? const ScannerState();

    useEffect(() {
      pulse.repeat();
      return pulse.dispose;
    }, [pulse]);

    return Scaffold(
      appBar: AppBar(
        title: Text('wireless_scanner'.tr()),
        actions: const [AppSettingsMenu()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.spacingLarge,
                  AppDimens.spacingLarge,
                  AppDimens.spacingLarge,
                  AppDimens.spacingSmall,
                ),
                child: Card(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (context, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          _RadarRing(
                            scale: 0.45 + pulse.value * 0.55,
                            opacity: 1 - pulse.value,
                          ),
                          _RadarRing(
                            scale: 0.25 + ((pulse.value + .5) % 1) * .75,
                            opacity: .65 - (pulse.value * .5),
                          ),
                          SpinKitRipple(
                            color: Theme.of(context).colorScheme.primary,
                            size: 130.w,
                          ),
                          Icon(
                            Icons.wifi_tethering,
                            size: 44.w,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimens.spacingLarge),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      data.isScanning ? 'scanning'.tr() : 'scanner_ready'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Switch.adaptive(
                    value: data.minimumRssi != null,
                    onChanged: (enabled) =>
                        notifier.filterByRssi(enabled ? -70 : null),
                  ),
                  Text('nearby_only'.tr()),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppDimens.spacingLarge),
              child: PrimaryButton(
                label: data.isScanning
                    ? 'stop_scanning'.tr()
                    : 'start_scanning'.tr(),
                isLoading: scanner.isLoading,
                onPressed: () async {
                  try {
                    if (data.isScanning) {
                      await notifier.stopScanning();
                    } else {
                      await notifier.startScanning();
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('scan_unavailable'.tr())),
                      );
                    }
                  }
                },
              ),
            ),
            Expanded(
              flex: 6,
              child: scanner.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text('scan_unavailable'.tr())),
                data: (state) => state.filteredDevices.isEmpty
                    ? Center(
                        child: Text(
                          state.isScanning
                              ? 'scanning'.tr()
                              : 'no_devices'.tr(),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppDimens.spacingLarge,
                          0,
                          AppDimens.spacingLarge,
                          AppDimens.spacingLarge,
                        ),
                        itemCount: state.filteredDevices.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: AppDimens.spacingSmall),
                        itemBuilder: (context, index) {
                          final device = state.filteredDevices[index];
                          return DeviceListTile(
                            deviceName: device.name,
                            deviceId: device.deviceId,
                            deviceStatus: device.status,
                            signalStrength: device.signalStrength,
                            onTap: () =>
                                context.go('/radar', extra: device.deviceId),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarRing extends StatelessWidget {
  const _RadarRing({required this.scale, required this.opacity});
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: scale,
    child: Container(
      width: 220.w,
      height: 220.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(
            alpha: opacity.clamp(0, 1).toDouble(),
          ),
          width: 2,
        ),
      ),
    ),
  );
}
