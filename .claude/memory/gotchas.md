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

#### Android BLE — Location OFF = zero scan results (Android 12+ too)
- **What Happens**: Scanner showed "LIVE • 0 DEVICES" forever on a Samsung A07 (Android 16) with Location off; enabling Location later didn't help until the scan restarted.
- **Why**: Without `neverForLocation`, Android only delivers BLE results while Location is on. FBP only checks this on Android ≤ 11.
- **How to Avoid**: `BluetoothServiceImpl` polls the Location service every 2 s while scanning, publishes `scanProblem` (`BleScanError.locationOff`), stops the radio, and restarts it automatically when Location returns. Screens show "Turn on Location" (native `exam_guard/system` → `openLocationSettings`).
- **Discovered**: 2026-10-17 (on-device test)

#### Devices without a magnetometer exist (Galaxy A07)
- **How to Avoid**: `MagneticState.isSensorUnavailable` → explicit "no magnetometer" UI; dashboard shows "No sensor". Never show "—" without a reason.
- **Discovered**: 2026-10-17

#### Scanner state — blocking errors vs one-off notices
- **How to Avoid**: `errorMessage` = blocking scan problem (drives dashboard "SCAN FAILED"); `noticeKey`/`noticeId` = snackbar-only (connect failed etc.).
- **Discovered**: 2026-10-17

#### Classic BT discovery degrades BLE scanning
- **How to Avoid**: `ClassicBluetoothServiceImpl` runs ~12 s inquiries with 20 s pauses while owners exist. Classic discovery also returns nothing with Location off (like BLE).
- **Discovered**: 2026-10-18

#### Wi-Fi scan permission differs from BLE
- **How to Avoid**: NEARBY_WIFI_DEVICES uses `neverForLocation` (Wi-Fi results aren't filtered); BLUETOOTH_SCAN must NOT (beacons get filtered). Android throttles foreground Wi-Fi scans to 4 / 2 min → `WifiScanServiceImpl` scans every 30 s. Developer option "Wi-Fi scan throttling" changes behaviour on test phones.
- **Discovered**: 2026-10-18

#### Riverpod 3 filters updates with == — keep model equality complete
- **What Happens**: `SessionModel ==` ignored new fields → trusting a device wouldn't notify listeners.
- **How to Avoid**: When adding fields to a state model, add them to `==`/`hashCode`.
- **Discovered**: 2026-10-18

#### Classic BT inquiry starves BLE → finder/RF dropouts (seen live on Samsung A07)
- **What Happens**: Walk finder targets went "not heard" and the RF meter read "0 transmitters / QUIET" every ~30 s.
- **Why**: The dashboard keeps the scanner (and its classic discovery owner) alive; each ~12 s inquiry starves BLE.
- **How to Avoid**: Finder screens (radar, walk, sweep) and the RF meter call `suspend(owner)` on classic + Wi-Fi services via their repositories and `resume` on stop. Background classic duty cycle: 12 s inquiry per ~57 s.
- **Discovered**: 2026-10-18 (live test)

#### Finders — never listen to one fixed BLE address
- **What Happens**: Radar stuck on "Acquiring signal…", seat sweep read "No signal" at every seat (Samsung A07 live test).
- **Why**: Phones/earbuds advertise from several random addresses at once (scanner groups them) and rotate them every few minutes; `watchDevice(id)` heard only the tapped address.
- **How to Avoid**: Finders subscribe to `RadarRepository.watchAll()` and filter by `FinderAliases.of(id)` (→ `ScannerViewModel.aliasesOf`), refreshed when `ScannerState.identityVersion` changes. Smoothing/alarms stay per target, not per address.
- **Discovered**: 2026-10-18 (live test)

#### Tests — don't wait real seconds for the radar's "signal lost"
- **What Happens**: A screen test using `tester.runAsync(() => Future.delayed(5 s))` hung until the 10-min timeout under full-suite load.
- **Why**: `TrackingRadarViewModel` decides "lost" from `DateTime.now()` (wall clock), so fake time can't trigger it.
- **How to Avoid**: For screen rendering, override `trackingRadarViewModelProvider` with a subclass whose `build()` returns a fixed state (see `_FixedRadar` in test/features/radar/tracking_radar_screen_test.dart).
- **Discovered**: 2026-10-18

#### Theme text styles scale with width in landscape
- **What Happens**: `bodySmall` (12.sp in AppTheme) rendered ~25 px at 800×360; extra `.sp` overrides doubled it again.
- **How to Avoid**: For small captions on screens that must work in landscape, prefer M3 `label*` styles; never add `fontSize: x.sp` on top of a theme style. `.r` shrinks in landscape — radar widgets use `.rc` (radar_sizes.dart, floor 90 %).
- **Discovered**: 2026-10-18

#### core/permission — Android-only permissions are "permanently denied" on iOS
- **What Happens**: iPhone always showed "Bluetooth/Location permission was permanently denied", no prompt.
- **Why**: permission_handler maps `bluetoothScan`/`bluetoothConnect` to `UnknownPermissionStrategy` on iOS, which answers `permanentlyDenied`. Also: with SPM (no Podfile) permissions are enabled from Info.plist keys only when built from the project dir; builds from Xcode.app compile every permission out.
- **How to Avoid**: Request `Permission.bluetooth` on iOS. Build with `fvm flutter run`; after Info.plist changes clear DerivedData.
- **Discovered**: 2026-10-25

#### go_router — refreshListenable on every session edit re-creates pushed pages
- **What Happens**: After "Save record" the incident form re-opened empty instead of closing.
- **Why**: `addLog` changed the session → router refresh → pushed page rebuilt, so the old screen's `popBack()` closed nothing.
- **How to Avoid**: Router listens only to `(session != null, isActive)` — what `appRedirect` depends on.
- **Discovered**: 2026-10-25

#### UI — `.w` keeps scaling past the dashboard's 800 px max width
- **What Happens**: Module cards overflowed on tablets / landscape (> 650 px, 3 columns).
- **How to Avoid**: Wide grid uses rows sized by content (IntrinsicHeight); fixed-size children in width-capped layouts must be able to shrink (FittedBox/Flexible).
- **Discovered**: 2026-10-25

#### Tests — ScreenUtil scale and rootBundle futures leak between widget tests
- **What Happens**: A tablet responsive test passed in the full file but failed alone (it reused a phone test's scale), hiding a real overflow. Later tests hung on translations cached in a finished test's zone.
- **How to Avoid**: Run size-specific tests in isolation when checking layout; call `rootBundle.clear()` in `setUp`. Load real Roboto (see `loadFonts()` in responsive_test) — the default test font fakes overflows.
- **Discovered**: 2026-10-25

#### i18n — Missing keys render as the raw key on screen
- **What Happens**: Radar showed "radar_band_range", "radar_status_live" etc. (12 keys never added to the JSON files).
- **How to Avoid**: `test/core/localization/translation_keys_test.dart` fails on any literal `'key'.tr()` missing from en/bn/ar. Keys built at runtime (`'mag_level_$name'`) aren't covered — grep test output for "Localization key [...] not found".
- **Discovered**: 2026-10-25

#### UI — Show distance, not dBm, to invigilators
- **How to Avoid**: Use `approxDistanceText` / `signalSummaryText` (features/scanner/view/distance_text.dart), backed by `DistanceEstimate` (shared with radar). Whole metres only; BLE only — Wi-Fi/classic keep dBm (different transmit power / no real level).
- **Discovered**: 2026-10-25

#### scanner — Most BLE devices advertise no name; Settings only lists paired / pairing-mode devices
- **What Happens**: Users compare with the phone's Bluetooth settings and ask why most scanner entries are "Hidden BLE Device".
- **How to Avoid**: Phones/AirPods/watches omit names for privacy. ScannerViewModel auto-identifies: every 4 s connects to the strongest nameless, connectable, non-Apple, non-phone device ≥ -80 dBm (once per id, max 40 per scan, never while the user is connected), reads GAP name 0x2A00, disconnects. OS-known names (`knownDeviceNames`: Android bonded + connected system devices) are applied on sighting.
- **Discovered**: 2026-10-25

#### iOS BLE — Apple devices arrive stripped; RSSI 127 means "unknown"
- **What Happens** (on-device capture, iPhone, 2026-10-25): AirPods/iPhones/Macs arrive with NO name, NO manufacturer data, NO services (iOS hides Apple Continuity data from apps) — looked like "Hidden BLE Device". A device's first packet sometimes has `rssi=127` (iOS: unavailable), which seeded the smoother as "closest device".
- **How to Avoid**: `BluetoothServiceImpl` drops packets with rssi ≥ 0 and sets `BleScanRecord.isPayloadHidden` on iOS for fully empty adverts → repository labels them `ScannedDeviceModel.appleHiddenType` (manufacturer Apple). Never group them (nothing distinguishes them); audio + smartphone filters include them. iOS can't tell AirPods from an iPhone, and can't see classic-only (connected) earbuds at all — Android is the stronger invigilation phone.
- **Discovered**: 2026-10-25

#### hall — Local link needs platform switches; host must stay in foreground on iOS
- **What Happens**: dart:io sockets fail in release Android builds without `INTERNET`; `ws://` is refused unless cleartext is allowed; iOS asks for Local Network permission (needs `NSLocalNetworkUsageDescription`) and suspends the hub in background.
- **How to Avoid**: Manifest has INTERNET + ACCESS_NETWORK_STATE + `usesCleartextTraffic`; Info.plist has the local-network text. `hallViewModelProvider` is NOT autoDispose (lives for the exam) — it leaves the hall itself when the session ends. The hub rewrites `from` on relayed messages (never trust the sender's claim). ESP32 nodes expect port 47800 at the hotspot gateway — don't change `HallRepository.defaultPort` without updating firmware.
- **Discovered**: 2026-10-25

#### firmware/esp32 — A header named config.h collides with the ESP32 toolchain
- **What Happens**: `__has_include("config.h")` found another config.h on the Arduino-ESP32 include path; every setting was "not declared".
- **How to Avoid**: Node settings live in `include/node_config.h` (git-ignored; template `node_config.example.h`). Nodes send raw clues (mfid/mfb/svc/SSID, no `type`) — the app classifies them in `HallProtocol.decodeSightings`, so firmware never needs category rules. Keep hello/sightings shapes in step with `hall_protocol.dart`.
- **Discovered**: 2026-10-25

#### firmware/esp32 — Setup portal must never open automatically on Wi-Fi failure
- **What Happens**: Common WiFiManager examples fall back to a config AP when Wi-Fi fails; in an exam that opens a setup network exactly when the hotspot is off.
- **How to Avoid**: Portal only on first start (no key / no Wi-Fi) or BOOT held 3 s; password (`SETUP_PASSWORD`), 5-min timeout, restart afterwards. Tampering shows up in the app as "Sensor node offline" (HallState.offlineNodes). Node alerts are raised by the HOST with `NodeAlertTracker` (phone scanner rules + rotation handling), not by the node.
- **Discovered**: 2026-10-25

#### Tests — InputDecorator keeps a cleared error Text in its crossfade stack
- **What Happens**: After a field's error cleared, `find.text(error)` still found it (inside `_HelperError`'s FadeTransition), even after the fade.
- **How to Avoid**: Assert `tester.state<FormFieldState<String>>(...).hasError`, not the text. Also: screens that show a summary of field errors must listen to the controllers (`useListenable`), or the summary goes stale while typing. Setup form rules live in `SessionFormValidator` (features/session/model).
- **Discovered**: 2026-10-25

#### UI tests — Shadows can't be judged from test screenshots
- **What Happens**: BoxShadow / Material elevation render as hard grey/black bands in `toImage` captures of widget tests.
- **How to Avoid**: For sheets/cards that must look clean everywhere, use a thin `outlineVariant` border instead of a shadow (setup screen does). The setup header art is `ExamHallBackdrop` (CustomPainter, no image asset); its radar sweep repeats via `useEffect` and stops with reduced motion.
- **Discovered**: 2026-10-25

#### scanner — Don't claim "AirPods in ear"
- **What Happens**: Apple's proximity-pairing status byte is undocumented; open-source decoders (LibrePods, LinuxPods, OpenPods) disagree on the bits and captures have contradicted them; AirPods 4 reportedly don't send it.
- **How to Avoid**: Only identify AirPods (type 0x07). Never show in-ear/in-case status — a wrong claim could accuse a student. Covert earpiece names (`BluetoothDeviceInspector.isSpyEarpieceName`: loop / neckloop / induction / spy / nano / hands-free, whole words, not Arduino/iPod) set `isHighSuspicion`.
- **Discovered**: 2026-10-26
