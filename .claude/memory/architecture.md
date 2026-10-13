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

## Folder Structure
```
lib/
├── main.dart                     # bootstrap only (localization, storage, ProviderScope)
├── app/exam_guard_app.dart       # MaterialApp.router, theme, locale
├── core/
│   ├── localization/             # AppLocalization, String.tr(), context.setAppLocale
│   ├── navigation/               # AppRouter + AppRoute, AppNavigator extension
│   ├── services/
│   │   ├── audio/                # GeigerBuzzerService (+ provider)
│   │   ├── bluetooth/            # IBluetoothService: one shared scan, owner-counted
│   │   ├── logger/               # AppLogger
│   │   ├── pdf/                  # IPdfService + PdfTableDocument
│   │   ├── permission/           # IPermissionService
│   │   ├── sensors/              # IMagnetometerService
│   │   ├── share/                # IShareService (files + text)
│   │   ├── storage/              # ILocalStorage (key-value) + Hive impl
│   │   └── toast/                # AppToast
│   ├── settings/                 # ThemeModeViewModel
│   ├── theme/                    # AppTheme, AppColors, AppDimens
│   ├── utils/                    # size_extensions, AppDateFormat
│   └── widgets/                  # PrimaryButton, AppLoader, AppShimmer, ...
└── features/
    ├── session/      model (SessionModel, ActionLogModel) · repository · view_model · view
    ├── dashboard/    view (+ widgets) — reads other features' view models
    ├── scanner/      model · repository (ScannerRepository, BluetoothDeviceInspector) · view_model · view (+ widgets)
    ├── radar/        model · repository · view_model · view (+ widgets)
    ├── magnetic/     model · repository · view_model · view (+ widgets)
    ├── rf_detector/  model · repository · view_model · view (+ widgets)
    ├── action_log/   repository · view_model · view
    └── report/       repository · view_model · view (+ widgets)
```

## Data Flow
Session is created on the setup screen → `SessionRepository` stores it under `session_<id>` (+ `current_session_id`) → screens read it via `sessionViewModelProvider`. Incidents are `ActionLogModel`s stored inside the session. End Exam stamps `endTime` and opens the report, which exports a PDF through the share sheet.

## External Services
- Optional ESP32 hardware node over BLE (name contains `esp32` / `examguard` / `rf-node`)

## Environment Differences
- Android: BLE scan + location permissions in AndroidManifest
- iOS: Bluetooth + location usage descriptions in Info.plist
