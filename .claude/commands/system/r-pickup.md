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
