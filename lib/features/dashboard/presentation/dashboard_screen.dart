import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../scanner/application/magnetic_scanner_provider.dart';
import '../../scanner/application/scanner_provider.dart';
import '../../scanner/domain/scanned_device_model.dart';
import '../../session/application/session_provider.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch live state providers
    final scannerState = ref.watch(scannerProvider);
    final magneticState = ref.watch(magneticScannerProvider);
    final session = ref.watch(sessionProvider).valueOrNull;

    final room = session?.roomNumber.isNotEmpty == true
        ? 'Room ${session!.roomNumber}'
        : 'Exam Hall 302';

    final institute = session?.instituteName.isNotEmpty == true
        ? session!.instituteName
        : 'Exam Guard Central';

    final colors = Theme.of(context).colorScheme;

    // Live ticking time hook
    final now = useState(DateTime.now());
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => now.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);

    // Live radar animation controller
    final sweepController = useAnimationController(
      duration: const Duration(seconds: 3),
    )..repeat();

    final activeDevices = scannerState.activeDevices;
    final highThreatCount = activeDevices.where((d) => d.rssi > -65).length;

    Future<bool> showExitConfirmationDialog() async {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.red,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Exit ExamGuard?',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure all exam hall security checks are completed?',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Exiting now will stop active BLE signal & magnetic spectrum monitoring.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel / Continue Scan'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('All Checks Done & Exit'),
              ),
            ],
          );
        },
      );
      return shouldExit ?? false;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showExitConfirmationDialog();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: colors.primary,
                size: 22.w,
              ),
              SizedBox(width: 8.w),
              const Text('ExamGuard Security'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.cell_wifi_rounded,
                color: scannerState.isScanning ? colors.primary : Colors.grey,
              ),
              tooltip: scannerState.isScanning ? 'Scanner Active' : 'Scanner Idle',
              onPressed: () => context.push('/scanner'),
            ),
            const AppSettingsMenu(),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 650;

              return SingleChildScrollView(
                padding: EdgeInsets.all(AppDimens.spacingLarge),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Security Status HUD Hero Card
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusLarge,
                            ),
                            side: BorderSide(
                              color: colors.primary.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingLarge),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Animated Radar Live Visualizer Icon
                                    AnimatedBuilder(
                                      animation: sweepController,
                                      builder: (context, _) {
                                        return Container(
                                          width: 52.w,
                                          height: 52.w,
                                          decoration: BoxDecoration(
                                            color: colors.primary
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colors.primary
                                                  .withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              CustomPaint(
                                                size: Size(52.w, 52.w),
                                                painter: _MiniSweepPainter(
                                                  angle: sweepController.value *
                                                      2 *
                                                      math.pi,
                                                  color: colors.primary,
                                                ),
                                              ),
                                              Icon(
                                                Icons.radar_rounded,
                                                size: 26.w,
                                                color: colors.primary,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                room,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16.sp,
                                                    ),
                                              ),
                                              SizedBox(width: 6.w),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8.w,
                                                  vertical: 2.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(10.r),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 6.w,
                                                      height: 6.w,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: AppColors.success,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4.w),
                                                    Text(
                                                      'MONITORING ONLINE',
                                                      style: TextStyle(
                                                        fontSize: 9.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors.success,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            '$institute • ${DateFormat('hh:mm:ss a').format(now.value)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 11.sp,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),

                                // Real-time Security HUD Counters
                                Row(
                                  children: [
                                    Expanded(
                                      child: _LiveStatBadge(
                                        icon: Icons.cell_wifi_rounded,
                                        title: 'BLE Signals',
                                        value: '${activeDevices.length}',
                                        color: colors.primary,
                                        onTap: () => context.push('/scanner'),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _LiveStatBadge(
                                        icon: Icons.warning_amber_rounded,
                                        title: 'High Threats',
                                        value: '$highThreatCount',
                                        color: highThreatCount > 0
                                            ? Colors.red
                                            : Colors.orange,
                                        onTap: () => context.push('/scanner'),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _LiveStatBadge(
                                        icon: Icons.sensors_rounded,
                                        title: 'Magnetic EMP',
                                        value:
                                            '${magneticState.magnitude.toStringAsFixed(1)} μT',
                                        color: magneticState.hazardLevel ==
                                                MagneticHazardLevel.critical
                                            ? Colors.red
                                            : Colors.teal,
                                        onTap: () => context.push('/magnetic'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Section Title: Tactical Navigation Deck
                        Text(
                          'Tactical Security Modules',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                        ),
                        SizedBox(height: AppDimens.spacingSmall),

                        // Responsive Grid Navigation Deck
                        GridView.count(
                          crossAxisCount: isWideScreen ? 3 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: AppDimens.spacingMedium,
                          mainAxisSpacing: AppDimens.spacingMedium,
                          childAspectRatio: 1.15,
                          children: [
                            _DashboardModuleCard(
                              icon: Icons.cell_wifi_rounded,
                              title: 'Wireless BLE Scanner',
                              subtitle:
                                  'Detect bluetooth earpieces & hidden bugs',
                              badgeText: '${activeDevices.length} Active',
                              color: colors.primary,
                              onTap: () => context.push('/scanner'),
                            ),
                            _DashboardModuleCard(
                              icon: Icons.radar_rounded,
                              title: '360° Tracking Radar',
                              subtitle:
                                  'Live multi-target radar map & 1-on-1 tracking',
                              badgeText: 'Multi-Radar',
                              color: Colors.teal,
                              onTap: () => context.push('/radar'),
                            ),
                            _DashboardModuleCard(
                              icon: Icons.sensors_rounded,
                              title: 'Magnetic EMP Detector',
                              subtitle:
                                  'Find hidden metal bugs & magnetic signals',
                              badgeText:
                                  '${magneticState.magnitude.toStringAsFixed(0)} μT',
                              color: Colors.indigo,
                              onTap: () => context.push('/magnetic'),
                            ),
                            _DashboardModuleCard(
                              icon: Icons.assignment_turned_in_rounded,
                              title: 'Session Setup',
                              subtitle: 'Configure room boundary & parameters',
                              badgeText: room,
                              color: Colors.blueGrey,
                              onTap: () => context.push('/session-setup'),
                            ),
                            _DashboardModuleCard(
                              icon: Icons.settings_input_antenna_rounded,
                              title: 'ESP32 Cellular RF Analyzer',
                              subtitle:
                                  'Wideband 8.0 GHz SIM call & 4G/5G data analyzer',
                              badgeText: 'ESP32-S3',
                              color: Colors.deepOrange,
                              onTap: () => context.push('/rf-detector'),
                            ),
                            _DashboardModuleCard(
                              icon: Icons.report_problem_rounded,
                              title: 'Log Incident Report',
                              subtitle:
                                  'Record cheating & unauthorized devices',
                              badgeText: 'Action',
                              color: Colors.redAccent,
                              onTap: () => context.push('/action/new'),
                            ),
                          ],
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Section Title: Live Discovered Threats Stream
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Live Discovered Feed',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                  ),
                            ),
                            TextButton.icon(
                              onPressed: () => context.push('/scanner'),
                              icon: Icon(
                                Icons.arrow_forward_rounded,
                                size: 14.w,
                              ),
                              label: Text(
                                'View Scanner',
                                style: TextStyle(fontSize: 11.sp),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),

                        // Live Devices Stream Card List
                        activeDevices.isEmpty
                            ? Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusMedium,
                                  ),
                                ),
                                child: Padding(
                                  padding:
                                      EdgeInsets.all(AppDimens.spacingLarge),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.bluetooth_searching_rounded,
                                          size: 32.w,
                                          color: Colors.grey.shade400,
                                        ),
                                        SizedBox(height: 8.h),
                                        Text(
                                          'Scanning live BLE frequencies...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: activeDevices.take(3).map((device) {
                                  return Padding(
                                    padding:
                                        EdgeInsets.only(bottom: 6.h),
                                    child: _LiveThreatTile(
                                      device: device,
                                      onTrackTap: () => context.push('/radar',
                                          extra: device),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
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

class _LiveStatBadge extends StatelessWidget {
  const _LiveStatBadge({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18.w, color: color),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 9.sp,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardModuleCard extends StatelessWidget {
  const _DashboardModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22.w),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 12.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Expanded(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10.sp,
                        color: Colors.grey.shade600,
                        height: 1.2,
                      ),
                  maxLines: 2,
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

class _LiveThreatTile extends StatelessWidget {
  const _LiveThreatTile({
    required this.device,
    required this.onTrackTap,
  });

  final ScannedDeviceModel device;
  final VoidCallback onTrackTap;

  Color _getSignalColor(int rssi) {
    if (rssi > -60) return const Color(0xFF10B981);
    if (rssi > -75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getSignalColor(device.rssi);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          radius: 18.r,
          child: Icon(
            Icons.bluetooth_searching_rounded,
            color: color,
            size: 18.w,
          ),
        ),
        title: Text(
          device.displayName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${device.manufacturer} • MAC: ${device.id}',
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey.shade600,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ElevatedButton.icon(
          onPressed: onTrackTap,
          icon: Icon(Icons.radar_rounded, size: 14.w),
          label: Text('Track', style: TextStyle(fontSize: 10.sp)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _MiniSweepPainter extends CustomPainter {
  _MiniSweepPainter({required this.angle, required this.color});
  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      0.0,
      math.pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniSweepPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
