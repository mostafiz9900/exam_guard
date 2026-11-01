# Module: radar — direction finder (turn around)

**Confidence**: medium. The logic is unit-tested with simulated body shadow; not yet tried on real phones in a hall.

## What
- Radar screen → "Find direction (turn around)", shown for BLE targets while the signal is live.
- `DirectionFinderSheet` (bottom sheet):
  - Heading-up compass rose: N/E/S/W, the hall FRONT marker, signal per 10° wedge, and the result arrow.
  - Ready (3 steps) → turning (coverage bar, "slower" and "no signal" notes) → done:
    - hall word (back-left…) when a front is set, plus the compass word (South-west, 230°);
    - confidence chip, and a turn left/right hint;
    - or "unclear" / "incomplete".
- "Set the front of the hall" saves a per-room heading: `hall_front_heading_<RoomProfile.keyOf>`.

## How
- `IHeadingService` (core/services/sensors):
  - EventChannel `exam_guard/heading` sends [degrees, accuracy].
  - Android: `HeadingSensor.kt`, rotation vector, 20 Hz.
  - iOS: `HeadingStream` in AppDelegate, Core Motion `.xMagneticNorthZVertical` `heading`.
  - The error code `unavailable` becomes `HeadingUnavailableException`.
- `DirectionFinder` (model):
  - 36 bins of 10°; at least 75 % coverage needed.
  - Bearing = phase of the first harmonic (cosine fit). Picking the strongest bin was off by up to 20° with ±3 dB fading.
  - Contrast = peak-to-trough of the fit. Good ≥ 8 dB with a ≥ 2 dB margin over any rival ≥ 90° away; fair ≥ 4 dB; otherwise unclear.
- `DirectionFinderViewModel`:
  - Uses the target's aliases (FinderAliases), so a rotated address counts.
  - Finishes by itself at 92 % coverage, or after 40 s.
  - "Too fast" above 70°/s; "no signal" after 3 s of silence.

## Tests
- test/features/radar/direction_finder_test.dart: 30 noisy cases, all within 10°.
- test/features/radar/direction_finder_view_model_test.dart: view model and sheet; `DIR_SHOTS=<dir>` for screenshots.

## Changelog
- 2026-11-01 created
