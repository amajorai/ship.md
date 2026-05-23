---
name: ship
description: Full-cycle development workflow for any non-trivial feature or fix. Runs up to 10 phases (interview, explore, plan, implement, verify, edge cases, e2e tests, simplify, security review, final verify) using the strongest available model for planning and autonomous goal loops for quality gates. Use when asked to implement a feature, fix a bug, or ship something with full quality assurance.
argument-hint: <task description>
---

# Ship

You are orchestrating a comprehensive, quality-focused development pipeline. Work through each phase in order. Do not skip or merge phases.

**Task:** {{args}}


## Phase 0: Auto-Update & Dependencies

*Skip if `{{args}}` contains `--no-update`, or if `SKILLS_AUTO_UPDATE: false` is set in your project CLAUDE.md.*

**1. Check if the `skills` CLI is available:**

```bash
skills --version 2>/dev/null || npx skills --version 2>/dev/null
```

If neither works (node/npx not on PATH), ask the user: "Install the skills CLI to enable auto-updates? (`npm install -g skills`)" — if yes, run that. If no, skip this entire phase.

**2. Auto-update this skill:**

```bash
npx skills update ship -y
```

If the skill was updated, stop here and tell the user: **"This skill was just updated. Re-run your command to use the new version."** Otherwise continue silently.

**3. Check optional skill dependencies:**

Look for `.claude/skills/edge-cases.md` and `.claude/skills/e2e.md` in the current project. If either is missing, ask the user:

> "The `/edge-cases` and `/e2e` skills power Phases 6-7. Install them now?"

If yes:

```bash
npx skills add amajorai/skills/skills/edge-cases
npx skills add amajorai/skills/skills/e2e
```

If no, note that Phases 6-7 will be skipped automatically when the user opts out during the Phase 1 interview.

## Phase 1: Interview

Before touching any code, conduct a structured interview to surface hidden requirements and establish clear acceptance criteria.

Ask the user about (combine related questions, don't fire them one by one):

- **Scope**: Which files, modules, or systems are in scope? What is explicitly out of scope?
- **Acceptance criteria**: What does done look like? How will we verify correctness?
- **Constraints**: Performance requirements, backwards compatibility, existing patterns to follow, team conventions?
- **Ambiguities**: Unclear terms, conflicting requirements, or edge cases in the task description?
- **Quality gates**: Which hardening phases do you want after implementation? Options: edge cases (`/edge-cases`), E2E tests (`/e2e`), both, or neither. Default: both.
- **GitHub issues**: Do you want to track this work with GitHub issues? (one atomic issue per implementation unit, closed by each agent on completion)
- **Implementation strategy**: How should Phase 4 run parallel units?
  - **(Recommended) Parallel subagents, shared workspace** — fastest; agents work concurrently on the same working tree with no overhead. Works for most tasks where units touch different files.
  - **Let the agent decide** — agent evaluates the plan at implementation time and picks the right strategy based on file overlap and unit size.
  - **Isolated worktrees / `/batch`** — each unit gets its own git worktree and produces a separate PR. Use only when units conflict on the same files or separate PRs are explicitly required.

Do not proceed until you have enough information to write unambiguous acceptance criteria. Write them as a numbered list and confirm with the user before continuing.


## Phase 1.5: GitHub Prerequisites Check

*Skip entirely if the user opted out of GitHub issues in Phase 1.*

Run both — if either fails, set `SHIP_GH_ENABLED=false`, tell the user why (not installed / not authenticated / no GitHub remote), and continue without issue tracking:

```bash
gh auth status 2>/dev/null && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null
```

If both succeed, set `SHIP_GH_ENABLED=true`. No issues are created yet — that happens in Phase 3 once work is decomposed into atomic units.


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

**If `SHIP_GH_ENABLED=true`**, after the user approves the plan, create one GitHub issue per atomic implementation unit. Each issue must be self-contained — an agent reading only the issue should have everything it needs. Use this template:

```
## Task
<what specifically needs to be done — one atomic, independently shippable change>

## Context
<why this is needed; what it connects to; relevant file paths, patterns, or constraints surfaced during Phase 2 exploration>

## Acceptance Criteria
- [ ] <specific, verifiable criterion>
- [ ] <specific, verifiable criterion>

## Dependencies
<list other issue numbers this unit depends on, or "none">

## Notes
<gotchas, patterns to follow, edge cases to watch for>
```

Create all issues with `gh issue create`, collect their URLs and numbers, and tell the user the full list. Label issues consistently (e.g. `--label "ship"`) if the label exists.


## Phase 4: Implement

Decompose the approved plan into **independent units** and execute in parallel using the strategy chosen in Phase 1:

- **Parallel subagents, shared workspace** *(recommended)*: spawn concurrent subagents on the same working tree, no worktrees. Fastest path — use when units touch different files.
- **Let the agent decide**: review the plan now and pick the right strategy. Default to shared workspace; switch to worktrees only if two or more units modify the same files incompatibly or a unit is a large isolated refactor that would create noisy partial state.
- **Isolated worktrees / `/batch`**: run `/batch` (creates one PR per unit) or spawn agents with `isolation: "worktree"`. Use only when units conflict on the same files or separate PRs are required.

Each agent's prompt must include its assigned issue URL (if `SHIP_GH_ENABLED=true`):

> "Your task is fully specified in this GitHub issue: `<issue URL>`. Read the Task, Context, Acceptance Criteria, and Notes before writing any code. When all acceptance criteria are satisfied and your changes are committed, close the issue: `gh issue close <number> --reason completed`"

Agents are responsible for closing their own issue on completion. Do not wait until the end of the pipeline.

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

Do not accept simplifications that break correctness, `/goal` will keep iterating until tests pass.


## Phase 9: Security Review

- **Claude Code:** Invoke the built-in `security-review` skill.
- **Codex / fallback:** Run `/goal` with this condition:

```
All changes have been audited for: (1) input validation at system boundaries; (2) authentication and authorization on new endpoints; (3) no injection vulnerabilities (SQL, XSS, command injection, path traversal); (4) no hardcoded secrets or tokens; (5) intentional and documented trust boundary crossings. All HIGH and CRITICAL findings are fixed.
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

**If `SHIP_GH_ENABLED=true`**, verify all issues created in Phase 3 are closed:

```bash
gh issue list --label "ship" --state open
```

For any still open, close them with a note explaining why (e.g. merged into another unit, superseded, or deferred):

```bash
gh issue close <number> --comment "<reason>" --reason "not planned"
```
