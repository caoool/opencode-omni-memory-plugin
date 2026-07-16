/**
 * omni-memory plugin for OpenCode.
 *
 * Companion to the `omni-memory` skill (skills/omni-memory/SKILL.md). Two hooks:
 *
 * 1. `experimental.chat.messages.transform` — prepends a compact orientation
 *    bootstrap to the first user message of each session so memory behavior,
 *    self-evolution capture, and the single-writer rule are unconditionally in
 *    context from turn one (the skill itself stays lazily loaded).
 * 2. `experimental.session.compacting` — instructs the compaction summarizer to
 *    carry forward memory pointers and any un-persisted decisions, findings,
 *    blockers, and self-evolution lessons, so continuation summaries do not
 *    silently drop durable state.
 *
 * The bootstrap is embedded as a constant: no per-step fs reads, and the hook
 * fires on every agent step, so idempotence is guarded by BOOTSTRAP_MARK.
 */

const BOOTSTRAP_MARK = "<omni-memory:bootstrap>";

const BOOTSTRAP = `${BOOTSTRAP_MARK}
You have persistent Markdown memory (omni-memory). This bootstrap is already loaded; do not re-load it as a skill for orientation alone.

Auto-loaded every turn via instructions: global memory (~/.config/opencode/memory/GLOBAL.md), project memory (.opencode/project/MEMORY.md), and project handoff (.opencode/project/HANDOFF.md). Detailed state lives in .opencode/project/ (INDEX, CHARTER, SPEC, ROADMAP, PROGRESS, FINDINGS, DECISIONS, sessions/, archive/) — retrieve on demand.

Rules that hold for every substantive task (implementation, debugging, refactor, planning, review, memory commands):
1. Orient silently before acting: use the auto-loaded memory, read INDEX/CHARTER when present, and compare the handoff against the real repository state. Verified current state beats remembered state. Load the omni-memory skill for full procedure when work is substantive; skip orientation for trivial or scratch work.
2. Update state at meaningful transitions (material decision, milestone change, new blocker, verified finding, user correction) — not after every edit, and never when nothing durable was learned.
3. Self-evolution is automatic: capture explicit user corrections and repeated friction as one consolidated entry in the narrowest correct scope, at the moment they occur. When a lesson is really a standing behavior rule, promote it into the governing configuration (AGENTS.md section, agent, skill, or command) and shrink the memory entry to a pointer. Rewrite or merge instead of appending; fix stale or contradictory memory in place immediately.
4. Single writer: only the primary agent writes memory/ or .opencode/project/. If you are a subagent, treat memory as read-only and return candidate lessons, decisions, and findings in your report instead of writing them.
5. Never retain secrets, credentials, raw logs, transcripts, temporary status, or unverified assumptions.

Red flags — if you think any of these, stop and check memory or persist state instead:
"I remember this project's state" (reread the files) · "this edit is too small to checkpoint" (was there a decision, correction, or blocker? then record it) · "I'll update the handoff later" (later never comes; update at the transition) · "the user already told me this once" (a second occurrence of the same friction is a capture trigger) · "the subagent can note that in memory" (it cannot; single writer).

Commands: /project-init, /remember, /recall, /forget, /handoff, /project-status, /memory-audit.
</omni-memory:bootstrap>`;

const COMPACTION_CONTEXT = `## omni-memory continuation requirements

This session uses persistent Markdown memory. The continuation summary MUST preserve:
1. The memory system pointers: global memory at ~/.config/opencode/memory/GLOBAL.md; project state under <project-root>/.opencode/project/ (MEMORY.md and HANDOFF.md auto-load; INDEX, CHARTER, SPEC, ROADMAP, PROGRESS, FINDINGS, DECISIONS, sessions/, archive/ on demand).
2. Every decision, verified finding, user correction, or blocker from this session that has NOT yet been written to those files — list each one explicitly so the continuation can persist it at the next meaningful transition.
3. Any pending self-evolution obligations: lessons that should be captured to memory, or memory entries that should be promoted into AGENTS.md, an agent, skill, or command.
4. The current handoff intent: branch, objective, exact next actions.
After compaction, the agent must re-orient from the memory files rather than trusting the summary alone; verified repository state overrides remembered state.`;

export const OmniMemoryPlugin = async () => {
  return {
    "experimental.chat.messages.transform": async (_input, output) => {
      if (!output.messages.length) return;
      const firstUser = output.messages.find((m) => m.info.role === "user");
      if (!firstUser || !firstUser.parts.length) return;
      // Idempotence: the hook fires on every agent step and message arrays may
      // be rebuilt from the DB, so skip if the bootstrap is already present.
      if (
        firstUser.parts.some(
          (p) => p.type === "text" && typeof p.text === "string" && p.text.includes(BOOTSTRAP_MARK),
        )
      )
        return;
      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: "text", text: BOOTSTRAP });
    },

    "experimental.session.compacting": async (_input, output) => {
      output.context.push(COMPACTION_CONTEXT);
    },
  };
};
