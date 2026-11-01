# 2026-11-01 — ESP32 easy connect + Sensor nodes dashboard card

Plan: .claude/tasks/plans/2026-11-01-esp32-easy-connect.md

- Firmware 1.1.0: Bluetooth GATT setup alongside the web page (non-blocking WiFiManager), node tests Wi-Fi + host port and reports, hotspot saved in prefs. Built with PlatformIO 6.2 (espressif32 6.x): RAM 17.4 %, flash 42 %.
- App: core IBleGatt wrapper; features/node_setup (protocol, repository, VM, sensor nodes screen, wizard, guide cards); dashboard SensorNodesTile; hall node card gets "Add a sensor node" + guide, old steps under "Without Bluetooth"; routes /nodes, /nodes/add; 131 keys en/bn/ar.
- tools/fake_node.dart verified against the real hall hub (joins, devices arrive, offline when stopped).
- Bug found via screenshots: Wi-Fi form lost the password after a failed attempt → draft kept in the VM (also pre-fills the next node).
- Tests: 882 pass; analyze clean. Not tried on real ESP32 / phone yet.
