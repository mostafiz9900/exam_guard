# 2026-10-17 — Full app review & fixes (senior review)

Reviewed by 3 parallel reviewers (shell/dashboard, detectors, records/report), fixed by 3 parallel devs with disjoint file ownership, integrated + verified.

## Dashboard / shell
- Status chip & empty state reflect real scan state (Bluetooth off / scan failed / stopped) — no fake "MONITORING ONLINE".
- Magnetic badge: "—" without sensor; strongSource is red.
- App bar contrast fixed; End Exam is a filled red button; End Exam errors handled.
- Back-button dialog honest (exam keeps running) + "End exam & view report".
- "Session Setup" dead card → "Report" card. Strong signal = red everywhere (dashboard, scanner card) at -65/-75 dBm.
- Rebuild cost reduced (small widgets with select). Dashboard fully localized (en/bn/ar, 104 keys).
- Theme: onPrimary white; ElevatedButton no forced infinite width; theme choice persisted.
- CustomTextField error text not clipped, RTL-correct padding. PrimaryButton keeps label while loading.
- Setup: "View last report" for the last ended exam; animation leak fixed.

## Detectors
- Radar: smoothed RSSI, stable trend, threat derived from distance, txPower-aware, honest painter (distance ring, no fake bearing), signal-lost greys out, acquiring state, errors + retry.
- RF: not-measuring state, BT-off handling, start/stream errors surfaced, "esp32" no longer trusted as ExamGuard node.
- Magnetic: delta-based hazard, honest sensitivity labels, peak on every sample, calibrate only when live, paused/unavailable states.
- Buzzer muted while incident form is open; incident form prefilled with category + reading.

## Records / report
- PDF: bundled Noto fonts (Latin/Bengali/Arabic), RTL Arabic; safe file names; iPad share anchor.
- Incident: save-then-share (no unsaved "official" reports), category/notes prefill, multi-line notes, honest copy/share feedback, reentrancy guard, ended-exam message, generic user errors.
- Report screen: start/end/duration, no duplicate totals, "ID" label, theme colours.
- Session storage: corrupt entries skipped (no startup crash), non-atomic pointer writes tolerated.

## Known limitations / follow-ups
- Bangla in PDF: glyphs render but vowel-sign ordering/conjuncts may be wrong (no Indic shaping in `pdf`).
- Localization done for dashboard/setup/core; radar, RF, magnetic, scanner, report, incident screens still English.
- RF tick stops the shared buzzer (only matters if RF screen stays under another detector).

## Verification
- `fvm flutter analyze`: no issues · `fvm flutter test`: 188 passed · debug APK build: see session.

## Follow-up (same day) — "finish next"
- Localized all remaining screens (scanner, incident entry, radar, RF, magnetic, report): translations now 376 keys, identical in en/bn/ar, placeholders checked. Model enums expose `labelKey`s; view models store message keys (`errorMessage`/`errorKey`/`messageKey`), views call `.tr()`.
- Left English on purpose: PDF + shared text report (official record), stored values (incident category, severity code), device identifiers, units.
- `BleScanException.code` (`BleScanError.locationOff/throttled/other`) — callers no longer match English message text.
- RF meter only stops the shared buzzer if it started it (no longer silences radar/magnetic).
- Remaining limitation: Bangla shaping in PDF (pdf package has no Indic shaping).
- Verification: analyze clean, 189 tests pass, debug APK builds.
