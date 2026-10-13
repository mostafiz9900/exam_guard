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
