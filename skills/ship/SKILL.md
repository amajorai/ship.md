---
name: ship
description: Full-cycle development workflow for any non-trivial feature or fix. Runs up to 10 phases (interview, explore, plan, implement, verify, edge cases, e2e tests, simplify, security review, final verify) using the strongest available model for planning and autonomous goal loops for quality gates. Use when asked to implement a feature, fix a bug, or ship something with full quality assurance.
argument-hint: <task description>
---

# Ship

You are orchestrating a comprehensive, quality-focused development pipeline. Work through each phase in order. Do not skip or merge phases.

**Task:** {{args}}


## Phase 0: Auto-Update (opt-in)

*Skip unless `{{args}}` contains `--update`, or `SKILLS_AUTO_UPDATE: true` is set in your project CLAUDE.md.*

```bash
npx --yes skills update ship -y 2>/dev/null || true
```

If the output indicates the skill was actually updated, stop and tell the user: **"This skill was just updated. Re-run your command to use the new version."** Otherwise continue silently to Phase 1.


## Phase 1: Interview

Before touching any code, conduct a structured interview to surface hidden requirements and establish clear acceptance criteria.

Ask the user about (combine related questions, don't fire them one by one):

- **Scope**: Which files, modules, or systems are in scope? What is explicitly out of scope?
- **Acceptance criteria**: What does done look like? How will we verify correctness?
- **Constraints**: Performance requirements, backwards compatibility, existing patterns, team conventions?
- **Ambiguities**: Unclear terms, conflicting requirements, or edge cases in the task description?
- **Quality gates**: Edge cases, E2E tests, both, or neither? Default: both.
- **GitHub issues**: Track this work with GitHub issues?
- **GitHub deployment checks**: Should the verify phases check that GitHub deployments succeed? (polls until the deployment passes, diagnoses and fixes on failure — opt in if this repo has CI/CD deployments)
- **Implementation strategy**: Parallel subagents shared workspace (recommended) / let agent decide / isolated worktrees?

Do not proceed until you have unambiguous acceptance criteria confirmed by the user.

**Optional-dependency check.** Once quality gates are confirmed, check whether edge-cases/e2e skills are installed:

```bash
ls .claude/skills/edge-cases.md .claude/skills/e2e.md 2>/dev/null
```

Install missing skills for opted-in gates (best-effort — skip that gate's phase if install fails):

```bash
npx skills add amajorai/skills/skills/edge-cases && echo "EDGE_CASES_INSTALLED" || echo "EDGE_CASES_INSTALL_FAILED"
npx skills add amajorai/skills/skills/e2e && echo "E2E_INSTALLED" || echo "E2E_INSTALL_FAILED"
```

At the end of the interview, create tasks for every remaining phase with `TaskCreate`. Set `addBlockedBy` so each phase is blocked by the previous one. Skip tasks for opted-out phases.

**Track in working memory (not shell variables):** quality gate choices + skill availability, implementation strategy, `SHIP_GH_ENABLED`, `SHIP_CHECK_GH_DEPLOYMENTS`, GitHub issue numbers/URLs.


## Phase 1.5: GitHub Prerequisites Check

*Skip if user opted out of GitHub issues — set `SHIP_GH_ENABLED=false` and continue.*

```bash
gh auth status && gh repo view --json nameWithOwner -q .nameWithOwner
```

If either fails: set `SHIP_GH_ENABLED=false`, tell the user why, and continue.

If both pass: set `SHIP_GH_ENABLED=true`. Then set up ship labels — see [references/github-labels.md](references/github-labels.md) for the exact commands and label/color table.


## Phase 2: Explore

Mark the Explore task `in_progress`. Spawn **3–5 parallel subagents** covering distinct areas:

- Data / schema layer (models, types, database schema, migrations)
- Feature area (code most directly relevant to the task)
- Tests and patterns (how similar things are tested elsewhere)
- Dependencies and integrations (what affected code connects to upstream/downstream)
- Config / infrastructure (only if task touches deployment, environment, or build)

Each subagent returns: what it found, what's relevant, and any risks or surprises.

Synthesize findings into a **Context Summary**: current state, key constraints, implementation risks, suggested entry points. Mark Explore `completed`.


## Phase 3: Plan

Mark the Plan task `in_progress`. Call `EnterPlanMode` (or use the strongest reasoning model if unavailable).

The plan must specify:
1. Exact files to create or modify (line-level specificity where possible)
2. Implementation order respecting the dependency graph
3. How each acceptance criterion from Phase 1 will be satisfied
4. Test strategy: new tests to write, existing tests to update

Do not begin implementation until the user explicitly approves. Revise and re-present as many times as needed, then call `ExitPlanMode`.

**If `SHIP_GH_ENABLED=false`:** mark Plan `completed` and proceed to Phase 4.

**If `SHIP_GH_ENABLED=true`:** after plan approval, create GitHub issues. For a single atomic unit, create one issue (no epic). For multiple units, create an epic + sub-issues and link them. See [references/github-issues.md](references/github-issues.md) for templates, bash commands, and GraphQL mutations. Mark Plan `completed` only after issues exist.


## Phase 4: Implement

Mark Implement `in_progress`. Decompose the plan into independent units and execute using the strategy from Phase 1.

**Dependency ordering:** group units into waves (wave 1 = no blockers, wave 2 = depends on wave 1, etc.). Dispatch all units in the current wave in parallel, wait for all to return, then dispatch the next wave. Never instruct an agent to self-wait.

**Non-GitHub path:** spawn one agent per unit with goal, context, file paths, and acceptance criteria inline. Agents implement and commit only — no PRs.

**GitHub path:** each agent gets its issue URL. For prompt templates (shared workspace vs isolated worktrees), see [references/agent-prompts.md](references/agent-prompts.md). After all shared-workspace waves finish, open a single PR covering all issues.

After all waves complete, mark Implement `completed`.


## Phase 5: Verify

Mark Verify `in_progress`. Run an in-session goal loop (max 5 passes) — do not spawn a subagent:

1. Run the project build (e.g. `bun run build`) to catch compilation errors before running tests.
2. Run the full test suite, lint/typecheck, and smoke-test end-to-end yourself using Bash.
3. Evaluate the output against each Phase 1 acceptance criterion.
4. All criteria pass → proceed. Failures remain → fix them directly (edit files, re-run), count as one pass.
5. After 5 passes with failures → surface to user for direction before continuing.

**If `SHIP_CHECK_GH_DEPLOYMENTS=true`:** once all local criteria pass, enter a deployment-check loop (max 20 polls, ~30 s apart):

```bash
# Fetch the latest deployment ID (adjust environment name as needed)
gh api "repos/{owner}/{repo}/deployments?environment=production&per_page=1" --jq '.[0].id'
# Check its current status
gh api "repos/{owner}/{repo}/deployments/{id}/statuses?per_page=1" --jq '.[0].state'
```

- `success` → continue to next phase.
- `pending` / `in_progress` / `queued` → wait 30 s and poll again.
- `failure` / `error` → inspect the deployment logs, diagnose the root cause, fix the code, push, and restart the poll from the beginning (counts as one fix attempt). After 3 fix attempts without reaching `success`, surface to the user before continuing.

Mark Verify `completed`.


## Phase 6: Edge Cases

*Skip if opted out or `edge-cases` skill unavailable (declined or failed install in Phase 1).*

Mark Edge cases `in_progress`. Invoke:

```
Skill({ skill: "edge-cases", args: "<feature area or changed files>" })
```

Do not proceed until all P0/P1 edge cases are covered and the full test suite passes. Mark Edge cases `completed`.


## Phase 7: E2E Tests

*Skip if opted out or `e2e` skill unavailable.*

Mark E2E tests `in_progress`. Invoke:

```
Skill({ skill: "e2e", args: "<feature or flow to cover>" })
```

All tests must pass before proceeding. Mark E2E tests `completed`.


## Phase 8: Simplify

Mark Simplify `in_progress`. Run an in-session goal loop (max 5 passes) — do not spawn a subagent:

**Condition:** All code added or modified is as simple as possible. No unnecessary abstractions, dead code, over-engineering, or speculative generality. Every line serves a concrete current requirement. All existing tests still pass.

1. Review modified files yourself: remove dead code, flatten abstractions, simplify logic.
2. Run tests. Green + no further simplification needed → condition met, proceed.
3. Tests break → revert only the breaking change, re-evaluate.
4. Hard gate: never leave this phase with failing tests.

Mark Simplify `completed`.


## Phase 9: Security Review

Mark Security review `in_progress`. Invoke:

```
Skill({ skill: "security-review", args: "<feature area + changed files>" })
```

If unavailable, spawn an agent with this goal condition (scoped to files changed in this task):

> All changes audited for: input validation at system boundaries, auth/authz on new endpoints, no injection vulnerabilities (SQL/XSS/command/path traversal), no hardcoded secrets, intentional trust boundary crossings documented. All HIGH and CRITICAL findings fixed.

If a HIGH/CRITICAL finding can't be resolved within ~5 attempts, surface to user before continuing.

Mark Security review `completed`.


## Phase 10: Final Verify

Mark Final verify `in_progress`. Same in-session goal loop as Phase 5 (max 5 passes) against:

1. Run the project build (`bun run build` or equivalent) — must be clean.
2. All original acceptance criteria still pass.
3. No regressions from Phases 6–9.
4. Application is in a clean, deployable state.

Surface blocking failures to user if unmet after 5 passes.

**If `SHIP_CHECK_GH_DEPLOYMENTS=true`:** repeat the same deployment-check loop from Phase 5 — poll until `success`, fix and re-push on `failure`/`error`, escalate to user after 3 fix attempts.

Mark Final verify `completed`.


## Completion Report

Report the following (omit lines for skipped phases):

- What was implemented and which files changed
- Edge cases found and hardened (count by priority tier)
- E2E tests written (golden path + edge cases)
- Test coverage added or modified
- Security findings and their resolutions
- Any open limitations or recommended follow-up

**If `SHIP_GH_ENABLED=true`:** include epic + sub-issue URLs and PR URL(s). Then verify all sub-issues are closed — check each by number (not by label, since the epic also carries the ship label). Close any the agent didn't close. For a single-unit task, just that one issue — no epic. Close the epic last. See [references/github-issues.md](references/github-issues.md) for the closing commands.
