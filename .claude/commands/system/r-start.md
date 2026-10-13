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
