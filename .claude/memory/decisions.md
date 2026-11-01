# Architecture Decisions
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.

[Decisions will be logged here as they are made]

## Template
#### [date] — [Title]
- **Problem**:
- **Options Considered**:
- **Decision**:
- **Reason**:
- **Tradeoffs**:
- **Revisit If**:

---

#### 2026-10-13 — Initial Setup
- **Problem**: Need a structured AI-assisted development system
- **Decision**: Claude Code with .claude/ memory system
- **Reason**: Project-scoped, team-shared, native Claude Code support
- **Tradeoffs**: Requires Claude Code installation
- **Revisit If**: Team grows beyond 10 developers

#### 2026-10-13 — Feature-first + MVVM, no use cases, wrapped packages
- **Problem**: Codebase mixes clean-architecture folders (domain/application/infrastructure), duplicate models and services, and imports packages directly in screens
- **Options Considered**: Clean Architecture with use cases; Feature-first MVVM
- **Decision**: Feature-first + MVVM (model / repository / view_model / view). No use case layer. Manual Riverpod providers (no `@riverpod` codegen). Every third-party package wrapped in a custom class in `lib/core/`
- **Reason**: Less boilerplate, no build_runner, and packages can be swapped or mocked in one place
- **Tradeoffs**: ViewModels hold a bit more logic without use cases; wrappers add a thin layer per package
- **Revisit If**: ViewModels grow large enough that shared business logic is duplicated across features

#### 2026-10-18 — Tracking radar: gauge hero replaces radar rings
- **Problem**: Radar screen was long and busy (meter card, tips, trend banner, threat card, rotating radar rings, info rows, buttons); the gauge was below the fold while walking.
- **Decision**: One hero card (270° closeness gauge, animated value + count-up, peak marker, pulse speed ∝ closeness, warmer/colder pill, one hint line, best-so-far + reset), compact target header, a 4-segment distance band card, collapsible "How to find it", sticky bottom action bar. Sound/vibration toggles in the app bar. `RadarPainter` + `ProximityMeterCard` removed.
- **Reason**: The rotating sweep implied a bearing RSSI doesn't have and duplicated the distance already shown in the gauge; the band card shows the same 1.5/3.5/6 m bands honestly in ~80 dp.
- **Tradeoffs**: Guide sheet replaced by an inline ExpansionTile (`radar_guide_done` key now unused).

#### 2026-11-01 — ESP32 nodes are set up over Bluetooth from the app
- **Problem**: Setting up a node needed a second phone on the "ExamGuard-Setup" Wi-Fi page and typing the hotspot, password and node key by hand.
- **Decision**: In setup mode the firmware is also a GATT server (service `e9a40001-…`). The app (`features/node_setup`) finds it, reads the Wi-Fi networks it sees, writes `{ssid, pass, key, name, hub}` with the hall `nodeKey` filled in, and follows status notifications while the node tests the Wi-Fi and the host port before saving. The web page stays as a fallback; both run at once (WiFiManager non-blocking).
- **Reason**: One phone, nothing typed but the password, and wrong password / 5 GHz hotspot is reported by the node itself instead of a silent slow blink.
- **Tradeoffs**: Firmware grew ~16 KB; GATT ops got a core wrapper (`IBleGatt`) separate from the shared scan service.
- **Revisit If**: Nodes need setting up without the app (then the web page is the path).

#### 2026-11-01 — Hall map shows an area, not a seat
- **Problem**: Invigilators want "which seat", but RSSI varies ±10 dB with bodies and desks.
- **Decision**: Least-squares position from placed nodes with an uncertainty circle and a confidence word (Distance only / Rough / Good); nearest seat is a label, and the screen says to confirm with the radar. Room path loss is learnt from nodes hearing each other.
- **Reason**: Honest output an invigilator can act on (walk to the area) without accusing the wrong student.
- **Revisit If**: Nodes gain direction finding (BLE AoA) or many more nodes per room.

#### 2026-11-01 — App renamed ExamGuard → Pahara ("Exam Hall Security")
- **Decision**: Public name Pahara, ID `com.it24617.pahara.app` (Android applicationId/namespace, iOS/macOS bundle, Linux id). Brand strings via `lib/core/utils/app_brand.dart`. Nodes advertise `Pahara-…`, setup `Pahara-Setup-…` (Wi-Fi password `pahara123`), hall QR `pahara://`, report `pahara_room_…pdf`.
- **Kept**: Dart package `exam_guard` (imports only; renaming conflicts with teammates' branches), platform channel names `exam_guard/*`, project folder.
- **Compatibility**: `AppBrand.isNodeName` and `HallInvite.parse` still accept `ExamGuard…` / `examguard://`.
- Store docs: docs/store/ (listings, privacy policy + Blogger HTML, data safety, rating, review notes, release checklist).
