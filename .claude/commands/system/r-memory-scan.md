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
