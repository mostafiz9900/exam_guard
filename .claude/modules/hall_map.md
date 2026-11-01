# Module: hall_map (locate devices on the seat map with ESP32 nodes)

**Confidence**: high for logic (unit + widget tests); not tried with real nodes yet.

## What
- `/hall-map` (needs a running exam). Entry: Sensor nodes screen → "Open hall map".
- Seat layout form if the exam has none (`SeatLayoutDraft`, `SessionViewModel.setSeatLayout`).
- Place nodes: ✎ in the app bar → pick node chip → tap seat. Saved per room (`hall_map_nodes_<RoomProfile.keyOf>` JSON in ILocalStorage), one node per seat.
- Map (`HallMapCanvas`): seats, node markers, device area circle (radius) + dot; dots sitting on a node are nudged toward the room centre. Map is always LTR.
- Device sheet: likely seat, ±m, confidence, per-node ≈m/dBm, "Log incident at C4" (ActionEntryArgs.seat + notes), "Walk to it with the radar" (Android only — nodes report MACs, iOS uses UUIDs).

## Logic
- `HallLocator` (model): log-distance (DistanceEstimate) → seats (1.2 m/seat); 1 node = node position + radius d (low); ≥2 = weighted least squares from 1/d²-weighted centroid, clamped to the room; radius 0.5 + rms + 0.2·nearest (0.7–5 seats); good = ≥3 nodes and radius ≤ 1.8.
- Calibration: nodes hear each other's advertised names (= member names) at known distances → median path-loss exponent (1.6–4.0), pairs ≥ 1.5 m.
- `buildHallMap` (pure, tested): only live placed nodes locate; skips ExamGuard names, room equipment, trusted ids (scanner read only if it already exists); alerts first, then confidence, then RSSI; max 30.

## Files
lib/features/hall_map/{model/hall_locator.dart, repository/hall_map_repository.dart, view_model/hall_map_view_model.dart, view/hall_map_screen.dart, view/widgets/hall_map_canvas.dart}
Also: ActionEntryArgs.seat (incident form preselects it), routes, 37 keys en/bn/ar, fake_node.dart [name] [id].

## Tests
test/features/hall_map/ — `MAP_SHOTS=<dir>` for screenshots.

## Changelog
- 2026-11-01 created
