# 2026-10-17 — On-device test (Samsung SM-A075F, Android 16) & fixes

## Found on device
1. Location off → 0 BLE results, false "MONITORING LIVE"; enabling Location needed a scan restart.
2. No magnetometer on this phone → unexplained "—".
3. Scanner header took half the screen.
4. Filter with no matches said "Scanning…".
5. Radar map used fake angles.
6. One iPhone shown as 3 "Apple Device" cards (simultaneous addresses).
7. Exit dialog: irreversible "End exam" was the primary button (exam got ended during testing — phone was also being used by someone at the time).
8. PDF works (fonts OK) but plain.
Also from code: connect failure set scanner errorMessage → dashboard "SCAN FAILED".

## Fixed
- Core: location watch + `scanProblem` stream + auto-resume; native `openLocationSettings` (MainActivity MethodChannel).
- Scanner: location banner, one scrolling page with pinned filters, compact cards, precise empty states, stable radar-map dots + honest caption, likely-same-device grouping (expandable, nothing dropped), errors vs notices split.
- Dashboard/RF/radar: Location-off state with "Turn on Location", auto-recover. Magnetic: "no sensor" state. Exit dialog: Minimize primary, End exam needs 2 steps.
- PDF: professional layout (header, details grid, summary boxes, verdict, paged incident table with Category, signatures, footer).
- Translations: 408 keys en/bn/ar.

## Verification
- analyze clean · 226 tests pass · debug APK builds. New build NOT yet installed on phone (it was in use).
