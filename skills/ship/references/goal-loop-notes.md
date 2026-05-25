# Quality Gate Loop vs. `/goal` Stop Hooks

## Important: `/goal` Is Not Invokable as a Skill

`/goal` is a **UI/CLI command**, not a skill. You cannot call it via `Skill({ skill: "goal", ... })` — that will fail. `/goal` is a built-in Claude Code command that registers a stop hook in the shell process running the CLI.

Do **not** attempt to invoke `/goal` from within this skill or any subagent prompt.

---

## How `/goal` Actually Works

When a user types `/goal <condition>`, Claude Code:
1. Registers a **stop hook** — a shell callback that fires at the end of every Claude turn in that session.
2. The stop hook calls an LLM evaluation of the condition against the current state.
3. If the condition is not yet met, the hook injects feedback into the next turn, forcing Claude to continue.
4. The loop runs entirely at the **UI/CLI layer**, in the main orchestrator's session.

Key constraints:
- Stop hooks fire on the **main session's turns only** — they do not propagate into subagents spawned via the `Agent` tool.
- Stop hooks require an interactive Claude Code session and cannot be set programmatically from within a skill.
- Each hook evaluation makes an LLM call with the full context, so it carries token cost per turn.

---

## How Ship's External-Evaluator Loop Works

Phases 5, 8, and 10 use a different pattern — **orchestrator-driven evaluation**:

1. The orchestrator (this skill's session) spawns a subagent to do work (run tests, simplify code, etc.) and return a structured report.
2. **The orchestrator itself** evaluates the report against the acceptance criteria — not the subagent, and not a stop hook.
3. If criteria are not met and passes remain, the orchestrator spawns another subagent with the failure context.
4. After 5 passes without success, the orchestrator surfaces to the user.

This is intentionally different from `/goal`:

| | `/goal` stop hook | Ship's evaluator loop |
|---|---|---|
| Who evaluates | Stop hook (LLM call at CLI layer) | Orchestrator (this session) |
| Works on subagents | No | Yes — orchestrator controls |
| Max iterations | Until condition met or user stops | Hard cap: 5 passes |
| Requires interactive CLI | Yes | No |
| Can be invoked in a skill | No | Yes (built in) |

---

## Why Not Use Stop Hooks for Subagents?

Stop hooks cannot reach subagents. A subagent spawned via the `Agent` tool runs as an isolated session — the parent session's stop hooks do not fire inside it. Attempting to register a `/goal` inside a subagent prompt would require the subagent to be running its own interactive Claude Code session, which is not the case when spawned via the tool.

The orchestrator-driven loop is the correct architecture for quality gates in multi-agent workflows: the orchestrator maintains the loop, inspects subagent output, and decides continuation. This gives more control (explicit pass cap, structured failure reporting) than a stop hook would.

---

## When to Use `/goal` Instead

`/goal` is the right choice for **single-session, interactive work** where:
- You want Claude to keep iterating without manually re-prompting.
- You don't need subagents — all work happens in the main session.
- The user is present in an interactive Claude Code session.

For multi-agent orchestration (like ship), the external-evaluator loop is the appropriate pattern.
