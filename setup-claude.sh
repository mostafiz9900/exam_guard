#!/bin/bash

# ═══════════════════════════════════════════════════════
# Claude AI Development System Setup
# Usage: ./setup-claude.sh
# ═══════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ───────────────────────────────────────────────────────
# HELPERS
# ───────────────────────────────────────────────────────

print_step() { echo -e "\n${BLUE}═══ $1 ═══${NC}"; }
print_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }

make_file() {
  mkdir -p "$(dirname "$1")"
  if [ -f "$1" ]; then
    print_warn "Skipped (already exists): $1"
    cat > /dev/null  # consume stdin so heredoc doesn't hang
  else
    cat > "$1"
    print_ok "Created: $1"
  fi
}

# ───────────────────────────────────────────────────────
# SAFETY CHECK
# ───────────────────────────────────────────────────────

print_step "Safety Check"

SAFE_MODE=false
if [ -f "CLAUDE.md" ] || [ -d ".claude" ]; then
  echo ""
  print_warn "Existing Claude setup detected!"
  print_info "Running in SAFE MODE — existing files will NOT be touched"
  print_info "Only missing files and folders will be created"
  echo ""
  SAFE_MODE=true
else
  print_info "Fresh project — creating full setup"
fi

# ───────────────────────────────────────────────────────
# DETECT PROJECT
# ───────────────────────────────────────────────────────

print_step "Detecting Project"

PROJECT_NAME=$(basename "$PWD")
TODAY=$(date +%Y-%m-%d)

# Detect stack
STACK=""
[ -f "package.json" ]      && STACK="$STACK Node.js"
[ -f "composer.json" ]     && STACK="$STACK PHP/Laravel"
[ -f "requirements.txt" ]  && STACK="$STACK Python"
[ -f "Gemfile" ]           && STACK="$STACK Ruby"
[ -f "go.mod" ]            && STACK="$STACK Go"
[ -f "Cargo.toml" ]        && STACK="$STACK Rust"
[ -z "$STACK" ]            && STACK="Unknown"

# Detect source folders
SRC_FOLDERS=""
for folder in src app lib resources pages components api; do
  [ -d "$folder" ] && SRC_FOLDERS="$SRC_FOLDERS $folder/"
done

print_info "Project: $PROJECT_NAME"
print_info "Stack:   $STACK"
print_info "Source:  $SRC_FOLDERS"

# ───────────────────────────────────────────────────────
# STEP 1: CREATE FOLDER STRUCTURE
# ───────────────────────────────────────────────────────

print_step "Creating Folder Structure"

mkdir -p .claude/memory
mkdir -p .claude/modules
mkdir -p .claude/tasks/todo
mkdir -p .claude/tasks/inprogress
mkdir -p .claude/tasks/done
mkdir -p .claude/tasks/plans
mkdir -p .claude/tasks/logs
mkdir -p .claude/tasks/eod
mkdir -p .claude/commands/system
mkdir -p .claude/commands/custom

touch .claude/tasks/eod/.gitkeep

print_ok "Folder structure created"

# ───────────────────────────────────────────────────────
# STEP 2: settings.json
# ───────────────────────────────────────────────────────

print_step "Creating Settings Files"

# Build allow paths from detected source folders
ALLOW_PATHS='"Read(.claude/**)",
      "Read(CLAUDE.md)"'

for folder in $SRC_FOLDERS; do
  folder=$(echo "$folder" | xargs)
  ALLOW_PATHS="$ALLOW_PATHS,
      \"Read($folder**)\",
      \"Write($folder**)\""
done

ALLOW_PATHS="$ALLOW_PATHS,
      \"Write(.claude/tasks/**)\",
      \"Write(.claude/memory/**)\",
      \"Write(.claude/modules/**)\",
      \"Write(.claude/commands/**)\""

make_file ".claude/settings.json" << EOF
{
  "permissions": {
    "allow": [
      $ALLOW_PATHS
    ],
    "deny": [
      "Write(~/**)",
      "Write(../**)",
      "Read(~/.ssh/**)",
      "Read(~/.env/**)"
    ]
  }
}
EOF

make_file ".claude/settings.local.json" << 'EOF'
{
  "developerName": "",
  "notes": "Fill in your name above. This file is yours only — never commit it."
}
EOF

# ───────────────────────────────────────────────────────
# STEP 3: CLAUDE.md
# ───────────────────────────────────────────────────────

print_step "Creating CLAUDE.md"

make_file "CLAUDE.md" << EOF
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
- **Name**: $PROJECT_NAME
- **Purpose**: [to be filled after Claude scans project]
- **Stack**: $STACK
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
[Run /r-memory-scan to auto-fill based on existing code]

✅ DO: [to be filled]
❌ DON'T: [to be filled]

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
- Install:
- Dev server:
- Build:
- Test:
- Lint:
- Migrate:
- Seed:
- Deploy:

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
8. Save task log to .claude/tasks/logs/$TODAY-[title].md
9. Set memory confidence flags on updated modules
EOF

# ───────────────────────────────────────────────────────
# STEP 4: MEMORY FILES
# ───────────────────────────────────────────────────────

print_step "Creating Memory Files"

make_file ".claude/memory/context.md" << EOF
# Project Context
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Run /r-memory-scan to auto-fill from codebase.

- **Product Name**: $PROJECT_NAME
- **Purpose**: [to be filled]
- **Target Users**: [to be filled]
- **Current Phase**: [to be filled]
- **What Success Looks Like**: [to be filled]
- **What Must Never Break**: [to be filled]
- **Known Technical Debt**: [to be filled]
EOF

make_file ".claude/memory/architecture.md" << 'EOF'
# Architecture
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Run /r-memory-scan to auto-fill from codebase.

## Stack
[to be filled]

## Folder Structure
[to be filled]

## System Layers
[to be filled]

## Data Flow
[to be filled]

## Auth Flow
[to be filled]

## External Services
[to be filled]

## Environment Differences
[to be filled]

## Key Design Decisions
[to be filled]
EOF

make_file ".claude/memory/rules.md" << 'EOF'
# Rules — Non Negotiable
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Run /r-memory-scan to auto-fill from codebase.

## Naming Conventions
✅ DO: [to be filled]
❌ DON'T: [to be filled]

## Import Rules
✅ DO: [to be filled]
❌ DON'T: [to be filled]

## Function Rules
✅ DO: [to be filled]
❌ DON'T: [to be filled]

## Error Handling
✅ DO: [to be filled]
❌ DON'T: [to be filled]

## Testing Rules
✅ DO: [to be filled]
❌ DON'T: [to be filled]

## Forbidden Patterns
❌ NEVER: [to be filled]

## Environment Variables
✅ DO: [to be filled]
❌ DON'T: [to be filled]
EOF

make_file ".claude/memory/patterns.md" << 'EOF'
# Established Patterns
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Run /r-memory-scan to auto-fill from codebase.

[Patterns will be added here as they are discovered]

## Template
#### [Pattern Name]
- **When to use**:
- **Example**: [file path + snippet]
- **Anti-pattern**:
EOF

make_file ".claude/memory/decisions.md" << EOF
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

#### $TODAY — Initial Setup
- **Problem**: Need a structured AI-assisted development system
- **Decision**: Claude Code with .claude/ memory system
- **Reason**: Project-scoped, team-shared, native Claude Code support
- **Tradeoffs**: Requires Claude Code installation
- **Revisit If**: Team grows beyond 10 developers
EOF

make_file ".claude/memory/gotchas.md" << 'EOF'
# Gotchas
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Run /r-memory-scan to auto-fill from codebase.

[Gotchas will be added here as they are discovered]

## Template
#### [Module] — [Title]
- **What Happens**:
- **Why**:
- **How to Avoid**:
- **Discovered**:
EOF

make_file ".claude/memory/dependencies.md" << 'EOF'
# Module Dependencies
> ⚠️ PROJECT SCOPED: This file lives in .claude/memory/ only.
> Run /r-memory-scan to auto-fill from codebase.

## Module Dependency Map
[to be filled]

## Shared Utilities
[files used across 3+ modules]

## High Risk Modules
[most depended on — highest blast radius]

## External Package Usage
[which packages used where and why]

## Circular Dependencies
[any detected circular imports]
EOF

make_file ".claude/memory/pre-task-checklist.md" << 'EOF'
# Pre Task Checklist
> ⚠️ Run every item before starting any task.

- [ ] Re-read CLAUDE.md
- [ ] Read .claude/modules/[relevant].md
- [ ] Read .claude/memory/gotchas.md for this area
- [ ] Read .claude/memory/dependencies.md
- [ ] State complete plan before writing any code
- [ ] List all files that will change
- [ ] Check blast radius
- [ ] Confirm plan follows .claude/memory/rules.md
- [ ] Confirm plan uses patterns from .claude/memory/patterns.md
EOF

make_file ".claude/memory/post-task-checklist.md" << 'EOF'
# Post Task Checklist
> ⚠️ Complete every item after finishing any task.

- [ ] All rules from .claude/memory/rules.md followed
- [ ] Existing patterns used correctly
- [ ] Errors handled correctly
- [ ] .claude/modules/[affected].md updated
- [ ] Changelog appended in module file
- [ ] New gotchas logged to .claude/memory/gotchas.md
- [ ] New patterns logged to .claude/memory/patterns.md
- [ ] New decisions logged to .claude/memory/decisions.md
- [ ] CLAUDE.md updated if needed
- [ ] Task log saved to .claude/tasks/logs/YYYY-MM-DD-[title].md
- [ ] Memory confidence flags set on updated modules
EOF

make_file ".claude/memory/INDEX.md" << 'EOF'
# Memory System Index
> ⚠️ PROJECT SCOPED: All memory lives in .claude/ only.

## Directory Structure
.claude/
├── memory/              → core memory files
├── modules/             → per module memory files
├── tasks/
│   ├── todo/            → tasks waiting to be picked up
│   ├── inprogress/      → tasks being worked on
│   ├── done/            → completed tasks
│   ├── plans/           → feature plans before coding
│   ├── logs/            → completed task logs
│   └── eod/             → personal EOD (gitignored)
└── commands/
    ├── system/          → built-in r- commands
    └── custom/          → your custom r- commands

## Quick Reference
| Situation | Command |
|---|---|
| Start session | /r-start |
| See all tasks | /r-todo |
| Add a task | /r-add-task [desc] |
| Pick up a task | /r-pickup |
| Execute a task | /r-task [desc] |
| Plan a feature | /r-plan [feature] |
| Fix something | /r-fix [desc] |
| Mark task done | /r-done |
| Review last task | /r-review |
| Find something | /r-where [thing] |
| Check blast radius | /r-impact [thing] |
| Log a decision | /r-decisions [desc] |
| Log a gotcha | /r-gotcha [desc] |
| Log a pattern | /r-pattern [desc] |
| Sync memory | /r-memory-update |
| Full rescan | /r-memory-scan |
| Memory health | /r-memory-status |
| End session | /r-end |
| Check tokens | /r-tokens |
| All commands | /r-help |

## Core Memory Files
| File | Purpose |
|---|---|
| CLAUDE.md | Auto-loaded every session |
| memory/context.md | Product purpose and priorities |
| memory/architecture.md | System design and data flow |
| memory/rules.md | Non-negotiable coding rules |
| memory/patterns.md | Established code patterns |
| memory/decisions.md | Architecture decision log |
| memory/gotchas.md | Known traps and footguns |
| memory/dependencies.md | Module dependency map |
| memory/pre-task-checklist.md | Run before every task |
| memory/post-task-checklist.md | Run after every task |
EOF

make_file ".claude/memory/VERSION" << EOF
Memory System Version: 1.0.0
Created: $TODAY
Project: $PROJECT_NAME
Memory Root: .claude/memory/
Modules Root: .claude/modules/
Tasks Root: .claude/tasks/
Commands Root: .claude/commands/
Last Full Scan: pending — run /r-memory-scan
Generated By: setup-claude.sh
EOF

# ───────────────────────────────────────────────────────
# STEP 5: TASK READMES
# ───────────────────────────────────────────────────────

print_step "Creating Task Folders"

make_file ".claude/tasks/todo/README.md" << EOF
# 📋 Todo Tasks
Anyone on the team can add tasks here.
Anyone on the team can pick up any task.

## How to add a task
Run: /r-add-task [description]
Or create: .claude/tasks/todo/$TODAY-[title].md

## Task template
---
# Task: [title]
**Added By**: [name]
**Date Added**: $TODAY
**Priority**: 🔴 High / 🟡 Medium / 🟢 Low
**Module**: [which module]
**Estimated Effort**: Small / Medium / Large
**Assigned To**: unassigned

## Description
[what needs to be done and why]

## Acceptance Criteria
- [ ] [what done looks like]

## Notes
[context, gotchas, links]

## Related Files
[relevant file paths]
---

## How to pick up a task
Run: /r-pickup
Commit and push so team knows it is taken.
EOF

make_file ".claude/tasks/inprogress/README.md" << 'EOF'
# 🔄 In Progress
Tasks currently being worked on.
Move here from todo/ when you start.
Commit so team knows who is working on what.
EOF

make_file ".claude/tasks/done/README.md" << 'EOF'
# ✅ Done
Completed tasks.
Team and Claude read these to understand project history.
EOF

make_file ".claude/tasks/plans/README.md" << 'EOF'
# 📐 Plans
Feature plans created before coding.
Always plan large features before starting.
Run: /r-plan [feature name]
EOF

make_file ".claude/tasks/logs/README.md" << 'EOF'
# 📝 Task Logs
Logs of completed tasks.
Auto-created by /r-task and /r-done commands.
EOF

# ───────────────────────────────────────────────────────
# STEP 6: SYSTEM COMMANDS
# ───────────────────────────────────────────────────────

print_step "Creating System Commands"

make_file ".claude/commands/system/r-start.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read only from this project's .claude/ directory.

Load full memory system:
1. CLAUDE.md (already loaded by Claude Code)
2. .claude/memory/context.md
3. .claude/memory/architecture.md
4. .claude/memory/rules.md
5. .claude/memory/patterns.md
6. .claude/memory/gotchas.md
7. .claude/memory/dependencies.md
8. Last 3 files in .claude/tasks/logs/
9. Last file in .claude/tasks/eod/ if exists
10. Scan all .claude/modules/ — flag any 🔴 Stale
11. Read .claude/tasks/todo/ — count and sort by priority
12. Read .claude/tasks/inprogress/ — list what is in progress

Report:
- ✅ Memory loaded — what you know about this project
- ⚠️ Stale modules — list with suggested action
- 🔴 Risk flags — anything broken or outdated
- 📋 Todo: [count] tasks — top 3 by priority
- 🔄 In Progress: [what is being worked on]
- 💡 Suggested focus — highest priority todo task
- 🛠️ Dev commands quick ref

At the very end of the report show a token usage meter:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧠 TOKEN USAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Used:      [████░░░░░░░░░░░░░░░░]  ~XX%  (~XXk / 200k)
Remaining: [████████████████░░░░]  ~XX%  (~XXk tokens)
Status:    🟢 Safe / 🟡 Medium / 🔴 Critical
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 Safe 0–60%  → keep working
🟡 Medium 60–80% → wrap up current task, run /r-end soon
🔴 Critical 80%+ → run /r-end NOW before context cuts off
Tip: run /r-tokens anytime to check remaining context.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You are now senior dev partner for this session.
Never ask to re-explain anything already in memory.
EOF

make_file ".claude/commands/system/r-end.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Save to .claude/tasks/eod/ only.

Session ending:
1. List all tasks completed this session
2. List all files changed
3. List all memory files updated
4. List anything unfinished or still in progress
5. Suggest what to pick up first tomorrow
6. Check if CLAUDE.md needs updating

Save to .claude/tasks/eod/YYYY-MM-DD-EOD-summary.md
Confirm saved. Remind: this file is personal and gitignored.
EOF

make_file ".claude/commands/system/r-task.md" << 'EOF'
> ⚠️ PROJECT SCOPED: All outputs save to .claude/ only.

Execute the given task:
1. Read .claude/memory/pre-task-checklist.md — complete every item
2. Read .claude/modules/[relevant].md
3. State complete plan before writing any code
4. Wait for approval if change touches more than 3 files
5. Execute the task
6. Read .claude/memory/post-task-checklist.md — complete every item
7. Update all affected .claude/modules/ files
8. Save log to .claude/tasks/logs/YYYY-MM-DD-[title].md

Log format:
# Task: [title]
**Date**:
**Summary**:
**Files Changed**:
**Modules Affected**:
**Decisions Made**:
**Memory Updated**:
**Notes**:

Confirm log saved with full path.
EOF

make_file ".claude/commands/system/r-plan.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Save to .claude/tasks/plans/ only.

Do NOT write any code yet.
Plan the requested feature:
1. Read full memory system
2. Read all relevant .claude/modules/ files
3. List all files to create/change/delete
4. List patterns to follow
5. List rules that apply
6. Map blast radius
7. List risks and gotchas
8. Write step by step execution order

Save to .claude/tasks/plans/YYYY-MM-DD-[feature]-PLAN.md
Confirm saved. Wait for explicit approval before coding.
EOF

make_file ".claude/commands/system/r-fix.md" << 'EOF'
> ⚠️ PROJECT SCOPED: All reads and updates stay in .claude/ only.

Diagnose and fix what is broken:
1. Read .claude/memory/gotchas.md first
2. Read .claude/modules/[relevant].md
3. Trace actual root cause — never guess
4. Explain what is broken and exactly why
5. Propose fix with clear reasoning
6. Apply the fix
7. Verify fix works
8. New gotcha? Add to .claude/memory/gotchas.md
9. Add to .claude/modules/[relevant].md gotchas section
10. Update module changelog
11. Save log to .claude/tasks/logs/YYYY-MM-DD-fix-[title].md
EOF

make_file ".claude/commands/system/r-review.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read from .claude/ only.

Review the last completed task:
1. Read most recent file in .claude/tasks/logs/
2. Check every rule in .claude/memory/rules.md was followed
3. Check correct patterns were used
4. Check memory files were properly updated
5. Check error handling is correct

Report:
- ✅ Pass / ❌ Fail for each check
- Issues found with file references
- Suggested improvements
- New gotchas or patterns to log
EOF

make_file ".claude/commands/system/r-todo.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read from .claude/tasks/ only.

Show all tasks and status:
1. Read all files in .claude/tasks/todo/
2. Read all files in .claude/tasks/inprogress/
3. Read last 5 files in .claude/tasks/done/

Report:

## 📋 Todo ([count])
| Priority | Task | Module | Effort | Added By |
|---|---|---|---|---|
[sorted: 🔴 first, then 🟡, then 🟢]

## 🔄 In Progress ([count])
| Task | Module | Assigned To | Started |
|---|---|---|---|

## ✅ Recently Done (last 5)
| Task | Module | Completed By |
|---|---|---|
EOF

make_file ".claude/commands/system/r-add-task.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Save to .claude/tasks/todo/ only.

Create a new task for the team todo list.
Infer developer name from:
1. .claude/settings.local.json developerName
2. git config user.name
3. Ask if neither found

Gather or infer:
- Task title
- Which module it touches
- Priority (🔴 High / 🟡 Medium / 🟢 Low)
- Description
- Acceptance criteria
- Estimated effort (Small / Medium / Large)
- Related file paths

Save to .claude/tasks/todo/YYYY-MM-DD-[title].md

# Task: [title]
**Added By**: [name]
**Date Added**: [today]
**Priority**: [priority]
**Module**: [module]
**Estimated Effort**: [effort]
**Assigned To**: unassigned

## Description
[description]

## Acceptance Criteria
- [ ] [criteria]

## Notes
[notes]

## Related Files
[paths]

Confirm saved. Remind: commit and push so team can see it.
EOF

make_file ".claude/commands/system/r-pickup.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Move files within .claude/tasks/ only.

Pick up a task from todo list:
1. Read all files in .claude/tasks/todo/
2. Show list sorted by priority
3. Identify which task to pick up from context or ask
4. Get developer name from:
   a. .claude/settings.local.json developerName
   b. git config user.name
   c. Ask if neither found
5. Move file: .claude/tasks/todo/ → .claude/tasks/inprogress/
6. Add to file:
   - Assigned To: [name]
   - Started: [today]
7. Automatically run r-task with the task description

Confirm moved with full path.
Remind: commit and push so team knows it is taken.
EOF

make_file ".claude/commands/system/r-done.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Move files within .claude/tasks/ only.

Mark current task as done:
1. Read files in .claude/tasks/inprogress/
2. Identify task from context or ask
3. Get developer name from settings.local.json or git config
4. Update task file:
   - Completed By: [name]
   - Completed Date: [today]
   - Check off all met acceptance criteria
   - Add ## Summary of what was done
5. Move: .claude/tasks/inprogress/ → .claude/tasks/done/
6. Save log to .claude/tasks/logs/YYYY-MM-DD-[title].md
7. Suggest git commit message for team

Confirm moved. Remind: commit and push so team sees it is done.
EOF

make_file ".claude/commands/system/r-memory-update.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read and write .claude/ only.
> ⚠️ SAFE MODE: Never delete or overwrite existing content.

Sync memory with current codebase — SAFE MODE rules:
- NEVER delete existing memory files
- NEVER overwrite existing content
- ONLY add missing information
- When updating an outdated field → keep old value in comment:
  <!-- previous: old value here -->
- Always append to changelogs — never rewrite them
- If unsure whether to update → leave existing and flag:
  ⚠️ NEEDS REVIEW: [what was found]

Process:
1. Read every file in the project
2. Compare against all .claude/memory/ files
3. Compare against all .claude/modules/ files
4. Find everything outdated, missing, or wrong
5. ADD missing sections only — never replace existing
6. APPEND new findings — never overwrite
7. Set confidence: 🟢 High / 🟡 Medium / 🔴 Stale
8. Update all Last Updated dates
9. Update CLAUDE.md missing sections only
10. Bump VERSION minor version

Report all changes made with file paths.
EOF

make_file ".claude/commands/system/r-memory-save.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Save to .claude/ only.

Save all memory files modified this session:
1. Save all updated .claude/memory/ files
2. Save all updated .claude/modules/ files
3. Confirm each with full path and Last Updated date
4. List summary of what changed in each
EOF

make_file ".claude/commands/system/r-memory-status.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read from .claude/modules/ only.

Read all .claude/modules/ files.
Report:

| Module | Confidence | Last Updated | Notes |
|---|---|---|---|

Then:
- List all 🔴 Stale with fix action
- List all 🟡 Medium with reason
- Overall memory health score
EOF

make_file ".claude/commands/system/r-memory-scan.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Update .claude/ only. Never touch global paths.
> ⚠️ SAFE MODE: Never delete or overwrite existing content.

Full project re-scan — SAFE MODE rules:
- NEVER delete any existing file in .claude/
- NEVER overwrite any existing content in .claude/
- ONLY append new findings to existing files
- ONLY create files that do not exist yet
- ALWAYS append to changelogs — never rewrite them
- If unsure → keep existing content and add below it

Process:
1. Read every single file in the project
2. For each file in .claude/memory/:
   - Read existing content first
   - Compare with current codebase
   - ADD missing sections only
   - APPEND new findings below existing content
   - Never touch content that already exists
3. For each module in .claude/modules/:
   - If file exists → read first, then append new findings only
   - If file does not exist → create fresh
   - Always append to Changelog — never rewrite it
4. For new modules not yet in .claude/modules/:
   - Create new file only
5. Update CLAUDE.md:
   - Only add missing sections
   - Never overwrite existing sections
   - Append to existing sections where needed
6. Bump .claude/memory/VERSION minor version

Report:
- ✅ Files updated (what was appended)
- ✅ New files created
- ⏭️ Files skipped (already up to date)
- ⚠️ Nothing deleted
- ⚠️ Nothing overwritten
- New modules discovered
- Major changes found since last scan
EOF

make_file ".claude/commands/system/r-impact.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read from .claude/ only.

Analyze blast radius:
1. Read .claude/memory/dependencies.md
2. Read all relevant .claude/modules/ files
3. Trace direct and indirect dependencies
4. List all files that need updating
5. List tests affected

Report:
- Risk: 🟢 Low / 🟡 Medium / 🔴 High
- Direct impact with file paths
- Indirect impact with file paths
- Files to update
- Tests to check
- Recommendation
EOF

make_file ".claude/commands/system/r-where.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read from .claude/ only.

Find where the requested thing lives:
1. Read .claude/memory/dependencies.md
2. Read relevant .claude/modules/ files
3. Search actual codebase

Report:
- Exact file paths and line numbers
- Which module owns it
- What imports it
- What it exports to
EOF

make_file ".claude/commands/system/r-decisions.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Save to .claude/memory/decisions.md only.

Log a new architecture decision.
Add to .claude/memory/decisions.md:

#### [today] — [title]
- **Problem**:
- **Options Considered**:
- **Decision**:
- **Reason**:
- **Tradeoffs**:
- **Revisit If**:

Confirm saved to .claude/memory/decisions.md
EOF

make_file ".claude/commands/system/r-gotcha.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Save to .claude/ only.

Log a new gotcha:
1. Add to .claude/memory/gotchas.md
2. Add to .claude/modules/[relevant].md gotchas section
3. Append to module changelog

#### [Module] — [Title]
- **What Happens**:
- **Why**:
- **How to Avoid**:
- **Discovered**: [today]

Confirm saved to both files.
EOF

make_file ".claude/commands/system/r-pattern.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Save to .claude/memory/patterns.md only.

Log a new pattern:
#### [Pattern Name]
- **When to use**:
- **Example**: [file path + snippet]
- **Anti-pattern**:

Confirm saved to .claude/memory/patterns.md
EOF

make_file ".claude/commands/system/r-tokens.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read from .claude/ only.

Estimate current token usage for this session.

Calculate approximate tokens used based on:
- All memory files loaded this session
- All files read from the project
- Full conversation length so far
- All responses generated

Then display:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧠 TOKEN USAGE — Current Session
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Used:      [fill bar with █ and ░]  ~XX%  (~XXk / 200k)
Remaining: [fill bar with █ and ░]  ~XX%  (~XXk tokens)
Status:    🟢 Safe / 🟡 Medium / 🔴 Critical
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 Safe      0–60%  → keep working
🟡 Medium   60–80%  → wrap up task, run /r-end soon
🔴 Critical  80%+   → run /r-end NOW before cutoff
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Bar is 20 chars wide:
- Each █ = 5% used
- Each ░ = 5% remaining
- Example 60% used: ████████████░░░░░░░░

Note: This is an estimate based on conversation size.
Actual token count may vary slightly.
Run /r-end before hitting 85% to save session safely.
EOF

make_file ".claude/commands/system/r-help.md" << 'EOF'
> ⚠️ PROJECT SCOPED: Read from .claude/commands/ only.

Read .claude/commands/system/ and .claude/commands/custom/
Display all available commands:

## System Commands
| Command | Description |
|---|---|
| /r-start | Load memory, show project status + token meter |
| /r-end | EOD summary, save session |
| /r-todo | Show all tasks and status |
| /r-add-task [desc] | Add task to team todo list |
| /r-pickup | Pick up a task from todo |
| /r-task [desc] | Execute a task with full memory |
| /r-done | Mark current task as done |
| /r-plan [feature] | Plan before coding |
| /r-fix [desc] | Diagnose and fix something broken |
| /r-review | Review last task quality |
| /r-where [thing] | Find where something lives |
| /r-impact [thing] | Blast radius of a change |
| /r-decisions [desc] | Log architecture decision |
| /r-gotcha [desc] | Log a new gotcha |
| /r-pattern [desc] | Log a new pattern |
| /r-memory-update | Sync memory with codebase |
| /r-memory-save | Force save all memory files |
| /r-memory-status | Show module confidence levels |
| /r-memory-scan | Full project rescan |
| /r-tokens | Show token usage meter for this session |
| /r-help | Show this list |

## Custom Commands
[list any found in .claude/commands/custom/]
[if empty: No custom commands yet — see .claude/commands/custom/README.md]
EOF

# ───────────────────────────────────────────────────────
# STEP 7: CUSTOM COMMANDS README
# ───────────────────────────────────────────────────────

print_step "Creating Custom Commands"

make_file ".claude/commands/custom/README.md" << 'EOF'
# Custom Commands
> ⚠️ PROJECT SCOPED: Save to .claude/commands/custom/ only.
> All custom commands use r- prefix.

## Template
Create: .claude/commands/custom/r-[name].md

Content:
---
> ⚠️ PROJECT SCOPED: All reads and writes stay within .claude/ only.
[Exact instructions for Claude to execute when this command is typed]
---

## To add a custom command
/r-task create custom command /r-[name] that does [description]

## Ideas
- /r-deploy   → your deployment steps
- /r-test     → run test suite your way
- /r-migrate  → database migration workflow
- /r-seed     → database seeding workflow
- /r-lint-fix → auto fix linting issues
EOF

# ───────────────────────────────────────────────────────
# STEP 8: UPDATE .gitignore
# ───────────────────────────────────────────────────────

print_step "Updating .gitignore"

GITIGNORE_BLOCK="
# ─────────────────────────────────────────────────────
# Claude AI Memory System
# Shared with team: everything in .claude/ except below
# ─────────────────────────────────────────────────────
.claude/settings.local.json
.claude/tasks/eod/
"

if [ -f ".gitignore" ]; then
  if grep -q "Claude AI Memory System" .gitignore; then
    print_warn ".gitignore already has Claude entries — skipping"
  else
    echo "$GITIGNORE_BLOCK" >> .gitignore
    print_ok "Appended to existing .gitignore"
  fi
else
  echo "$GITIGNORE_BLOCK" > .gitignore
  print_ok "Created .gitignore"
fi

# ───────────────────────────────────────────────────────
# STEP 9: UPDATE README.md
# ───────────────────────────────────────────────────────

print_step "Updating README.md"

README_BLOCK="
## 🧠 Claude AI Development System

This project uses a shared Claude Code memory system in \`.claude/\`

### First time setup
\`\`\`bash
npm install -g @anthropic-ai/claude-code
claude
\`\`\`
Then add your name to \`.claude/settings.local.json\`:
\`\`\`json
{ \"developerName\": \"Your Name Here\" }
\`\`\`
Then run \`/r-memory-scan\` to build your memory.

### Daily workflow
\`\`\`
/r-start              → load memory, see project status
/r-todo               → see all pending tasks
/r-pickup             → pick up a task to work on
/r-task [desc]        → execute any task
/r-plan [feature]     → plan a big feature before coding
/r-fix [desc]         → diagnose and fix a bug
/r-done               → mark current task as complete
/r-end                → end of day summary
\`\`\`

### Team rules
- Commit all \`.claude/\` changes after tasks
- Only \`settings.local.json\` and \`tasks/eod/\` are personal/gitignored
- Add tasks for teammates with \`/r-add-task\`
- Update module memory after touching any module
"

if [ -f "README.md" ]; then
  if grep -q "Claude AI Development System" README.md; then
    print_warn "README.md already has Claude section — skipping"
  else
    echo "$README_BLOCK" >> README.md
    print_ok "Appended to existing README.md"
  fi
else
  echo "# $PROJECT_NAME $README_BLOCK" > README.md
  print_ok "Created README.md"
fi

# ───────────────────────────────────────────────────────
# DONE
# ───────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Claude AI Development System Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Project:${NC}   $PROJECT_NAME"
echo -e "${CYAN}Stack:${NC}     $STACK"
echo -e "${CYAN}Date:${NC}      $TODAY"
if [ "$SAFE_MODE" = true ]; then
  echo -e "${YELLOW}Mode:${NC}      ⚠️  SAFE MODE — existing files were not touched"
else
  echo -e "${CYAN}Mode:${NC}      🆕 Fresh setup — all files created"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. cd into your project"
echo "  2. Run: claude"
echo "  3. Type: /r-memory-scan  ← builds full memory from your code"
echo "  4. Add your name: .claude/settings.local.json"
echo "  5. Commit: git add .claude/ CLAUDE.md && git push"
echo ""
echo -e "${YELLOW}Daily workflow:${NC}"
echo "  /r-start    → load memory"
echo "  /r-todo     → see tasks"
echo "  /r-pickup   → grab a task"
echo "  /r-task     → do the work"
echo "  /r-done     → mark complete"
echo "  /r-end      → end of day"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""