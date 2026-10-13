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
