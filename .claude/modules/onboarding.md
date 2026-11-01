# Module: onboarding (splash + first-run introduction)

**Confidence**: high (widget + full-app tests; native splash not yet seen on a real device)

## Flow
1. Native splash: emblem on navy.
   - Android: `drawable*/launch_background.xml` + `splash_logo.png`; 12+ uses `values(-night)-v31/styles.xml` with `splash_icon.png`.
   - iOS: `LaunchScreen.storyboard`, navy + LaunchImage.
2. `/splash` → `SplashScreen`: radar sweep over `assets/images/pahara_emblem.png`, then `launchRouteProvider`:
   - `/welcome` on first run;
   - otherwise `/`, which the router turns into the dashboard while an exam runs.
   - `SplashScreen.hold` = 1.6 s; tests set `Duration.zero`.
3. `/welcome` → `OnboardingScreen`, 5 pages: welcome + language, find, detect, team, permissions (`IPermissionService.requestBluetoothScan`).
   - Skip jumps to the permission page.
   - "Get started" saves `onboarding_done_v1` and goes to `/`.
   - Menu → "How Pahara works" opens `/welcome?replay=1`, which pops at the end.

## Files
lib/features/onboarding/{repository/onboarding_repository.dart, view_model/onboarding_view_model.dart, view/splash_screen.dart, view/onboarding_screen.dart, view/widgets/brand_colors.dart}; AppSettingsMenu (guide item); routes splash/onboarding (initialLocation = splash).

## Icons
Generated with Pillow from docs/store/assets/icon-source-original.png:
- emblem cut out as a circle (r = 230);
- Android mipmaps, adaptive foreground (70/108 dp) on `#0B1628`, splash sizes;
- iOS AppIcon (no alpha), LaunchImage;
- store 512/1024 icons.

## Tests
- test/app/app_flow_test.dart "first launch" group.
- test/features/onboarding/onboarding_screen_test.dart, with `ONB_SHOTS=<dir>` for screenshots.
- Full-app test storages must preset `onboarding_done_v1: true`.

## Changelog
- 2026-11-01 created
