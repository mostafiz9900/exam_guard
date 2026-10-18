# 2026-10-18 — New features: classic BT, Wi-Fi hotspots, baseline & alerts, seat map, photos, history

## Added
- Classic Bluetooth discovery (Android native EventChannel `exam_guard/classic_bt`), class-of-device classification, "Headset profile" high-suspicion flag.
- Wi-Fi hotspot detection (Android native `exam_guard/wifi`, 30 s scans), SSID/BSSID hotspot classifier, Wi-Fi problem states.
- Scanner: transport badges (BLE / Classic / Wi-Fi), Track only for BLE, trust/untrust.
- Room baseline (dashboard) → trusted devices; new-device alerts (banner, sheet, vibration) with acknowledge / track / log / trust.
- Seat layout at setup; seat picker in incident form; seat heat map in report + PDF.
- Photo evidence (image_picker + path_provider wrapped in core), thumbnails, viewer, PDF photo section; no orphan files.
- Exam history screen (only when no exam is running; read-only reports).
- New incident categories: Wi-Fi Hotspot, Classic Bluetooth Earpiece.
- Translations: 512 keys en/bn/ar.

## Verification
- analyze clean · 352 tests pass · debug APK builds.
- Live device test pending (Samsung disconnected).

## Known limits
- Alert sound: vibration only on phones (SystemSound.alert is desktop-only).
- Alerts/trust-dedupe not persisted across app restart (trusted ids are).
- PDF embeds photos at capture size (≤1600 px); no extra downscaling.
- No background (screen-off) monitoring yet.

## Follow-up — stable scanner list + finder tools (2026-10-18)
- Scanner list: stable order (new devices appended + "N new ↓" pill), optional Nearest-first (3 s throttle, 4 dB hysteresis), smoothed RSSI + label hysteresis, sticky groups, muted "last seen" before eviction, 250 ms publish coalescing.
- Finder: radar proximity meter (0–100 %, peak hold, warmer/colder, haptics), Walk & find (1–5 devices, pocket mode, zone alert with debounce), Seat sweep (sample per seat → most likely seat + confidence), wakelock wrapper.
- Live test (Samsung A07): dashboard alerts/baseline/no-sensor OK; scanner list stable (identical screenshots 3 s apart); classic BT + Wi-Fi detection live (BLE 10 · Classic 1 · Wi-Fi 13).
- Fixed from live test: HP "DIRECT-…-HP Smart Tank" printer was labelled a hotspot; Wi-Fi entries went QUIET because a throttled scan doubled the gap → Wi-Fi scan every 35 s, classic/Wi-Fi quiet after 75 s, removed after 150 s.
- Live test stopped: phone was in use by someone else. Not yet tested on device: radar finder meter, walk finder, seat sweep, photos, seat map, history, PDF.
- Polish noted: Flutter default launcher icon/splash; Wi-Fi card shows "Wi-Fi" chip twice; device count repeated in two header rows.
- analyze clean · 413 tests pass.
