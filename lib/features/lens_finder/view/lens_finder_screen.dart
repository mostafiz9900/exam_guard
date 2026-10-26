import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/features/lens_finder/view/widgets/lens_control_panel.dart';
import 'package:exam_guard/features/lens_finder/view/widgets/lens_glint_overlay.dart';
import 'package:exam_guard/features/lens_finder/view/widgets/lens_not_measuring_view.dart';
import 'package:exam_guard/features/lens_finder/view_model/lens_finder_view_model.dart';

/// Hidden camera lens finder: torch on, camera picture with rings on
/// steady bright glints, plus how-to and limits.
class LensFinderScreen extends HookConsumerWidget {
  const LensFinderScreen({super.key});

  /// Fallback preview aspect (landscape native) before the camera reports.
  static const double _defaultAspect = 4 / 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lensFinderViewModelProvider);
    final notifier = ref.read(lensFinderViewModelProvider.notifier);
    final hasCandidates = state.isLive && state.candidates.isNotEmpty;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final pulse = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    );
    useEffect(() {
      if (hasCandidates && !reduceMotion) {
        pulse.repeat();
      } else {
        pulse
          ..stop()
          ..value = 0;
      }
      return null;
    }, [pulse, hasCandidates, reduceMotion]);

    useOnAppLifecycleStateChange((previous, current) {
      switch (current) {
        case AppLifecycleState.hidden:
        case AppLifecycleState.paused:
          notifier.onAppBackgrounded();
        case AppLifecycleState.resumed:
          notifier.onAppForegrounded();
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
          // Inactive also fires for the permission dialog: keep the camera.
          break;
      }
    });

    final measuring =
        state.status == LensFinderStatus.live ||
        state.status == LensFinderStatus.starting;

    final preview = ClipRect(
      child: ColoredBox(
        color: Colors.black,
        child: measuring
            ? _LivePreview(
                state: state,
                pulse: pulse,
                preview: notifier.buildPreview(),
                defaultAspect: _defaultAspect,
              )
            : LensNotMeasuringView(
                status: state.status,
                onRetry: notifier.start,
                onOpenSettings: notifier.openAppSettings,
              ),
      ),
    );
    final panel = LensControlPanel(
      state: state,
      onToggleTorch: notifier.toggleTorch,
      onSensitivity: notifier.setSensitivity,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPopBack) {
          context.popBack();
        } else {
          context.goTo(AppRoute.dashboard);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('lens_title'.tr()),
          actions: [
            if (state.status != LensFinderStatus.noCamera &&
                state.status != LensFinderStatus.permissionDenied)
              IconButton(
                icon: Icon(
                  measuring
                      ? Icons.stop_circle_outlined
                      : Icons.play_arrow_rounded,
                ),
                tooltip: (measuring ? 'lens_pause' : 'lens_resume').tr(),
                onPressed: measuring ? notifier.pause : notifier.start,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > constraints.maxHeight) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: preview),
                    Expanded(flex: 2, child: panel),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(child: preview),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.45,
                    ),
                    child: panel,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cover-fitted camera picture with the glint rings and status chips.
class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.state,
    required this.pulse,
    required this.preview,
    required this.defaultAspect,
  });

  final LensFinderState state;
  final Animation<double> pulse;
  final Widget preview;
  final double defaultAspect;

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final size = state.previewSize;
    final native = size == null || size.height == 0
        ? defaultAspect
        : size.width / size.height;
    // Upright width / height of the camera picture.
    final aspect = portrait ? 1 / native : native;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final double cw;
        final double ch;
        if (w / h > aspect) {
          cw = w;
          ch = w / aspect;
        } else {
          ch = h;
          cw = h * aspect;
        }
        final area = Rect.fromLTWH((w - cw) / 2, (h - ch) / 2, cw, ch);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (state.isLive) Positioned.fromRect(rect: area, child: preview),
            if (state.isLive)
              Positioned.fill(
                child: LensGlintOverlay(
                  candidates: state.candidates,
                  area: area,
                  pulse: pulse,
                ),
              ),
            if (!state.isLive)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'lens_starting'.tr(),
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            PositionedDirectional(
              top: 10,
              start: 10,
              end: 10,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip(state: state),
                  if (state.isLive && state.isSceneTooBright)
                    _Chip(
                      icon: Icons.wb_sunny_outlined,
                      label: 'lens_too_bright'.tr(),
                      color: const Color(0xFFFFB74D),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final LensFinderState state;

  /// Shown when glints are marked: warning, not "found a camera".
  static const Color _alertColor = Color(0xFFFFC107);
  static const Color _scanColor = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    if (!state.isLive) {
      return _Chip(
        icon: Icons.hourglass_top_rounded,
        label: 'lens_starting'.tr(),
        color: Colors.white70,
      );
    }
    final n = state.candidates.length;
    if (n == 0) {
      return _Chip(
        icon: Icons.center_focus_weak_rounded,
        label: 'lens_status_scanning'.tr(),
        color: _scanColor,
      );
    }
    return _Chip(
      icon: Icons.adjust_rounded,
      label: n == 1
          ? 'lens_status_one'.tr()
          : 'lens_status_many'.tr(args: {'count': '$n'}),
      color: _alertColor,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
