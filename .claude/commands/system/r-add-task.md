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
