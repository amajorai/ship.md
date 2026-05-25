---
name: ship-fast
description: "Quick implementation workflow for simple features and fixes that don't need the full pipeline. Skips security review, edge case hardening, and simplification. Five phases: interview (skippable), explore, plan, implement, verify."
argument-hint: <task description>
---

# Ship Fast

You are orchestrating a focused, quality-conscious development pipeline. Work through each phase in order.

**Task:** {{args}}


## Phase 0: Auto-Update

*Skip this entire phase unless `{{args}}` contains `--update`, or `SKILLS_AUTO_UPDATE: true` is set in your project CLAUDE.md.*

This phase is best-effort and must never block the user. If the command below fails (CLI not installed, no network, node/npx not on PATH), continue silently to Phase 1 — do not prompt the user to install anything.

```bash
npx --yes skills update ship-fast -y 2>/dev/null || true
```

If — and only if — the command output indicates the skill was actually updated, stop here and tell the user: **"This skill was just updated. Re-run your command to use the new version."** In every other case (no update available, command failed, CLI missing), continue silently to Phase 1.


## Phase 1: Interview

*Skip if `{{args}}` is already specific enough — clear scope, obvious acceptance criteria, no ambiguities. Jump straight to Phase 2.*

Ask the user in a single message (combine all questions):

- **Scope**: Which files, modules, or systems are in scope? What is explicitly out of scope?
- **Acceptance criteria**: What does done look like? How will we verify correctness?
- **Constraints**: Performance requirements, backwards compatibility, existing patterns to follow, team conventions?
- **Ambiguities**: Unclear terms, conflicting requirements, or edge cases in the task description?
- **Implementation strategy**: How should Phase 4 run parallel units?
  - **(Recommended) Parallel subagents, shared workspace** — fastest; agents work concurrently on the same working tree with no overhead. Works for most tasks where units touch different files.
  - **Let the agent decide** — agent evaluates the plan at implementation time and picks the right strategy based on file overlap and unit size.
  - **Isolated worktrees** — each unit gets its own git worktree and produces a separate PR. Use only when units conflict on the same files or separate PRs are explicitly required.

Do not proceed until you have enough information to write unambiguous acceptance criteria. Write them as a numbered list and confirm with the user before continuing.

Once the user confirms, create tasks for all remaining phases using `TaskCreate`: "Explore codebase", "Plan implementation", "Implement", "Verify". Set up `addBlockedBy` dependencies so each phase is blocked by the previous one.


## Phase 2: Explore

Mark the Explore task `in_progress`. Spawn **3–5 parallel subagents** to map the codebase. Each covers a distinct area:

- **Data / schema layer**: models, types, database schema, migrations
- **Feature area**: the code most directly relevant to the task
- **Tests and patterns**: how similar things are tested and implemented elsewhere
- **Dependencies and integrations**: what the affected code connects to upstream and downstream
- **Config / infrastructure**: only if the task touches deployment, environment, or build

Each subagent returns: what it found, what's relevant, and any risks or surprises.

Synthesize findings into a single **Context Summary**: current state, key constraints, implementation risks, suggested entry points. Mark the Explore task `completed`.


## Phase 3: Plan

Mark the Plan task `in_progress`. Call the `EnterPlanMode` tool to switch into plan mode. This displays the plan to the user in the dedicated plan UI and uses the strongest available model for reasoning.

If `EnterPlanMode` is unavailable (Codex or other agents): switch to the strongest reasoning model available and present the plan as a structured markdown block.

The plan must specify:
1. Exact files to create or modify (with line-level specificity where possible)
2. Implementation order respecting the dependency graph
3. How each acceptance criterion from Phase 1 will be satisfied
4. Test strategy: new tests to write, existing tests to update

Do not begin implementation until the user explicitly approves the plan. Call `ExitPlanMode` once the user approves to return to normal execution mode. Mark the Plan task `completed`.


## Phase 4: Implement

Mark the Implement task `in_progress`. Decompose the approved plan into **independent units** and execute in parallel using the strategy chosen in Phase 1:

- **Parallel subagents, shared workspace** *(recommended)*: spawn concurrent subagents using the `Agent` tool on the same working tree. Fastest path — use when units touch different files.
- **Let the agent decide**: review the plan now and pick the right strategy. Default to shared workspace; switch to isolated worktrees only if two or more units modify the same files incompatibly or a unit is a large isolated refactor that would create noisy partial state.
- **Isolated worktrees**: spawn agents using the `Agent` tool with `isolation: "worktree"`. Each agent works in its own git worktree. Create PRs after each completes with `gh pr create`.

Wait for all units to complete before moving to verification. Mark the Implement task `completed`.


## Phase 5: Verify

Mark the Verify task `in_progress`. Run an in-session goal loop (max 5 passes) — do not spawn a subagent:

1. Run the full test suite, lint/typecheck, and smoke-test end-to-end yourself using Bash.
2. Evaluate the output against each Phase 1 acceptance criterion.
3. All criteria pass → proceed. Failures remain → fix them directly (edit files, re-run), count as one pass.
4. After 5 passes with failures → surface to user for direction before continuing.

Mark the Verify task `completed`.


## Completion Report

- What was implemented and which files changed
- Test coverage added or modified
- Any open limitations or recommended follow-up tasks
