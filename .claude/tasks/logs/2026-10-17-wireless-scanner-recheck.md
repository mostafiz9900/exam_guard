# 2026-10-17 — Wireless scanner recheck (not live / wrong names / duplicates)

## Root causes & fixes
| Symptom | Cause | Fix |
|---|---|---|
| Not live | Double radio start per scan start (adapter listener + startScan) → Android scan throttle (5 starts/30 s) silently drops results; start/stop races could leave owners set with radio off | `BluetoothServiceImpl`: serialized `_serial(_sync)` reconcile |
| Not live, no message | `startScan` errors (e.g. Location off on Android ≤11) only logged; UI showed "LIVE • 0" | `BleScanException` thrown/forwarded; VM shows message and `isScanning=false` |
| Missing devices | Manifest `BLUETOOTH_SCAN neverForLocation` filters beacons | Flag removed |
| Names wrong / flicker | Name taken only from current packet; inferred name frozen into `name`; category recomputed per packet | FBP cached `advName` fallback; repository merges per-device data; `displayName` builds fallback live |
| Wrong category | `180A` (Device Information) treated as audio; "huawei" → hotspot; "ear" matched "gear"/"year"; hotspot filter `'ap'` matched "Apple" | Real audio UUIDs + Apple proximity-pairing (AirPods); removed false keywords |
| Duplicates | Random address rotation; stale entry lingered 30 s | `_rotatedFrom` merge (same identity, old silent ≥5 s); list items keyed by id |
| Double permission prompt / error snackbar on open | VM build + screen both started scanning | Shared in-flight `_starting` future |

## Files
- lib/core/services/bluetooth/{i_bluetooth_service,bluetooth_service_impl}.dart
- android/app/src/main/AndroidManifest.xml
- lib/features/scanner/{model/scanned_device_model,repository/scanner_repository,repository/bluetooth_device_inspector,view_model/scanner_view_model,view/wireless_scanner_screen}.dart
- lib/features/action_log/view/action_entry_screen.dart (prefill displayName)
- test/features/scanner_provider_test.dart (+8 tests)

## Verification
- analyze: no issues · tests: all pass
- Needs on-device check (Android 12+): reinstall app (manifest permission change).
