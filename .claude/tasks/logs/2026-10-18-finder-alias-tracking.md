# 2026-10-18 — Finders follow every address of a device; seat layout from seat sweep

- Scanner: `_identityRoot` (rotated id → first id, kept after the old id is forgotten), `aliasesOf(id)` (rotation chain + live multi-address groups, closure), `ScannerState.identityVersion` (bumped on rotation and when multi-member group membership changes; signature computed in `_publish`).
- RadarRepository: `watchAll()`.
- New `features/radar/view_model/finder_aliases.dart` (`FinderAliases`: listens to `identityVersion`, falls back to `{id}`).
- Radar / walk finder / seat sweep use `watchAll()` + aliases. Walk finder maps address → target.
- Seat sweep: inline "Set seat layout" form (`SeatLayoutDraft` validation in the VM, `SessionViewModel.setSeatLayout`), "not heard for 10 s" hint (`isNotHeard`, blocks sampling, `checkHeard`).
- Tests: `FakeScanner` in test/features/radar/finder_fakes.dart (finder tests must override `scannerViewModelProvider`).
- New keys: sweep_layout_form_text, sweep_layout_saved_note, sweep_layout_set, sweep_layout_save_failed, sweep_not_heard_hint (fragments in scratchpad i18n5, not yet merged into assets/translations).

## Live verification (Samsung A07, 2026-10-18 13:45)
- Root causes confirmed: finders listened to one BLE address (phones use several + rotate) AND the scanner hid "Seat sweep" when the exam had no seat layout (Room 111 had none).
- Fixed: finders follow the scanner's device identity (aliasesOf / identityVersion); Seat sweep always offered for BLE; inline seat layout form.
- On device: Apple Device "+4 IDs" → ⋮ → Seat sweep → layout form → 3×3 set → "Live signal: -46 dBm", seat B3 sampled -45 dBm → "Most likely seat: B3 (low confidence, sample neighbours)" → "Log incident at B3" prefilled notes. Works.
- Note: a 3×3 seat layout was saved on test exam Room 111 during the check; someone else was also using the phone (an incident was logged by them).
- Classic BT seen live: "soundcore R50i" → Smart earpiece + Headset profile, -36 dBm.
