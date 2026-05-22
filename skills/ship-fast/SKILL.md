---
name: ship-fast
description: Quick implementation workflow for simple features and fixes that don't need the full pipeline. Skips security review, edge case hardening, and simplification — explore, plan, implement, verify and done.
argument-hint: <task description>
---

# ship-fast — Quick Implementation Workflow

**Task:** {{args}}


## Phase 1: Explore

Spawn **2–3 parallel subagents** to map the relevant parts of the codebase:

- **Feature area** — the code most directly relevant to the task
- **Tests and patterns** — how similar things are tested and implemented elsewhere
- **Dependencies** — what the affected code connects to upstream and downstream

Each subagent returns: what it found, what's relevant, and any risks or surprises.

Synthesize findings into a brief **Context Summary**: current state, key constraints, and suggested entry points.


## Phase 2: Plan

Produce a concrete plan specifying:

1. Exact files to create or modify
2. Implementation order respecting the dependency graph
3. Test strategy — new tests to write, existing tests to update

Do not begin implementation until the user explicitly approves the plan.


## Phase 3: Implement

Execute the approved plan. For independent units, work in parallel using subagents with `isolation: "worktree"` where appropriate.

Wait for all units to complete before moving to verification.


## Phase 4: Verify

Invoke the built-in `verify` skill to confirm the change works as expected:

- All intended behavior works end-to-end
- Existing tests pass
- No linting or type errors

If anything fails, fix it and re-verify before reporting done.
