# ExamGuard — Navigation & UI Blueprint

This document formalizes the screen-by-screen navigation flow and UI layout for ExamGuard. Use it as the single source of truth when implementing UI, providers, routing, and testing.

## High-level routing (go_router)
- `/` — Session Setup (SessionSetupScreen)
- `/dashboard` — Main Dashboard (DashboardScreen)
- `/scanner` — Wireless Scanner (WirelessScannerScreen)
- `/radar` — Tracking Radar (TrackingRadarScreen)
- `/magnetic` — Magnetic Scanner (MagneticScannerScreen)
- `/report` — Report Summary (ReportSummaryScreen)
- `/action/new` — Action Entry (ActionEntryScreen / BottomSheet)

Route names (constants):
- `AppRoute.sessionSetup` -> `/`
- `AppRoute.dashboard` -> `/dashboard`
- `AppRoute.scanner` -> `/scanner`
- `AppRoute.radar` -> `/radar`
- `AppRoute.magnetic` -> `/magnetic`
- `AppRoute.report` -> `/report`
- `AppRoute.actionNew` -> `/action/new`

## Screen details & navigation actions

1) Session Setup (`/`)
- UI: App logo, `CustomTextField`s for Institute, Teacher, Room; `Switch` "Connect Hardware (ESP32)"; large `PrimaryButton`.
- Action: `Start Exam Duty` -> persist `SessionModel` via `SessionProvider` then `context.go('/dashboard')`.

2) Dashboard (`/dashboard`)
- UI: Header (Room number + live clock), GridView with two `ActionCard`s: "Wireless Scan" and "Magnetic Scan"; footer list `Recent Logs`; red `End Exam` button.
- Actions:
  - Wireless Scan card -> `context.push('/scanner')`
  - Magnetic Scan card -> `context.push('/magnetic')`
  - End Exam -> `context.push('/report')`
  - Auto alert (Hardware detection) -> show Danger BottomSheet; Track Location -> `context.push('/radar')`

3) Wireless Scanner (`/scanner`)
- UI: Top radar animation; bottom list of scanned devices (name, MAC, RSSI color-coded).
- Action: Tap device -> `context.push('/radar', extra: DeviceDescriptor)` where `DeviceDescriptor` contains identifying fields (mac, name, initialRssi).

4) Tracking Radar (`/radar`)
- UI: Large circular hot/cold radar UI. Color transition based on live RSSI stream: Blue -> Yellow -> Red.
- Actions:
  - "Scan Desk/Body" -> `context.push('/magnetic')`
  - "Log Action" -> open `ActionEntryBottomSheet` (or `context.push('/action/new')` for full-screen)

5) Magnetic Scanner (`/magnetic`)
- UI: ECG-style waveform; flashes red on magnetic spike.
- Action: "Log Device" -> open `ActionEntryBottomSheet`.

6) Action Entry BottomSheet (`/action/new`)
- UI: Bottom sheet with Device Name, MAC, Action dropdown (Confiscated/Warning), Notes, Save button.
- Action: Save -> persist `ActionLogModel` linked to current `SessionModel` with `ActionLogRepository` -> close sheet (`context.pop()`), show success toast.

7) Report Summary (`/report`)
- UI: Start/End times, counts, `DataTable` with logs, `Generate & Share PDF` button.
- Action: Generate PDF offline (using `pdf` + `printing`) and call system share.

## Data passing & expectations
- When pushing `/radar` from scanner, provide `extra` parameter: a lightweight `DeviceDescriptor` (mac, name, lastRssi).
- Action logs must reference the active session id.
- The `SessionProvider` (Riverpod) exposes the current session and handles start/end.

## UI overlay conventions
- Action entry must be a BottomSheet where possible:
  - Use `showModalBottomSheet` with `isScrollControlled: true` and close with `Navigator.pop(context)`.
  - If deeper navigation is required, use `context.push('/action/new')`.

## Router suggestions (GoRouter)
- Use a central `AppRouter` with route constants in `AppRoute`.
- Example for scanning -> radar navigation with extra:

```dart
// when selecting a device in WirelessScannerScreen
context.push(AppRoute.radar, extra: deviceDescriptor);

// in TrackingRadarScreen
final device = GoRouterState.of(context).extra as DeviceDescriptor?;
```

## Implementation checklist (next work items)
- [ ] Wire `localStorageProvider` in `main.dart` with `HiveStorageImpl.create()` during app bootstrap.
- [ ] Implement `DeviceDescriptor` DTO and `ActionLogModel` + Hive adapters.
- [ ] Create `ActionEntryBottomSheet` UI and repository for saving logs.
- [ ] Implement radar hot/cold tracking provider that accepts a `DeviceDescriptor` and exposes RSSI stream.
- [ ] Implement hardware integration provider `HardwareProvider` for ESP32 alerts.
- [ ] Add tests for route navigation and session start/end flows.

---

If you want, I can now:
- (A) Implement `ActionEntryBottomSheet` and `ActionLogModel`.
- (B) Wire `localStorageProvider` into `main.dart`.
- (C) Generate `DeviceDescriptor` DTO and scaffold `TrackingRadarScreen` extras handling.

Tell me which of A, B, or C to do next.