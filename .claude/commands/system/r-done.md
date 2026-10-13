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
