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
