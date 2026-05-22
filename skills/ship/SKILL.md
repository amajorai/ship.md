---
name: ship
description: Full-cycle development workflow for any non-trivial feature or fix. Runs 9 phases — interview, explore, plan, implement, verify, edge cases, simplify, security review, final verify — using the strongest available model for planning and autonomous goal loops for quality gates. Use when asked to implement a feature, fix a bug, or ship something with full quality assurance.
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

Spawn **8 parallel subagents**, one per category, targeting the files and feature area changed in Phase 4. Each enumerates every edge case it can find and returns a numbered list with a risk rating (LOW / MEDIUM / HIGH / CRITICAL).

| Subagent | Category | What to look for |
|----------|----------|-----------------|
| 1 | **Boundary values** | min/max, zero, one, empty, off-by-one, integer overflow/underflow, float precision |
| 2 | **Null / missing / undefined** | null inputs, undefined fields, missing keys, unset env vars, absent config |
| 3 | **Invalid input types & formats** | wrong type coercions, malformed strings, bad dates/times, invalid enums, unexpected encoding |
| 4 | **Error states & exception paths** | network failures, timeouts, partial writes, disk full, DB unavailable, external service 500s |
| 5 | **Concurrency & ordering** | race conditions, double-submit, out-of-order events, stale reads after writes, cache invalidation |
| 6 | **Large / adversarial data** | very large payloads, deeply nested objects, extremely long strings, binary/emoji/RTL in text fields, injection attempts |
| 7 | **State machine violations** | calling operations in wrong order, acting on deleted/expired/cancelled resources, re-entrancy |
| 8 | **Auth & permission boundaries** | unauthenticated access, cross-tenant data leakage, privilege escalation, token expiry mid-request |

Each subagent must read the relevant source files before enumerating.

**Prioritize & deduplicate:** Consolidate into a master list sorted by risk × likelihood — P0 (CRITICAL / near-certain), P1 (HIGH / plausible), P2 (MEDIUM), P3 (LOW). Present to the user and confirm before writing tests.

**Write tests:** For each unhandled P0 and P1 case, write a focused test following the repo's existing test patterns. Run each test immediately — a failing test confirms the gap is real.

**Harden:** For each failing test, implement the minimal fix, re-run the test, and verify no regressions. Fix one at a time.

**Full suite:** Run `bun test` (or the project's test command). All tests must pass.

Do not proceed until all P0 and P1 edge cases are covered and the full test suite passes.


## Phase 7: Simplify

Run `/goal` with this condition:

```
All code added or modified for this task is as simple as possible. No unnecessary abstractions, dead code, over-engineered patterns, or speculative generality. Every line serves a concrete current requirement. All existing tests still pass.
```

Do not accept simplifications that break correctness — `/goal` will keep iterating until tests pass.


## Phase 8: Security Review

- **Claude Code:** Invoke the built-in `security-review` skill.
- **Codex / fallback:** Run `/goal` with this condition:

```
All changes have been audited for: (1) input validation at system boundaries; (2) authentication and authorization on new endpoints; (3) no injection vulnerabilities — SQL, XSS, command injection, path traversal; (4) no hardcoded secrets or tokens; (5) intentional and documented trust boundary crossings. All HIGH and CRITICAL findings are fixed.
```

Document any accepted LOW or MEDIUM findings with explicit rationale before proceeding.


## Phase 9: Final Verify

Repeat Phase 5. Confirm the codebase is shippable after edge case hardening, simplification, and security fixes:

1. All original acceptance criteria still pass
2. No regressions from Phase 6 (edge cases)
3. No regressions from Phase 7 (simplify)
4. No regressions from Phase 8 (security)
5. Application is in a clean, deployable state


## Completion Report

- What was implemented and which files changed
- Edge cases found and hardened (count by priority tier)
- Test coverage added or modified
- Security findings and their resolutions
- Any open limitations or recommended follow-up tasks
