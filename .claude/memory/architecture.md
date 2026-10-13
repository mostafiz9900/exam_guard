# Architecture
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Rules for this structure: .claude/memory/rules.md

## Stack
- Flutter 3.47 (via fvm), Dart ^3.13
- State: hooks_riverpod 3.4 (manual Notifier providers, no codegen, no StateNotifier) + flutter_hooks
- Android: AGP 9.1.0 · Gradle 9.3.1 · Kotlin 2.4.0 · compileSdk 37
- iOS: min 15.0 · Swift Package Manager (no CocoaPods)
- Export: pdf + share_plus
- Navigation: go_router · Storage: Hive · BLE: flutter_blue_plus · Sensors: sensors_plus
- i18n: easy_localization (en, bn, ar) · Responsive: flutter_screenutil_plus

## Pattern
Feature-first + MVVM. No use cases. Every package wrapped in `lib/core/`.

```
View (widget) ──watch/read──▶ ViewModel (Notifier) ──▶ Repository ──▶ core service wrapper ──▶ package
```

## Folder Structure (target)
```
lib/
├── main.dart                     # bootstrap only
├── app/
│   └── exam_guard_app.dart       # MaterialApp.router, theme, locale
├── core/
│   ├── navigation/               # AppRouter, AppRoutes, AppNavigator
│   ├── localization/             # AppLocalization wrapper
│   ├── services/
│   │   ├── bluetooth/            # IBluetoothService + impl
│   │   ├── sensors/              # IMagnetometerService + impl
│   │   ├── permission/           # IPermissionService + impl
│   │   ├── storage/              # ILocalStorage + Hive impl
│   │   ├── logger/               # AppLogger
│   │   ├── toast/                # AppToast
│   │   ├── audio/                # GeigerBuzzerService
│   │   └── report/               # ViolationReportService
│   ├── theme/                    # AppTheme, AppColors, AppTextStyles, AppDimens
│   ├── utils/                    # size extensions, formatters
│   └── widgets/                  # AppLoader, AppShimmer, PrimaryButton, ...
└── features/
    ├── session/      { model, repository, view_model, view }
    ├── dashboard/    { view_model, view }
    ├── scanner/      { model, repository, view_model, view }   # wireless BLE
    ├── magnetic/     { model, repository, view_model, view }
    ├── radar/        { model, view_model, view }
    ├── rf_detector/  { model, repository, view_model, view }
    ├── action_log/   { model, repository, view_model, view }
    └── report/       { view_model, view }
```

## Data Flow
Session is created on setup screen → saved to Hive → ViewModels read the active session via `sessionViewModelProvider`. Action logs reference the session id.

## External Services
- Optional ESP32 hardware node over BLE (name contains `esp32` / `examguard` / `rf-node`)

## Environment Differences
- Android: BLE scan + location permissions in AndroidManifest
- iOS: Bluetooth + location usage descriptions in Info.plist
