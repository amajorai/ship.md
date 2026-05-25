# ship

Full-cycle development workflow: interview → explore → plan → implement → verify → edge cases → e2e → simplify → security review → final verify.

## Usage

```
/ship <task description>
```

## Quality gates: evaluator loop vs. `/goal`

Phases 5 (Verify), 8 (Simplify), and 10 (Final Verify) use an **orchestrator-driven evaluator loop** — not the `/goal` CLI command.

**`/goal` is a UI/CLI stop hook.** It cannot be invoked via the `Skill` tool — calling `Skill({ skill: "goal", ... })` will fail. `/goal` registers a stop hook in the active Claude Code session; stop hooks fire at the end of every turn and cannot propagate into subagents spawned via the `Agent` tool.

**Ship's evaluator loop** is the correct pattern for multi-agent quality gates:

| | `/goal` stop hook | Ship evaluator loop |
|---|---|---|
| Who evaluates | Stop hook at CLI layer | Orchestrator (this session) |
| Works inside subagents | No | Yes |
| Iteration cap | None (until condition met or user stops) | Hard cap: 5 passes |
| Requires interactive CLI | Yes | No |

See [`references/goal-loop-notes.md`](references/goal-loop-notes.md) for a full comparison and notes on whether stop hooks can be replicated programmatically.

## Files

```
ship/
  SKILL.md                          main skill (all 10 phases)
  references/
    github-labels.md                label setup commands and color table
    github-issues.md                epic/sub-issue templates, GraphQL mutations
    agent-prompts.md                subagent prompt templates (shared vs worktree)
    goal-loop-notes.md              /goal vs evaluator loop analysis
```
