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
