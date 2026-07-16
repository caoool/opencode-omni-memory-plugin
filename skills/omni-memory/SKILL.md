---
name: omni-memory
description: Automatically retrieves and maintains native Markdown memory, project specifications, roadmaps, progress, findings, decisions, and session handoffs. Use when starting work in a repository, resuming after a break or compaction, before implementation or planning, when the user references earlier work or preferences, and whenever the user asks to remember, recall, forget, audit memory, initialize project state, inspect status, or hand off work.
---

# Omni Memory

Maintain durable knowledge and resumable project state without an external memory service. Keep stable memory separate from mutable project control documents and temporary session journals.

## Storage model

### Global scope

- `~/.config/opencode/memory/GLOBAL.md` — durable cross-project preferences and conventions; loaded automatically.
- `~/.config/opencode/memory/HANDOFF.md` — cross-project continuation state; retrieve only for configuration or multi-project work.
- `~/.config/opencode/memory/hosts/<hostname>.md` — machine-specific facts; retrieve only when the task depends on the host environment.
- `~/.config/opencode/memory/archive/` — inactive global detail; search on demand.

### Project scope

Use the Git worktree root as `<project-root>`. Outside Git, use the directory from which OpenCode was launched.

- `<project-root>/.opencode/project/MEMORY.md` — durable project facts; loaded automatically.
- `<project-root>/.opencode/project/HANDOFF.md` — concise branch/session continuation delta; loaded automatically.
- `<project-root>/.opencode/project/INDEX.md` — artifact map and relationship to existing documentation.
- `<project-root>/.opencode/project/CHARTER.md` — protected goals, constraints, non-goals, and success definition.
- `<project-root>/.opencode/project/SPEC.md` — agent-maintained working specification.
- `<project-root>/.opencode/project/ROADMAP.md` — milestones and sequencing.
- `<project-root>/.opencode/project/PROGRESS.md` — current whole-project snapshot.
- `<project-root>/.opencode/project/FINDINGS.md` — hypotheses and verified discoveries.
- `<project-root>/.opencode/project/DECISIONS.md` — material decisions and supersession history.
- `<project-root>/.opencode/project/sessions/` — temporary journals for concurrent sessions.
- `<project-root>/.opencode/project/archive/<milestone>/` — completed detail archived by milestone.

Templates are bundled under `templates/project/`. Most templates map to a single file of the same name. The two directory-backed templates instantiate under a path rather than at the root: `SESSION.md` seeds each journal at `sessions/YYYY-MM-DD-HHMM-<agent>-<topic>.md`, and `ARCHIVE.md` seeds each milestone summary at `archive/<milestone>/`. Do not overwrite an existing artifact when initializing or expanding project state.

`MEMORY.md` and `HANDOFF.md` load automatically only because the host `opencode.json` `instructions` array injects `~/.config/opencode/memory/GLOBAL.md`, `.opencode/project/MEMORY.md`, and `.opencode/project/HANDOFF.md`. If those paths or filenames change in one place, update the other; nothing else auto-loads. The companion `omni-memory` plugin additionally injects a compact orientation bootstrap into the first user message of each session and defends memory/handoff pointers during compaction; treat its bootstrap as already-loaded guidance, not as a reason to reload this skill.

## Silent session orientation

Substantive project work is any task that may read, change, or produce durable project state: implementation, debugging, refactoring, planning, review, or a memory command. Skip orientation entirely for pure question-answering, trivial single-file edits with no durable outcome, and scratch work outside a project root; do minimal targeted retrieval instead. Match orientation depth to task risk rather than running the full sequence for small local edits.

At the beginning of substantive project work:

1. Determine the project root. If Git is available, determine the current branch, commit, worktree, and dirty state.
2. Use the automatically loaded global memory, project memory, and handoff without announcing routine retrieval.
3. Read `INDEX.md` and `CHARTER.md` when present.
4. Retrieve only task-relevant portions of the spec, roadmap, progress, findings, decisions, archives, existing project docs, and session journals.
5. Compare the handoff with current repository state. Current verified state overrides stale handoff details.
6. Mention orientation only when a conflict, stale assumption, concurrent session, missing prerequisite, or blocker changes how work should proceed.

For cross-project or OpenCode-configuration work, also retrieve global `HANDOFF.md`. For machine-sensitive work, determine the hostname and retrieve the matching host file if present.

## Retrieval strategy

Keep the automatically injected global memory, project memory, and project handoff to roughly 2–4K tokens combined. Search detailed active files and archives on demand rather than injecting them all.

Before consequential use of a source-sensitive memory, verify it against its cited source. Low-risk user preferences may be trusted until contradicted.

When intended behavior conflicts, use this precedence:

1. Current explicit user instruction
2. Protected project charter
3. Explicit contracts, schemas, and accepted contract tests
4. Agent working specification
5. Existing or legacy project documentation
6. Current implementation behavior

Current code is evidence of what exists, not automatic proof of what should exist. Record material conflict resolutions in `DECISIONS.md`.

## Meaningful-transition updates

Update persistent state after a material transition, not after every edit or user turn.

Transitions include:

- A material decision or working-specification change
- A milestone becoming active, blocked, completed, or superseded
- A new blocker or major change in next actions
- A finding becoming verified, rejected, or promoted
- Verification materially changing confidence or completion status
- An explicit remember, forget, correction, audit, status, or handoff request
- An explicit user correction of agent behavior, or a second occurrence of the same failure, workaround, or misrouting (capture the lesson once, consolidated, in the narrowest correct scope)

Map transitions to artifacts:

- Decision → `DECISIONS.md`, and update spec or roadmap if affected
- Requirement or acceptance change → `SPEC.md`, with a decision entry when material
- Milestone change → `ROADMAP.md` and `PROGRESS.md`
- Current execution-state change → `PROGRESS.md`
- Discovery → `FINDINGS.md`; promote verified durable conclusions when appropriate
- Continuation change → `HANDOFF.md`
- Durable reusable fact → project or global memory

Reread each target file immediately before editing it. Consolidate instead of blindly appending. Do not write state when nothing material changed.

## Durable-memory retention

Good memory candidates:

- Explicit cross-project user preferences
- Stable environment or host facts
- Confirmed architecture and dependency constraints
- Stable conventions not obvious from standard tooling
- Canonical build, test, release, migration, or recovery commands
- Non-obvious recurring pitfalls and verified resolutions
- Corrections to existing memory

Do not retain:

- Secrets, tokens, credentials, private keys, or sensitive personal data
- Raw logs, full transcripts, large command outputs, or source-code copies
- Temporary status, one-off failures, speculative ideas, or unverified assumptions
- Sensitive exploit detail in committed project state; store only sanitized conclusions and remediation references
- Facts easily rediscovered from a canonical source unless the memory captures a non-obvious implication

Choose scope conservatively:

- Global memory only for facts intended to follow the user across repositories.
- Host memory for machine-specific facts that may differ across systems.
- Project memory for repository-derived architecture, commands, conventions, and pitfalls.
- Global handoff only for configuration or work spanning multiple projects.

Use compact bullets. Add `Source: <path or decision>; verified YYYY-MM-DD` only where provenance or staleness matters, and obtain the real current date (for example via `date +%F`) rather than guessing it. Rewrite or remove superseded claims. Keep active memory concise; archive inactive detail.

Promote rules out of memory: when an entry is really a standing behavior rule (routing, delegation, tooling, verification), its durable home is the governing configuration — the matching `AGENTS.md` section, agent definition, skill, or command. Encode it there and shrink the memory entry to a one-line pointer. Memory stages lessons; configuration is the rulebook.

Only the primary agent writes memory or project-state artifacts. Subagents never edit `memory/` or `.opencode/project/`; they return candidate lessons, decisions, and findings in their reports, and the primary agent persists what survives these retention rules. When delegating, do not instruct subagents to update memory.

## Project artifact contract

### Charter

The charter is protected. The agent may clarify wording that preserves meaning, but may change goals, hard constraints, non-goals, or success criteria only after explicit user direction.

### Working specification

The agent may autonomously evolve `SPEC.md` within the charter. Important requirements use stable IDs such as `REQ-001` and include status, acceptance criteria, and implementation or verification evidence.

Existing project documentation and the working specification are independent documents with distinct roles, not synchronized copies. `INDEX.md` must identify relevant existing docs and explain their relationship. Resolve disagreements according to the precedence rules and record material choices.

### Roadmap and progress

Roadmap milestones use stable IDs such as `M1` and link to requirements. `PROGRESS.md` is a rewritten current snapshot of completed, active, blocked, and next work; it is not an append-only activity journal.

### Findings

Findings use stable IDs such as `FND-001` and move through:

`hypothesis → verified → promoted`

A hypothesis may instead become `rejected`. Record evidence, impact, and destination when promoted into memory, spec, roadmap, or a decision.

### Decisions

Material decisions use stable IDs such as `DEC-001` and record rationale, evidence, consequences, affected requirements, and any superseded decision. Keep the decision ledger live rather than deleting history, but bound its active size: keep active decisions in full, and when a decision is superseded compress it to a one-line stub that records its ID, outcome, superseding ID, and date, then move its full rationale detail to `archive/<milestone>/`. The stub preserves the supersession trail while keeping the active file within budget.

## Lazy project initialization

Do not create project state merely because a repository was opened. On the first durable project fact, or when `/project-init` is requested:

1. Create `.opencode/project/` if needed.
2. Create the minimal `INDEX.md`, `MEMORY.md`, and `HANDOFF.md` from templates.
3. Add `.opencode/project/sessions/` to the project `.gitignore` because session journals are temporary concurrency state.
4. Create charter, spec, roadmap, progress, findings, and decisions only when the project needs them, unless full initialization is explicitly requested.
5. If legacy `.opencode/memory/PROJECT.md` exists, merge unique durable facts into the new `MEMORY.md`; do not discard unmatched content.

In a non-Git directory, treat the launch directory as the project root. Branch, commit, and Git-history fields then remain unavailable.

## Branches and concurrent sessions

Use the same canonical artifact paths on every branch. Git branches and worktrees naturally carry branch-specific versions of `HANDOFF.md` and operational state. Include the current branch and commit in each handoff.

When multiple sessions may write the same branch:

1. Create a temporary journal using `sessions/YYYY-MM-DD-HHMM-<agent>-<topic>.md`.
2. Write session-local observations there until canonical reconciliation is safe.
3. Before canonical edits, reread current files and other active journals.
4. During handoff, merge relevant journal content into canonical artifacts.
5. Delete only journals whose useful content was fully reconciled. Never delete another active session's journal merely because it exists.

Temporary journals are intentionally not committed. All canonical project state is eligible to join the user's normal Git commit. Never create a Git commit automatically.

## Handoff procedure

Maintain `HANDOFF.md` as a continuation delta at meaningful transitions. It must not duplicate the whole progress document.

An explicit `/handoff` performs full reconciliation:

1. Inspect branch, commit, dirty files, current task state, and active session journals.
2. Reconcile memory, decisions, spec, roadmap, progress, and findings.
3. Run only verification that is already required or reasonably necessary to make the handoff truthful; do not invent expensive checks solely for ceremony.
4. Rewrite `HANDOFF.md` with:
   - Updated time, branch, commit, and session focus
   - Current objective
   - Completed work
   - Uncommitted or partial changes
   - Material decisions and findings
   - Checks run and their results
   - Blockers and risks
   - Exact next actions
5. Reconcile and remove completed session journals.
6. Do not commit.

If a session ends abruptly, the most recent meaningful-transition updates are the best-effort checkpoint. Skill-only memory cannot guarantee a final session-close hook. The companion plugin's compaction hook mitigates the compaction case by instructing the summarizer to carry forward memory pointers and un-persisted decisions, findings, and blockers — but it cannot write files itself; persist state at transitions rather than relying on it.

## Milestone archival

At milestone completion, keep active files compact by moving completed roadmap detail, resolved findings, old progress snapshots, and milestone handoffs into `archive/<milestone>/`. Keep concise active summaries. Retain `DECISIONS.md` as the live supersession ledger, but compress superseded entries to stubs and archive their full detail as above. Git history remains the complete revision trail.

## Recall, correction, forgetting, and audit

- Recall only task-relevant memory and clearly distinguish verified state from remembered context.
- Correct stale memory in place rather than preserving contradictory active claims.
- On forget requests, remove direct matches from active memory and relevant archives without deleting unrelated content.
- A memory audit checks scope, duplication, provenance, staleness, conflicts, sensitive content, active-size budget, and promotion of verified findings.

## Commands and natural language

Support both ordinary language and these commands:

- `/project-init [full]`
- `/remember [global|host|project] <fact>`
- `/recall <query>`
- `/forget <query>`
- `/handoff`
- `/project-status`
- `/memory-audit [global|project|all]`

After automatic state writes, summarize them in one concise final-response line. Do not interrupt work to announce routine retrieval or every checkpoint.
