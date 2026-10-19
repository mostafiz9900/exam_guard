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
