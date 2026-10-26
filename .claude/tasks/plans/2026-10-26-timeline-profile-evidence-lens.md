# Plan — Device timeline, room profile, report evidence, lens finder

> Status: IN PROGRESS · 2026-10-26 · user asked for all four "at a professional level"

## 1. Device timeline (scanner)
- `PresenceTracker` (pure, tested): per device presence intervals, RSSI samples
  every 5 s (30 min window), reappearance count; *toggling* = ≥ 3 reappearances
  after ≥ 15 s silence within 10 min. Rotated random addresses are merged.
- Scanner VM feeds it on sightings/evictions; `ScannerState.togglingIds` for
  badges; `historyOf(id)` for the details sheet (not in state: no churn).
- UI: "Activity" section in the device details sheet (signal chart with gaps,
  first/last seen, time present, reappearances); "Toggling" badge on cards.

## 2. Room profile
- Saved on baseline per normalized room number: stable devices only — Wi-Fi
  APs, classic BT, named BLE devices (not phones/earbuds: they rotate and are
  what we must flag). Stored via ILocalStorage `room_profile_<room>`.
- New session in that room → equipment pre-trusted; dashboard baseline card
  says "Room profile: N known devices"; baseline still recommended.
- Profile review/remove items; clear profile.

## 3. Report evidence
- Incident logged from a device → `ActionLogModel.evidence` = signal trace
  (last 10 min) + presence summary from the tracker.
- Session keeps per-minute "devices in range" samples.
- Report screen: mini chart on incident cards + exam activity chart.
- PDF: activity chart + per-incident signal charts (`PdfChart` in PdfTableDocument).

## 4. Lens finder (delegated agent)
- `camera` package wrapped in `core/services/camera_stream/`; feature
  `features/lens_finder/`; torch on; detect small, bright, *stable* glints in
  the Y plane; overlay + haptic; honest disclaimer. Route `/lens-finder`.
- Agent does not touch dashboard/translations directly (strings handed over).

## Blast radius
scanner VM + details sheet + card; session model/VM (profile, samples);
action_log model/VM (evidence); report repository/screen/widgets; pdf service;
dashboard (profile line, lens finder card); router; translations; pubspec.
