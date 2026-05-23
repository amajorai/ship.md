---
name: ship-fast
description: Quick implementation workflow for simple features and fixes that don't need the full pipeline. Skips security review, edge case hardening, and simplification. Five phases: interview (skippable), explore, plan, implement, verify.
argument-hint: <task description>
---

# Ship Fast

You are orchestrating a focused, quality-conscious development pipeline. Work through each phase in order.

**Task:** {{args}}


## Phase 0: Auto-Update

*Skip if `{{args}}` contains `--no-update`, or if `SKILLS_AUTO_UPDATE: false` is set in your project CLAUDE.md.*

**1. Check if the `skills` CLI is available:**

```bash
skills --version 2>/dev/null || npx skills --version 2>/dev/null
```

If neither works (node/npx not on PATH), ask the user: "Install the skills CLI to enable auto-updates? (`npm install -g skills`)" — if yes, run that. If no, skip this entire phase.

**2. Auto-update this skill:**

```bash
npx skills update ship-fast -y
```

If the skill was updated, stop here and tell the user: **"This skill was just updated. Re-run your command to use the new version."** Otherwise continue silently.


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
  - **Isolated worktrees / `/batch`** — each unit gets its own git worktree and produces a separate PR. Use only when units conflict on the same files or separate PRs are explicitly required.

Do not proceed until you have enough information to write unambiguous acceptance criteria. Write them as a numbered list and confirm with the user before continuing.


## Phase 2: Explore

Spawn **3–5 parallel subagents** to map the codebase. Each covers a distinct area:

- **Data / schema layer**: models, types, database schema, migrations
- **Feature area**: the code most directly relevant to the task
- **Tests and patterns**: how similar things are tested and implemented elsewhere
- **Dependencies and integrations**: what the affected code connects to upstream and downstream
- **Config / infrastructure**: only if the task touches deployment, environment, or build

Each subagent returns: what it found, what's relevant, and any risks or surprises.

Synthesize findings into a single **Context Summary**: current state, key constraints, implementation risks, suggested entry points.


## Phase 3: Plan

Switch to the strongest available reasoning model:
- **Claude Code:** `/model opusplan` - runs Opus for planning, auto-switches to Sonnet for execution
- **Codex:** `/model o3`, then `/plan`

The plan must specify:
1. Exact files to create or modify (with line-level specificity where possible)
2. Implementation order respecting the dependency graph
3. How each acceptance criterion from Phase 1 will be satisfied
4. Test strategy: new tests to write, existing tests to update

Do not begin implementation until the user explicitly approves the plan.


## Phase 4: Implement

Decompose the approved plan into **independent units** and execute in parallel using the strategy chosen in Phase 1:

- **Parallel subagents, shared workspace** *(recommended)*: spawn concurrent subagents on the same working tree, no worktrees. Fastest path — use when units touch different files.
- **Let the agent decide**: review the plan now and pick the right strategy. Default to shared workspace; switch to worktrees only if two or more units modify the same files incompatibly or a unit is a large isolated refactor that would create noisy partial state.
- **Isolated worktrees / `/batch`**: run `/batch` (creates one PR per unit) or spawn agents with `isolation: "worktree"`. Use only when units conflict on the same files or separate PRs are required.

Wait for all units to complete before moving to verification.


## Phase 5: Verify

Run `/goal` with this condition (adapt to the specific task):

```
All acceptance criteria from Phase 1 are met. All existing tests pass. No linting errors or type errors. The feature works end-to-end including edge cases defined during Phase 1.
```

**Claude Code fallback:** If `/goal` is unavailable, invoke the built-in `verify` skill and spawn Opus agents to validate each criterion manually.

Do not proceed until every criterion passes.


## Completion Report

- What was implemented and which files changed
- Test coverage added or modified
- Any open limitations or recommended follow-up tasks
