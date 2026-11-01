# Module: node_setup (ESP32 sensor nodes)

**Confidence**: high (unit + widget tests; firmware compiles; not yet tried on real hardware)

## What
- `/nodes` **SensorNodesScreen**: header (live/offline), hall readiness (host button), node list (live + offline, dismiss), "Add a sensor node", guide cards (what to buy, firmware install, LED, placement), node key.
- `/nodes/add` **NodeSetupScreen** wizard: Power → Find (BLE scan for `ExamGuard-Setup-*`) → Wi-Fi (networks the node sees, password, name, advanced host address) → node tests live (send / join Wi-Fi / reach host / save) → Done (waits for the node in the hall, offers hosting).
- Dashboard **SensorNodesTile** (features/dashboard): none → "Set up"; live count + devices heard; offline → red. Offline nodes moved here from HallLinkTile.
- Not in `requireActiveSession`: nodes can be set up before an exam.

## Files
- model/node_setup_protocol.dart — UUIDs, encode/decode, statuses (mirror of firmware "Setup" section)
- repository/node_setup_repository.dart — `nearbyNodes()` (scan owner `node_setup`), `connect()` → `NodeSetupLink` (rescan, apply → status stream), last SSID
- view_model/node_setup_view_model.dart — steps, draft (memory only), validation (WPA2 ≥ 8)
- core: services/bluetooth/i_ble_gatt.dart + ble_gatt_impl.dart (flutter_blue_plus GATT)
- firmware/esp32/src/main.cpp (runSetup), README, tools/fake_node.dart

## Tests
test/features/node_setup/ — fakes mimic the firmware (node_fakes.dart).
Screenshots: `NODE_SHOTS=<dir> flutter test test/features/node_setup/node_setup_screens_test.dart`

## Changelog
- 2026-11-01 created (Bluetooth setup, sensor nodes screen, dashboard tile, fake node tool)
