import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_brand.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/onboarding/view/widgets/brand_colors.dart';
import 'package:exam_guard/features/onboarding/view_model/onboarding_view_model.dart';

/// First-run introduction: language, what Pahara does, and the scan
/// permissions. Also opened from the menu ([replay]) to read it again.
class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key, this.replay = false});

  /// Opened from the menu: ends by going back instead of to exam setup.
  final bool replay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingViewModelProvider);
    final vm = ref.read(onboardingViewModelProvider.notifier);
    final pager = usePageController();
    final last = state.page == OnboardingViewModel.pageCount - 1;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 320);

    void goTo(int page) => pager.animateToPage(
      page,
      duration: duration,
      curve: Curves.easeOutCubic,
    );

    Future<void> done() async {
      if (replay) {
        context.popBack();
        return;
      }
      await vm.finish();
      if (context.mounted) context.goTo(AppRoute.sessionSetup);
    }

    final pages = <Widget>[
      const _WelcomePage(),
      _FeaturePage(
        hero: const _Hero(
          icon: Icons.bluetooth_searching_rounded,
          satellites: [
            Icons.headphones_rounded,
            Icons.watch_rounded,
            Icons.smartphone_rounded,
          ],
        ),
        title: 'onb_find_title'.tr(),
        points: [
          (Icons.radar_rounded, 'onb_find_1'.tr()),
          (Icons.notification_important_rounded, 'onb_find_2'.tr()),
          (Icons.directions_walk_rounded, 'onb_find_3'.tr()),
        ],
      ),
      _FeaturePage(
        hero: const _Hero(
          icon: Icons.verified_user_rounded,
          satellites: [
            Icons.explore_rounded,
            Icons.camera_rounded,
            Icons.picture_as_pdf_rounded,
          ],
        ),
        title: 'onb_detect_title'.tr(),
        points: [
          (Icons.explore_rounded, 'onb_detect_1'.tr()),
          (Icons.camera_rounded, 'onb_detect_2'.tr()),
          (Icons.assignment_rounded, 'onb_detect_3'.tr()),
        ],
      ),
      _FeaturePage(
        hero: const _Hero(
          icon: Icons.hub_rounded,
          satellites: [
            Icons.qr_code_2_rounded,
            Icons.sensors_rounded,
            Icons.map_rounded,
          ],
        ),
        title: 'onb_team_title'.tr(),
        points: [
          (Icons.groups_rounded, 'onb_team_1'.tr()),
          (Icons.sensors_rounded, 'onb_team_2'.tr()),
          (Icons.map_rounded, 'onb_team_3'.tr()),
        ],
      ),
      _PermissionPage(state: state, vm: vm),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip jumps to the permission page: it is the one that matters.
            SizedBox(
              height: 48.h,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: last
                    ? null
                    : TextButton(
                        key: const Key('onb_skip'),
                        onPressed: () =>
                            goTo(OnboardingViewModel.pageCount - 1),
                        child: Text('onb_skip'.tr()),
                      ),
              ),
            ),
            Expanded(
              child: PageView(
                key: const Key('onb_pager'),
                controller: pager,
                onPageChanged: vm.setPage,
                children: pages,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.spacingMedium,
                AppDimens.spacingSmall,
                AppDimens.spacingMedium,
                AppDimens.spacingMedium,
              ),
              child: Row(
                children: [
                  _Dots(count: pages.length, index: state.page),
                  const Spacer(),
                  if (state.page > 0)
                    TextButton(
                      onPressed: () => goTo(state.page - 1),
                      child: Text('onb_back'.tr()),
                    ),
                  SizedBox(width: 6.w),
                  FilledButton(
                    key: const Key('onb_next'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(120.w, 48.h),
                    ),
                    onPressed: last ? done : () => goTo(state.page + 1),
                    child: Text((last ? 'onb_start' : 'onb_next').tr()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsetsDirectional.only(end: 6.w),
            width: i == index ? 22.w : 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: i == index ? colors.primary : colors.outlineVariant,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
      ],
    );
  }
}

/// Navy circle with a main icon (or the emblem) and small orbiting icons.
class _Hero extends StatelessWidget {
  const _Hero({this.icon, this.satellites = const [], this.emblem = false});

  final IconData? icon;
  final List<IconData> satellites;
  final bool emblem;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, c.maxHeight).clamp(120.0, 260.0);
        final chip = size * 0.2;
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size * 0.82,
                  height: size * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [BrandColors.navyLight, BrandColors.navy],
                    ),
                    border: Border.all(
                      color: BrandColors.cyan.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: BrandColors.cyan.withValues(alpha: 0.18),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: emblem
                      ? Padding(
                          padding: EdgeInsets.all(size * 0.03),
                          child: Image.asset('assets/images/pahara_emblem.png'),
                        )
                      : Icon(icon, size: size * 0.32, color: BrandColors.cyan),
                ),
                for (final (i, s) in satellites.indexed)
                  Align(
                    alignment: Alignment(
                      math.cos(-math.pi / 2 + i * 2 * math.pi / 3 + 0.5) * 0.92,
                      math.sin(-math.pi / 2 + i * 2 * math.pi / 3 + 0.5) * 0.92,
                    ),
                    child: Container(
                      width: chip,
                      height: chip,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == 0 ? BrandColors.orange : BrandColors.cyan,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(blurRadius: 6, color: Colors.black26),
                        ],
                      ),
                      child: Icon(
                        s,
                        size: chip * 0.5,
                        color: i == 0 ? BrandColors.orange : AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageLayout extends StatelessWidget {
  const _PageLayout({required this.hero, required this.children});

  final Widget hero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppDimens.spacingLarge),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: c.maxHeight * 0.36, child: hero),
              SizedBox(height: AppDimens.spacingLarge),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final current = context.appLocale.languageCode;
    return _PageLayout(
      hero: const _Hero(emblem: true),
      children: [
        Text(
          'onb_welcome_title'.tr(args: {'app': AppBrand.name}),
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Text(
          'onb_welcome_text'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        SizedBox(height: AppDimens.spacingLarge),
        Text(
          'onb_language'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final (locale, label) in const [
              (AppLocalization.english, 'English'),
              (AppLocalization.bangla, 'বাংলা'),
              (AppLocalization.arabic, 'العربية'),
            ])
              ChoiceChip(
                key: Key('onb_lang_${locale.languageCode}'),
                label: Text(label),
                selected: current == locale.languageCode,
                onSelected: (_) => context.setAppLocale(locale),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.hero,
    required this.title,
    required this.points,
  });

  final Widget hero;
  final String title;
  final List<(IconData, String)> points;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return _PageLayout(
      hero: hero,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: AppDimens.spacingMedium),
        for (final (icon, text) in points)
          Padding(
            padding: EdgeInsets.only(bottom: AppDimens.spacingSmall),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  ),
                  child: Icon(
                    icon,
                    size: 18.w,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      text,
                      style: textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({required this.state, required this.vm});

  final OnboardingState state;
  final OnboardingViewModel vm;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final p = state.permission;
    final (IconData icon, Color color, String text)? result = switch (p) {
      null => null,
      AppPermissionStatus.granted => (
        Icons.check_circle_rounded,
        AppColors.success,
        'onb_perm_granted'.tr(),
      ),
      AppPermissionStatus.denied => (
        Icons.info_rounded,
        Colors.orange.shade700,
        'onb_perm_denied'.tr(),
      ),
      AppPermissionStatus.permanentlyDenied => (
        Icons.block_rounded,
        colors.error,
        'onb_perm_blocked'.tr(),
      ),
    };
    return _PageLayout(
      hero: const _Hero(
        icon: Icons.bluetooth_rounded,
        satellites: [
          Icons.location_on_rounded,
          Icons.lock_rounded,
          Icons.wifi_rounded,
        ],
      ),
      children: [
        Text(
          'onb_perm_title'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Text(
          'onb_perm_text'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        SizedBox(height: AppDimens.spacingMedium),
        if (result == null || p != AppPermissionStatus.granted)
          FilledButton.tonalIcon(
            key: const Key('onb_allow'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(AppDimens.buttonHeight),
            ),
            onPressed: state.isRequesting
                ? null
                : p == AppPermissionStatus.permanentlyDenied
                ? vm.openSettings
                : vm.requestPermissions,
            icon: state.isRequesting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching_rounded),
            label: Text(
              (p == AppPermissionStatus.permanentlyDenied
                      ? 'onb_perm_settings'
                      : 'onb_perm_allow')
                  .tr(),
            ),
          ),
        if (result != null) ...[
          SizedBox(height: AppDimens.spacingSmall),
          Row(
            key: const Key('onb_perm_result'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(result.$1, color: result.$2, size: 20.w),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  result.$3,
                  style: textTheme.bodyMedium?.copyWith(color: result.$2),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
