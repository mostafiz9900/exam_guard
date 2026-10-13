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
