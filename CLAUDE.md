# CLAUDE.md — Project Memory

> ⚠️ PROJECT SCOPED: Everything lives in .claude/ only.
> Never read or write outside this project root.
> Auto-loaded by Claude Code every session.

## 🔒 Scope Rules — Non Negotiable
- ALL memory files → .claude/memory/
- ALL module files → .claude/modules/
- ALL task logs → .claude/tasks/logs/
- ALL plans → .claude/tasks/plans/
- ALL todo tasks → .claude/tasks/todo/
- ALL inprogress tasks → .claude/tasks/inprogress/
- ALL done tasks → .claude/tasks/done/
- ALL EOD summaries → .claude/tasks/eod/
- ALL commands → .claude/commands/
- NEVER write any file outside project root
- NEVER read memory from global or external paths
- NEVER create .md files at project root except CLAUDE.md
- If a path does not start with .claude/ — stop and fix it

## 🧭 Project Context
- **Name**: exam_guard
- **Purpose**: Help exam invigilators detect hidden electronic devices (BLE scan, magnetometer, RF meter) and log violations
- **Stack**: Flutter 3.47 (fvm) · hooks_riverpod 3.4 (no codegen) · go_router · Hive · flutter_blue_plus · sensors_plus
- **Current Phase**: [MVP / Growth / Maintenance]
- **Target Users**: [to be filled]
- **Critical Paths**: [to be filled]
- **Current Priorities**: [to be filled]

## 📁 Project Structure
[Run /r-memory-scan to auto-fill this section]

## 🏗️ Architecture
- **Layers**: [to be filled]
- **Data Flow**: [to be filled]
- **Auth**: [to be filled]
- **External Services**: [to be filled]
- **Environment Differences**: [to be filled]

## 📏 Non-Negotiable Rules
Full list: .claude/memory/rules.md

✅ DO: Feature-first + MVVM — `features/<name>/{model, repository, view_model, view}`
✅ DO: View → ViewModel (Riverpod Notifier) → Repository → core service wrapper
✅ DO: Wrap every third-party package in a custom class/function in `lib/core/`
❌ DON'T: Use use cases, `domain/` / `application/` / `infrastructure/` folders
❌ DON'T: Use `@riverpod` annotations, riverpod_generator, or StateNotifier
❌ DON'T: Import third-party packages in `lib/features/` (only flutter, hooks_riverpod, flutter_hooks)

## 🔁 Established Patterns
[Run /r-memory-scan to auto-fill]

## ⚠️ Gotchas
[Run /r-memory-scan to auto-fill]

## 🧩 Module Map
[Run /r-memory-scan to auto-fill]

## 🔗 Dependency Map
[Run /r-memory-scan to auto-fill]

## 📌 Key Decisions
[Run /r-memory-scan to auto-fill]

## 🛠️ Dev Commands
- Flutter binary: `~/fvm/default/bin/flutter` (not on PATH)
- Install: `fvm flutter pub get`
- Run: `fvm flutter run`
- Build: `fvm flutter build apk` / `fvm flutter build ios`
- Test: `fvm flutter test`
- Lint: `fvm flutter analyze`

## ⚙️ Settings
- .claude/settings.json → shared team settings — always commit
- .claude/settings.local.json → personal settings — never commit
- First thing after cloning: add your name to settings.local.json

## 👥 Team Guidelines
- All .claude/ files are shared — commit all changes
- Only settings.local.json and tasks/eod/ are personal/gitignored
- Every developer can work on all modules
- When you update any memory file — commit so team benefits
- After touching a module — update .claude/modules/[name].md
- New gotcha found — add to .claude/memory/gotchas.md and commit
- New pattern found — add to .claude/memory/patterns.md and commit
- Architecture decision made — add to .claude/memory/decisions.md and commit
- Run /r-memory-scan after pulling major changes

## 📋 Task Collaboration
- See all tasks: /r-todo
- Add task for team: /r-add-task [description]
- Pick up a task: /r-pickup
- Mark task done: /r-done
- All tasks are shared — commit and push after adding

## 📋 Before Every Task
1. Re-read this file
2. Read .claude/modules/[relevant].md
3. Read .claude/memory/gotchas.md
4. Read .claude/memory/dependencies.md
5. State plan before writing any code
6. List all files that will change
7. Check blast radius
8. Confirm plan follows all rules above

## 📋 After Every Task
1. Update .claude/modules/[affected].md
2. Append to module changelog
3. Log new gotchas to .claude/memory/gotchas.md
4. Log new patterns to .claude/memory/patterns.md
5. Log new decisions to .claude/memory/decisions.md
6. Update architecture.md if structure changed
7. Update this CLAUDE.md if anything major changed
8. Save task log to .claude/tasks/logs/2026-10-13-[title].md
9. Set memory confidence flags on updated modules
