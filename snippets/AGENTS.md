<!-- opencode-omni-memory-plugin:start -->
## Persistent Markdown memory (omni-memory)

- Global active memory lives at `~/.config/opencode/memory/GLOBAL.md`. Cross-project handoff lives at `~/.config/opencode/memory/HANDOFF.md`, and host-specific facts live under `~/.config/opencode/memory/hosts/`.
- Project memory and continuation state live under `<project-root>/.opencode/project/`. `MEMORY.md` and `HANDOFF.md` are loaded automatically when present; detailed charter, spec, roadmap, progress, findings, decisions, sessions, and archives are retrieved on demand.
- For every substantive task, load the `omni-memory` skill at orientation, use relevant memory silently, and follow its precedence, retention, transition-update, concurrency, and handoff rules. The companion plugin injects a session bootstrap; treat it as already-loaded guidance rather than a reason to skip or re-load the skill.
- At meaningful decisions, milestone changes, blockers, verification results, or major next-action changes, update the appropriate project-state artifacts. At task completion, perform the skill's conservative durable-memory check.
- Default repository-derived facts to project memory. Use global memory only for explicitly cross-project preferences, use host memory for machine-specific facts, and use global handoff only for work spanning projects or OpenCode configuration.
- Do not create or update memory when nothing durable was learned. Never retain secrets, credentials, raw logs, full transcripts, temporary status, sensitive exploit detail, or unverified assumptions.
<!-- opencode-omni-memory-plugin:end -->
