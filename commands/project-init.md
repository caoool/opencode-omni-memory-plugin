---
description: Initialize native Markdown memory and project-state files for the current project.
---

Load the `markdown-memory` skill and initialize the current project according to its lazy-bootstrap rules.

Use the Git worktree root, or the OpenCode launch directory outside Git. Preserve existing files and documentation. Create the minimal `INDEX.md`, `MEMORY.md`, and `HANDOFF.md` unless `$ARGUMENTS` requests `full`, in which case also create the charter, working specification, roadmap, progress, findings, and decisions from the skill templates. Add the temporary sessions directory to `.gitignore` without disturbing existing rules.

Arguments: `$ARGUMENTS`
