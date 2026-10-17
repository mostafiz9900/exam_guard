# Gotchas
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Run /r-memory-scan to auto-fill from codebase.

[Gotchas will be added here as they are discovered]

## Template
#### [Module] — [Title]
- **What Happens**:
- **Why**:
- **How to Avoid**:
- **Discovered**:

#### core/audio — Restarting a periodic Timer on every update starves it
- **What Happens**: Radar/RF buzzer never beeped — `updateTargetDistance` cancelled and recreated `Timer.periodic` on every call, and callers update faster (BLE adverts ~100 ms, RF tick 250 ms) than the beep interval (120–1000 ms).
- **Why**: Each new timer is cancelled before its first tick.
- **How to Avoid**: Keep one self-rescheduling one-shot timer; updates only change the interval it reads next. Regression test: `test/core/geiger_buzzer_service_test.dart`.
- **Discovered**: 2026-10-17

#### Riverpod — Non-autoDispose live-hardware ViewModels keep running forever
- **What Happens**: BLE scan + magnetometer kept running after End Exam (report/setup screens), draining battery.
- **Why**: `scannerViewModelProvider` / `magneticViewModelProvider` were plain `NotifierProvider`s, so they outlived the dashboard.
- **How to Avoid**: ViewModels that own a sensor/radio subscription must be `.autoDispose`.
- **Discovered**: 2026-10-17

#### flutter_hooks — `useAnimationController(...)..repeat()` in build
- **What Happens**: `repeat()` re-runs on every rebuild (dashboard rebuilds per BLE advert).
- **How to Avoid**: Call `repeat()` inside `useEffect(..., [controller])`.
- **Discovered**: 2026-10-17

#### core/bluetooth — Overlapping startScan calls trip Android's scan throttle
- **What Happens**: Scanner list froze ("not live") with no error.
- **Why**: FBP `startScan` stops+restarts a running scan. Our adapter listener (emits `on` immediately) and `startScan` both started the radio → 2 starts per start; Android silently drops all results for 30 s after 5 starts in 30 s.
- **How to Avoid**: All start/stop goes through `BluetoothServiceImpl._serial(_sync)` (one at a time, reconcile to owners). Never call `FlutterBluePlus.startScan` directly elsewhere.
- **Discovered**: 2026-10-17

#### Android manifest — `neverForLocation` on BLUETOOTH_SCAN hides beacons
- **What Happens**: Some BLE devices never appear on Android 12+.
- **Why**: With `usesPermissionFlags="neverForLocation"` Android filters beacon results. We need location-derived results anyway (`androidUsesFineLocation: true`).
- **How to Avoid**: Keep the flag off.
- **Discovered**: 2026-10-17

#### scanner — Per-packet classification flickers; random-address rotation looks like duplicates
- **What Happens**: Names/categories flipped between packets; the same phone/earbud showed twice for ~30 s.
- **Why**: Android delivers advertisement and scan response separately (name often only in one). Phones/earbuds rotate random MAC every few minutes; old entry lingered until eviction.
- **How to Avoid**: `ScannerRepository` merges per-id advertised data (`_AdvertisedProfile`); use FBP's cached `device.advName`. `ScannerViewModel._rotatedFrom` replaces a ≥5 s silent entry with the same identity. `ScannedDeviceModel.name` holds only the advertised name — fallback labels come from `displayName`.
- **Discovered**: 2026-10-17

#### radar — Raw RSSI must be smoothed before it drives trend/distance
- **What Happens**: Trend banner flipped approaching/receding several times a second; distance jumped metres per packet.
- **Why**: BLE RSSI noise is ±3–6 dB per packet at 10–30 packets/s.
- **How to Avoid**: `RssiTrendFilter` (time-based EMA, compare to 1.5 s ago, ≥3 dB + hysteresis, skip the first second). Threat comes from distance (1.5/3.5/6 m), not separate RSSI cutoffs.
- **Discovered**: 2026-10-17

#### magnetic — Hazard levels must use change from baseline only
- **What Happens**: Some presets stuck on "anomaly", critical unreachable, calibration useless.
- **How to Avoid**: elevated > T, critical > 2T, strong > 4T (or > 200 µT) with T = 35/20/10 µT. Phone magnetometers sense magnets at a few cm, never metres — don't label ranges in metres.
- **Discovered**: 2026-10-17

#### UI — Never show "all clear" while not measuring
- **What Happens**: Dashboard/RF/magnetic showed green "online / quiet / normal" with Bluetooth off or no sensor.
- **How to Avoid**: Every detector screen has an explicit not-measuring state (grey banner + reason + Retry). Null reading ≠ safe.
- **Discovered**: 2026-10-17

#### Shared buzzer — mute it under the incident form
- **How to Avoid**: Detector screens call `setAlertsSuspended(true)` before `await pushTo(actionNew)` and resume after. Note: RF tick calls `stopBuzzer` on the shared singleton — don't keep RF open under radar/magnetic.
- **Discovered**: 2026-10-17

#### PDF — built-in Helvetica is Latin-1 only
- **What Happens**: Bangla/Arabic text, "—" and curly quotes rendered as boxes.
- **How to Avoid**: `PdfServiceImpl` loads bundled Noto fonts (assets/fonts, OFL) with per-text script detection (Arabic → RTL). Limitation: pdf package has no Indic shaping, so Bangla vowel signs/conjuncts may be misordered.
- **Discovered**: 2026-10-17

#### share_plus — file names are used as temp paths
- **What Happens**: Room "12/B" crashed PDF export.
- **How to Avoid**: Always pass names through `safeFileName()` (core/services/share).
- **Discovered**: 2026-10-17
