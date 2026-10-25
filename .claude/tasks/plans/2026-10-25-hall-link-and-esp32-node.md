# Plan — Multi-invigilator hall link + ESP32 sensor node

> Status: Phases 1–3 DONE (2026-10-25; firmware compiles, 17% RAM / 38% flash); phase 4 (on-device test) pending · Author: Claude · 2026-10-25
> Decisions (user): Wi-Fi/hotspot + QR join · share **alerts** and **live device list** · ESP32 DevKit (WROOM-32) + Arduino/PlatformIO

## Goal
Several invigilator phones and fixed ESP32 nodes in one exam hall act as one
detector: every phone sees the devices and new-device alerts found by every
other phone/node, with who found it and how far away.

## Architecture
```
 [Host phone]  ← runs Hall Hub (dart:io WebSocket server, port 47800)
    ▲   ▲   ▲      shows QR: ws://<ip>:47800 + join token
    │   │   └── [ESP32 node]  connects to gateway IP (= host's hotspot) with node key
    │   └────── [Phone B]  scans QR → joins
    └────────── [Phone C]
```
- Transport: JSON over WebSocket (dart:io — no package). Host = hub; every
  member (incl. host itself) sends its sightings + alerts; hub relays to all.
- Join: QR shows `examguard://join?ws=ws://IP:47800&t=<token>&room=<room>`.
- ESP32 can't scan a QR: it connects to its Wi-Fi **gateway IP** (the host's
  hotspot) on port 47800 and authenticates with a **node key** shown in the
  app (Settings → Sensor nodes) and copied into the firmware `config.h`.
- Host's own hotspot: trusted via the existing room baseline (taken before
  students enter) — no SSID-name trust (a cheater could copy a name).

## Protocol v1 (all messages `{"t": type, "v": 1, ...}`)
| t | direction | payload |
|---|---|---|
| hello | member→hub | token or nodeKey, member {id, name, kind: phone/node} |
| welcome / reject | hub→member | hall {room}, members[] / reason |
| sightings | member→hub→all | from, items[{id, name, type, mfr, rssi, transport, seenAt}] (batched every 2 s, ≤ 60 strongest, ≥ -90 dBm) |
| alert | member→hub→all | from, alert{deviceId, name, type, transport, rssi, at} |
| members | hub→all | members[{id, name, kind, lastSeen}] |
| ping/pong | both | keep-alive every 5 s; member dropped after 15 s silence |

Honest limit: iPhones report per-phone device UUIDs, so the same device seen
by an iPhone and an Android phone can't always be merged; Android phones and
ESP32 nodes report MAC addresses and merge exactly (rotating random MACs
still differ).

## App work (rules: feature-first MVVM, Notifier, packages wrapped in core/)
**core/**
- `core/services/hall_link/` — `IHallHub` (start/stop server, broadcast,
  members stream) and `IHallClient` (connect/send/messages stream) on dart:io;
  `hall_protocol.dart` message (de)serialisation; local IP lookup via
  `NetworkInterface.list()`.
- `core/services/qr/` — wrappers: `AppQrImage` (qr_flutter) and
  `AppQrScanner` (mobile_scanner). **New packages: qr_flutter, mobile_scanner.**
**features/hall/** (new)
- model: `HallMember`, `RemoteSighting`, `RemoteAlert`, `HallRole`.
- repository: `HallRepository` (hub + client, token/node key, encode/decode).
- view_model: `HallViewModel` (role, members, merged remote devices, remote
  alerts; publishes local scanner sightings/alerts on a 2 s batch).
- view: `HallScreen` (host: QR + members + node key; member: scan QR, status),
  remote-device section, member badges.
**Integrations**
- Scanner: remote devices shown in a "Hall" section/filter with source +
  distance; remote alerts merged into dashboard alerts (source shown).
- Dashboard: "Hall" module card with member count; link-lost warning (never
  shown as all-clear).
- Router: `/hall`; translations en/bn/ar.
**Platform**
- Android: `INTERNET` + `ACCESS_NETWORK_STATE` in main manifest; network
  security config allowing cleartext only for local addresses (ws://).
- iOS: `NSLocalNetworkUsageDescription`; host must stay in foreground
  (wakelock already used) — iOS suspends the server in background.

## ESP32 firmware (`firmware/esp32/`, PlatformIO, Arduino framework)
- Libraries: NimBLE-Arduino (BLE scan + advertise), links2004/WebSockets,
  ArduinoJson.
- Loop: continuous passive BLE scan; Wi-Fi AP scan every 30 s; every 2 s send
  `sightings` (≤ 60 strongest); advertise as `ExamGuard-Node-XXXX` (the app
  already treats that prefix as trusted hardware, not a cheating ESP32);
  reconnect with backoff; status LED (connected / scanning / error).
- `include/config.example.h` → copy to `config.h`: Wi-Fi SSID/password, node
  key, node name, optional hub IP (default: gateway).
- README in `firmware/esp32/` (flash + setup steps).
- Build check needs PlatformIO (`pip install platformio`) — **not installed
  on this Mac; ask before installing.**

## Tests
- Protocol encode/decode round-trips; reject bad token / wrong version.
- Real loopback hub ↔ 2 clients: join, relay sightings/alerts, member drop
  on silence, reconnect.
- HallViewModel with fake link: merge, source tagging, link-lost state.
- Widget: HallScreen host/member at 320×568 light/dark, en/bn/ar.
- Translation guard covers the new keys.

## Phases
1. Core link + protocol + tests (no UI).
2. Hall feature + scanner/dashboard integration + platform config.
3. ESP32 firmware + node key + node display.
4. On-device test: 2 phones + 1 ESP32 on a hotspot.

## Blast radius
New: core/services/hall_link, core/services/qr, features/hall, firmware/esp32.
Changed: scanner view model (publish hook + remote section), dashboard
(alerts merge, module card), router, translations, AndroidManifest,
Info.plist, pubspec (2 packages).
