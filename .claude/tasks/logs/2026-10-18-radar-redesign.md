# 2026-10-18 — Tracking radar (find page) redesign

Behaviour unchanged (view model untouched). View only.

- New widgets (lib/features/radar/view/widgets/): closeness_colors.dart (closenessColor moved here + readableInk/trendColor/threatColor), closeness_gauge.dart (ClosenessGauge + GaugePainter, GaugeMode live/acquiring/lost/off, pulse via useAnimationController, MediaQuery.disableAnimations respected, AppShimmer skeleton while acquiring), radar_hero_card.dart, radar_target_header.dart (long-press copies address, trusted mark from ScannerState.isTrusted), distance_band_card.dart, radar_how_to_find.dart, radar_action_bar.dart, radar_sizes.dart (`.rc`).
- Removed: proximity_meter_card.dart, radar_painter.dart. walk_finder/seat_sweep import closeness_colors.dart.
- Issue states reuse FinderIssueBanner (locationOff / throttled / failed → retry).
- Tests: new test/features/radar/tracking_radar_screen_test.dart (6 states × 360x800/320x640 × light/dark × en/ar, + bn, 600x960, 800x360, toggles/reset/guide/copy, reduced motion). SCREENSHOTS=1 → build/screenshots/radar_*.png; RADAR_I18N_EXTRA / FONTS_DIR optional.
- New keys (scratchpad i18n6/radar.{en,bn,ar}.json, NOT yet merged into assets/translations): radar_signal_lost_short, radar_status_live/searching/lost/off, radar_copy_id_hint, radar_id_copied, radar_band_within, radar_band_range, radar_distance_band_title, radar_how_to_find, radar_find_seat.
