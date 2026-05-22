---
name: ship
description: Full-cycle development workflow for any non-trivial feature or fix. Runs up to 10 phases — interview, explore, plan, implement, verify, edge cases, e2e tests, simplify, security review, final verify — using the strongest available model for planning and autonomous goal loops for quality gates. Use when asked to implement a feature, fix a bug, or ship something with full quality assurance.
argument-hint: <task description>
---

# ship — Full-Cycle Development Workflow

You are orchestrating a comprehensive, quality-focused development pipeline. Work through each phase in order. Do not skip or merge phases.

**Task:** {{args}}


## Phase 1: Interview

Before touching any code, conduct a structured interview to surface hidden requirements and establish clear acceptance criteria.

Ask the user about (combine related questions — don't fire them one by one):

- **Scope**: Which files, modules, or systems are in scope? What is explicitly out of scope?
- **Acceptance criteria**: What does done look like? How will we verify correctness?
- **Constraints**: Performance requirements, backwards compatibility, existing patterns to follow, team conventions?
- **Ambiguities**: Unclear terms, conflicting requirements, or edge cases in the task description?
- **Quality gates**: Which hardening phases do you want after implementation? Options: edge cases (`/edge-cases`), E2E tests (`/e2e`), both, or neither. Default: both.

Do not proceed until you have enough information to write unambiguous acceptance criteria. Write them as a numbered list and confirm with the user before continuing.


## Phase 2: Explore

Spawn **3–5 parallel subagents** to map the codebase. Each covers a distinct area:

- **Data / schema layer** — models, types, database schema, migrations
- **Feature area** — the code most directly relevant to the task
- **Tests and patterns** — how similar things are tested and implemented elsewhere
- **Dependencies and integrations** — what the affected code connects to upstream and downstream
- **Config / infrastructure** — only if the task touches deployment, environment, or build

Each subagent returns: what it found, what's relevant, and any risks or surprises.

Synthesize findings into a single **Context Summary**: current state, key constraints, implementation risks, suggested entry points.


## Phase 3: Plan

Switch to the strongest available reasoning model:
- **Claude Code:** `/model opusplan` — runs Opus for planning, auto-switches to Sonnet for execution
- **Codex:** `/model o3`, then `/plan`

The plan must specify:
1. Exact files to create or modify (with line-level specificity where possible)
2. Implementation order respecting the dependency graph
3. How each acceptance criterion from Phase 1 will be satisfied
4. Test strategy — new tests to write, existing tests to update

Do not begin implementation until the user explicitly approves the plan.


## Phase 4: Implement

Decompose the approved plan into **independent units** and execute in parallel:

- **Claude Code:** Run `/batch` — it creates isolated git worktrees and opens one PR per unit. If `/batch` is unavailable, spawn parallel agents with `isolation: "worktree"`.
- **Codex:** Spawn parallel subagents, one per unit. Assign non-overlapping files where possible. Resolve conflicts before proceeding.

Wait for all units to complete before moving to quality gates.


## Phase 5: Verify

Run `/goal` with this condition (adapt to the specific task):

```
All acceptance criteria from Phase 1 are met. All existing tests pass. No linting errors or type errors. The feature works end-to-end including edge cases defined during Phase 1.
```

**Claude Code fallback:** If `/goal` is unavailable, invoke the built-in `verify` skill and spawn Opus agents to validate each criterion manually.

Do not proceed until every criterion passes.


## Phase 6: Edge Cases

*Skip if edge cases were opted out in Phase 1.*

Invoke the `edge-cases` skill, targeting the files and feature area changed in Phase 4:

```
/edge-cases <feature area or changed files>
```

This runs 8 parallel subagents to enumerate edge cases across boundary values, null inputs, invalid types, error states, concurrency, adversarial data, state machine violations, and auth boundaries. It then writes tests for every unhandled P0/P1 case, confirms each test fails before the fix and passes after, and verifies no regressions.

Do not proceed until all P0 and P1 edge cases are covered and the full test suite passes.


## Phase 7: E2E Tests

*Skip if E2E tests were opted out in Phase 1.*

Invoke the `e2e` skill, targeting the flows and feature area changed in Phase 4:

```
/e2e <feature or flow to cover>
```

This discovers user flows, sets up Playwright (web) or Maestro (mobile) if needed, writes golden-path and critical edge-case tests, runs them, and fixes any failures. All tests must pass before proceeding.


## Phase 8: Simplify

Run `/goal` with this condition:

```
All code added or modified for this task is as simple as possible. No unnecessary abstractions, dead code, over-engineered patterns, or speculative generality. Every line serves a concrete current requirement. All existing tests still pass.
```

Do not accept simplifications that break correctness — `/goal` will keep iterating until tests pass.


## Phase 9: Security Review

- **Claude Code:** Invoke the built-in `security-review` skill.
- **Codex / fallback:** Run `/goal` with this condition:

```
All changes have been audited for: (1) input validation at system boundaries; (2) authentication and authorization on new endpoints; (3) no injection vulnerabilities — SQL, XSS, command injection, path traversal; (4) no hardcoded secrets or tokens; (5) intentional and documented trust boundary crossings. All HIGH and CRITICAL findings are fixed.
```

Document any accepted LOW or MEDIUM findings with explicit rationale before proceeding.


## Phase 10: Final Verify

Repeat Phase 5. Confirm the codebase is shippable after hardening, simplification, and security fixes:

1. All original acceptance criteria still pass
2. No regressions from Phase 6 (edge cases)
3. No regressions from Phase 7 (E2E tests)
4. No regressions from Phase 8 (simplify)
5. No regressions from Phase 9 (security)
6. Application is in a clean, deployable state


## Completion Report

- What was implemented and which files changed
- Edge cases found and hardened (count by priority tier)
- E2E tests written (golden path + edge cases, if opted in)
- Test coverage added or modified
- Security findings and their resolutions
- Any open limitations or recommended follow-up tasks
