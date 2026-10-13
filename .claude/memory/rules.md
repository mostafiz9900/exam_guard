# Rules — Non Negotiable
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.

## Architecture: Feature-first + MVVM
✅ DO: Put every feature in `lib/features/<feature>/` with these folders:
  - `model/` — plain data classes (immutable, `copyWith`, `toMap`/`fromMap`)
  - `repository/` — data access for the feature; talks to `core/services/*` only
  - `view_model/` — Riverpod `Notifier` / `AsyncNotifier` + its state class
  - `view/` — screens; `view/widgets/` for widgets used only by this feature
✅ DO: Data flow is View → ViewModel → Repository → core service → package
✅ DO: Put code shared by 2+ features in `lib/core/`
❌ DON'T: Create `domain/`, `usecase/`, `application/`, or `infrastructure/` folders
❌ DON'T: Write use case classes — the ViewModel calls the Repository directly
❌ DON'T: Put business logic in widgets — Views only render state and forward events
❌ DON'T: Import one feature's internals from another feature — move shared code to `core/`

## Riverpod
✅ DO: Declare providers by hand: `NotifierProvider`, `AsyncNotifierProvider`, `Provider`
✅ DO: Use `Notifier` / `AsyncNotifier` for ViewModels
❌ DON'T: Use `@riverpod` annotations, `riverpod_generator`, or `build_runner` for providers
❌ DON'T: Use `StateNotifier` / `StateNotifierProvider` / `ChangeNotifierProvider` (legacy)

## Package Wrapping — every third-party package behind our own class
✅ DO: Wrap each package in a custom class or function in `lib/core/`. Feature code imports the wrapper, never the package.
✅ DO: Use Riverpod `Provider`s for dependency injection (no get_it)
✅ DO: For services, define an interface (`i_<name>_service.dart`) plus an implementation (`<name>_service_impl.dart`), exposed through a Riverpod `Provider`
❌ DON'T: Import a third-party package anywhere in `lib/features/` (except the allowed list below)

| Package | Wrapper (in `lib/core/`) |
|---|---|
| flutter_blue_plus | `services/bluetooth/` → `IBluetoothService` (one shared scan, owner-counted) |
| sensors_plus | `services/sensors/` → `IMagnetometerService` |
| permission_handler | `services/permission/` → `IPermissionService` |
| hive_flutter | `services/storage/` → `ILocalStorage` |
| logger | `services/logger/` → `AppLogger` |
| bot_toast | `services/toast/` → `AppToast` |
| go_router | `navigation/` → `AppRouter`, `AppRoutes`, `AppNavigator` |
| easy_localization | `localization/` → `AppLocalization`, `String.tr` extension re-export |
| flutter_screenutil_plus | `utils/size_extensions.dart` → `AppSize` / `.w .h .sp .r` |
| google_fonts | `theme/app_text_styles.dart` → `AppTextStyles` |
| shimmer | `widgets/app_shimmer.dart` → `AppShimmer` |
| flutter_spinkit | `widgets/app_loader.dart` → `AppLoader` |
| lottie | `widgets/app_lottie.dart` → `AppLottie` |
| share_plus | `services/share/` → `IShareService` |
| pdf | `services/report/session_report_pdf_service.dart` → `SessionReportPdfService` |

Allowed direct imports in features (they ARE the MVVM framework): `flutter`, `hooks_riverpod`, `flutter_hooks`.

## Naming Conventions
✅ DO: `snake_case.dart` files; `<Feature>Screen`, `<Feature>ViewModel`, `<Feature>State`, `<Feature>Repository`
✅ DO: Provider names: `<feature>ViewModelProvider`, `<feature>RepositoryProvider`
❌ DON'T: Duplicate models or services — one source of truth per concept

## Error Handling
✅ DO: Catch package errors inside the wrapper; return/throw our own error types
❌ DON'T: Use empty `catch (_) {}` — at minimum log via `AppLogger`

## Testing Rules
✅ DO: Test ViewModels by overriding repository/service providers with fakes
✅ DO: Run `fvm flutter analyze` with zero issues before finishing a task

## Forbidden Patterns
❌ NEVER: Show simulated/mock data in the UI without a visible "DEMO" label
❌ NEVER: Show a success message for an action that didn't happen
