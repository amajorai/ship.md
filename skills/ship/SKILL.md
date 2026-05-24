---
name: ship
description: Full-cycle development workflow for any non-trivial feature or fix. Runs up to 10 phases (interview, explore, plan, implement, verify, edge cases, e2e tests, simplify, security review, final verify) using the strongest available model for planning and autonomous goal loops for quality gates. Use when asked to implement a feature, fix a bug, or ship something with full quality assurance.
argument-hint: <task description>
---

# Ship

You are orchestrating a comprehensive, quality-focused development pipeline. Work through each phase in order. Do not skip or merge phases.

**Task:** {{args}}


## Phase 0: Auto-Update (opt-in)

*Skip this entire phase unless `{{args}}` contains `--update`, or `SKILLS_AUTO_UPDATE: true` is set in your project CLAUDE.md.* This phase ONLY handles auto-updating the skill — optional-dependency detection lives in Phase 1 and always runs.

This phase is best-effort and must never block the user. If the command below fails (CLI not installed, no network, node/npx not on PATH), continue silently to Phase 1 — do not prompt the user to install anything.

```bash
npx --yes skills update ship -y 2>/dev/null || true
```

If — and only if — the command output indicates the skill was actually updated, stop here and tell the user: **"This skill was just updated. Re-run your command to use the new version."** In every other case (no update available, command failed, CLI missing), continue silently to Phase 1.

## Phase 1: Interview

Before touching any code, conduct a structured interview to surface hidden requirements and establish clear acceptance criteria.

Ask the user about (combine related questions, don't fire them one by one):

- **Scope**: Which files, modules, or systems are in scope? What is explicitly out of scope?
- **Acceptance criteria**: What does done look like? How will we verify correctness?
- **Constraints**: Performance requirements, backwards compatibility, existing patterns to follow, team conventions?
- **Ambiguities**: Unclear terms, conflicting requirements, or edge cases in the task description?
- **Quality gates**: Which hardening phases do you want after implementation? Options: edge cases, E2E tests, both, or neither. Default: both.
- **GitHub issues**: Do you want to track this work with GitHub issues? (one atomic issue per implementation unit, closed by each agent on completion)
- **Implementation strategy**: How should Phase 4 run parallel units?
  - **(Recommended) Parallel subagents, shared workspace** — fastest; agents work concurrently on the same working tree with no overhead. Works for most tasks where units touch different files.
  - **Let the agent decide** — agent evaluates the plan at implementation time and picks the right strategy based on file overlap and unit size.
  - **Isolated worktrees** — each unit gets its own git worktree (and, on the GitHub path, its own PR). Use only when units conflict on the same files or separate PRs are explicitly required.

Do not proceed until you have enough information to write unambiguous acceptance criteria. Write them as a numbered list and confirm with the user before continuing.

**Optional-dependency check (runs every time, regardless of whether Phase 0 ran).** Phases 6-7 use the `edge-cases` and `e2e` skills. Once you know which quality gates the user wants, check whether the corresponding skills are installed:

```bash
ls .claude/skills/edge-cases.md .claude/skills/e2e.md 2>/dev/null
```

For each gate the user opted into whose skill is missing, offer to install it now (best-effort — if install fails, tell the user and skip that gate's phase):

```bash
npx --yes skills add amajorai/skills/skills/edge-cases   # only if edge cases opted in and missing
npx --yes skills add amajorai/skills/skills/e2e          # only if E2E opted in and missing
```

If the user declines an install, or it fails, the corresponding phase (6 and/or 7) is skipped — record that in your notes so the phase is not attempted. Do not check or install a skill for a gate the user opted out of.

Once the user has confirmed the acceptance criteria, the quality gates, the GitHub-issues decision, and the implementation strategy — i.e. at the very end of the interview, not before — create tasks for every remaining phase using `TaskCreate`. Create all phase tasks up front so progress is visible from the start. Use the phase names as subjects (e.g. "Explore codebase", "Plan implementation", "Implement", "Verify", "Edge cases", "E2E tests", "Simplify", "Security review", "Final verify"). Skip tasks for phases the user opted out of. Set up dependencies with `addBlockedBy` so each phase is blocked by the previous one in the *remaining* sequence — when a phase is skipped, chain across the gap (e.g. if edge cases is skipped but E2E is kept, "E2E tests" is blocked by "Verify"; if both are skipped, "Simplify" is blocked by "Verify").

**State you must track for the rest of the pipeline (in your own working memory / notes, not shell variables — shell state does not persist between tool calls):**

- Whether each quality gate (edge cases, E2E) was opted in, AND whether its skill is actually available — a gate that was opted in but whose skill was declined or failed to install is effectively off, and its phase is skipped.
- The chosen Phase 4 implementation strategy.
- `SHIP_GH_ENABLED` (set in Phase 1.5).
- If GitHub is enabled: the epic issue number and URL, and the number/URL of every sub-issue. The shell variables shown in later phases (`$EPIC_NUM`, `$EPIC_ID`, etc.) are only valid within the single command block that defines them; whenever a later phase needs an issue number, substitute the actual number you recorded here rather than relying on a variable persisting.


## Phase 1.5: GitHub Prerequisites Check

*If the user opted out of GitHub issues in Phase 1, set `SHIP_GH_ENABLED=false` and skip the rest of this phase.* (Recording it explicitly as false means every later "If `SHIP_GH_ENABLED=true`" branch is unambiguously off.)

Run both checks — if either fails, set `SHIP_GH_ENABLED=false`, tell the user why (gh not installed / not authenticated / no GitHub remote), and continue without issue tracking:

```bash
gh auth status && gh repo view --json nameWithOwner -q .nameWithOwner
```

If both succeed, set `SHIP_GH_ENABLED=true` and record this decision in your notes (it is referenced in Phases 3, 4, and the Completion Report).

**Ensure the `ship` label exists** so issue creation in Phase 3 does not fail. `gh label create` errors if the label already exists, so make it idempotent. Use `--force` (supported by current `gh`), which creates the label or updates it in place and exits 0 either way, so a real failure (no auth/network) still surfaces a non-zero exit rather than being masked:

```bash
gh label create ship --color BFD4F2 --description "Created by the ship skill" --force
```

If your `gh` version does not support `--force`, fall back to the idempotent form below — but note its error is swallowed, so if it reports "already exists" yet issue creation later fails on a missing label, re-check auth:

```bash
gh label create ship --color BFD4F2 --description "Created by the ship skill" 2>/dev/null \
  || echo "label 'ship' already present (or label creation skipped)"
```

No issues are created yet — that happens in Phase 3 once work is decomposed into atomic units.


## Phase 2: Explore

Mark the Explore task `in_progress` before starting. Spawn **3–5 parallel subagents** to map the codebase. Each covers a distinct area:

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

Do not begin implementation until the user explicitly approves the plan. **If the user rejects or requests changes to the plan, revise it and present it again — repeat this approve/revise loop as many times as needed.** Only call `ExitPlanMode` once the user approves, to return to normal execution mode. (When using the markdown fallback because `EnterPlanMode` was unavailable, there is no plan mode to exit — just proceed once the user approves.)

Do the GitHub issue creation below (if applicable) *before* marking the Plan task `completed`, because issue creation is part of planning. **If `SHIP_GH_ENABLED=false`**, there are no issues to create — mark the Plan task `completed` now and proceed to Phase 4. **If `SHIP_GH_ENABLED=true`**, after the user approves the plan, decompose the plan into atomic implementation units, then create issues (Steps 1–4 below); mark the Plan task `completed` only after the issues exist. **Exit plan mode first:** the `gh` commands below mutate state and cannot run while plan mode is active, so if you used `EnterPlanMode`, you must have already called `ExitPlanMode` (per the paragraph above) before running any of them.

**Single-unit shortcut:** If the plan is a single atomic unit (one independently shippable change), do *not* create an epic-plus-sub-issue hierarchy — that overhead adds no value for one unit. Instead create exactly one issue using the sub-issue template in Step 2 (its "Blocked by" will be "none"), record its number/URL, tell the user, then mark the Plan task `completed` and proceed to Phase 4 — skip Steps 1, 3, and 4 entirely (including their closing instructions, which assume an epic exists). The single agent in Phase 4 is pointed at this one issue. Only proceed with the full epic structure below when there are two or more units.

**Step 1: Create the parent epic issue**

One issue representing the full feature. Its body is a tasklist of all sub-issues (the tasklist is filled in by Step 4, after sub-issues exist):

```
## Goal
<what this achieves for the user — one sentence, outcome-focused>

## Plan
<summary of the approach from Phase 3>

## Sub-Issues
<!-- filled in after sub-issues are created -->
```

```bash
EPIC_URL=$(gh issue create \
  --title "feat: <feature name>" \
  --body "<epic body using the template above>" \
  --label ship)
EPIC_NUM=$(echo "$EPIC_URL" | grep -oE '[0-9]+$')
EPIC_ID=$(gh issue view "$EPIC_NUM" --json id -q .id)
```

Record `EPIC_NUM` and `EPIC_URL` in your notes — you will need the literal number in Step 4 and the Completion Report, where `$EPIC_NUM` from this block will no longer be in scope.

**Step 2: Create sub-issues**

One issue per atomic implementation unit. Each must be self-contained. Use this template:

```
## Goal
<what this achieves for the user — one sentence, outcome-focused>

## Task
<what specifically needs to be done — one atomic, independently shippable change>

## Context
<why this is needed; relevant file paths, patterns, or constraints from Phase 2>

## Acceptance Criteria
- [ ] <specific, verifiable criterion>
- [ ] <specific, verifiable criterion>

## Out of Scope
- <what we are explicitly NOT doing in this unit>

## Blocked by
<"none" or list of issue numbers this must wait for, e.g. "Blocked by #4, #5">

## Notes
<gotchas, patterns to follow, edge cases to watch for>
```

Create each sub-issue. Run this block once per unit, recording the resulting number/URL for each:

```bash
SUB_URL=$(gh issue create \
  --title "feat: <unit name>" \
  --body "<sub-issue body using the template above>" \
  --label ship)
SUB_NUM=$(echo "$SUB_URL" | grep -oE '[0-9]+$')
SUB_ID=$(gh issue view "$SUB_NUM" --json id -q .id)
```

Keep an ordered list of every sub-issue's number, URL, and node ID (`SUB_ID`) in your notes — Steps 3 and 4 and Phase 4 all need these literal values, and shell variables do not survive between command blocks.

**Step 3: Link sub-issues to the epic via GitHub's sub-issue API**

Run this once per sub-issue. Pass the node IDs as proper GraphQL variables (`-F` for typed/string variables) rather than interpolating them into the query string — string interpolation with escaped quotes is fragile and breaks on special characters. Substitute the actual node IDs you recorded:

```bash
gh api graphql \
  -F epicId="<EPIC_ID node id>" \
  -F subId="<this sub-issue's node id>" \
  -f query='
mutation($epicId: ID!, $subId: ID!) {
  addSubIssue(input: { issueId: $epicId, subIssueId: $subId }) {
    issue { number }
    subIssue { number }
  }
}'
```

This creates the parent→child hierarchy visible in GitHub's issue UI and project views. (`addSubIssue` requires the sub-issues feature; if your `gh`/API version rejects the mutation, fall back to listing the sub-issues in the epic body tasklist only — Step 4 still gives you a visible checklist.)

**Step 4: Update the epic body with the sub-issue tasklist**

Substitute the literal epic number and the real sub-issue numbers/titles you recorded:

```bash
gh issue edit <EPIC_NUM> --body "$(cat <<'EOF'
## Goal
<goal>

## Plan
<summary>

## Sub-Issues
- [ ] #<sub1> <title>
- [ ] #<sub2> <title>
- [ ] #<sub3> <title>
EOF
)"
```

Tell the user the epic URL and all sub-issue URLs, then mark the Plan task `completed` and proceed to Phase 4.

**Note on tasklist checkboxes:** Closing a sub-issue with `gh issue close` does *not* automatically tick its `- [ ]` checkbox in the epic body. GitHub does, however, render live open/closed status next to each referenced issue and rolls completion up in its sub-issue UI (from Step 3's linkage). If you want the literal checkboxes ticked too, the orchestrator must re-edit the epic body to change `- [ ]` to `- [x]` as each unit completes; otherwise rely on the sub-issue progress indicator and issue-status rendering, which update automatically.


## Phase 4: Implement

Mark the Implement task `in_progress`. Decompose the approved plan into **independent units**. The approved plan always yields at least one unit; if your decomposition somehow produces zero units, treat the whole plan as a single unit rather than spawning nothing. Execute using the strategy chosen in Phase 1:

- **Parallel subagents, shared workspace** *(recommended)*: spawn concurrent subagents using the `Agent` tool on the same working tree. Fastest path — use when units touch different files.
- **Let the agent decide**: review the plan now and pick the right strategy. Default to shared workspace; switch to isolated worktrees only if two or more units modify the same files incompatibly or a unit is a large isolated refactor that would create noisy partial state.
- **Isolated worktrees**: spawn agents using the `Agent` tool with `isolation: "worktree"`. Each agent works in its own git worktree. On the GitHub path, each agent opens its own PR with `gh pr create` (per the prompt below); on the non-GitHub path, agents commit in their worktree only and no PR is created unless the user asked for one.

**Dependency ordering is enforced by you, the orchestrator — not by the agents.** Spawned agents run concurrently and cannot observe or wait on one another, so an agent can never "wait until its blockers are closed." You sequence the work instead:

1. Build a dependency graph from the plan (or, if `SHIP_GH_ENABLED=true`, from each sub-issue's "Blocked by" field).
2. Group units into waves: wave 1 = units with no blockers; wave 2 = units whose blockers are all in wave 1; and so on.
3. Dispatch every unit in the current wave in parallel. **Wait for all agents in the wave to return before dispatching the next wave.** Never instruct an agent to self-wait.
4. Repeat until all waves are done. A single-unit task is simply one wave with one agent.

**Non-GitHub path (`SHIP_GH_ENABLED=false`):** there are no issues or PRs, so there is no "Blocked by" field to read — derive the dependency graph and wave grouping directly from the implementation order in the approved Phase 3 plan. Spawn one agent per unit, wave by wave as above, with a self-contained prompt derived directly from the approved plan. Because there is no issue to read, each agent's prompt must contain the unit's goal, the specific change to make, relevant context and file paths from Phase 2, and its acceptance criteria inline. Agents implement and commit their changes only; they do not open PRs or touch any issue. Skip the issue/PR instructions below.

**GitHub path (`SHIP_GH_ENABLED=true`):** each agent's prompt must include its assigned issue URL (the sub-issue, or for a single-unit task the one issue created in Phase 3). How PR creation is handled depends on the implementation strategy, because all shared-workspace agents commit to the *same* branch and GitHub allows only one open PR per head→base branch pair — so per-agent `gh pr create` only works when each agent has its own branch (isolated worktrees).

**Isolated worktrees** (each agent on its own branch) — the agent creates its own PR:

> "Your task is fully specified in this GitHub issue: `<issue URL>`. Read the Goal, Task, Context, Acceptance Criteria, and Notes before writing any code. (Your orchestrator has already confirmed that everything this unit depends on is complete — implement immediately; do not wait on other issues.) When all acceptance criteria are satisfied and your changes are committed, open a PR that closes the issue:
> ```
> gh pr create --title "feat: <unit name>" --body "Closes #<number>"
> ```
> Then close the issue: `gh issue close <number> --reason completed`"

In this case agents open their own PR and close their own issue on completion; do not defer this to the end of the pipeline.

**Shared workspace** (all agents on one branch — the recommended and "let the agent decide" default) — agents must NOT each run `gh pr create`, or every call after the first will fail on the duplicate head branch. Instead:

> "Your task is fully specified in this GitHub issue: `<issue URL>`. Read the Goal, Task, Context, Acceptance Criteria, and Notes before writing any code. (Your orchestrator has already confirmed that everything this unit depends on is complete — implement immediately; do not wait on other issues.) When all acceptance criteria are satisfied and your changes are committed, do NOT open a pull request (the orchestrator will open one covering the whole branch). Close your issue: `gh issue close <number> --reason completed`"

Then, after all waves finish, you (the orchestrator) open a single PR for the shared branch that references every issue in scope, e.g. `gh pr create --title "feat: <feature name>" --body "Closes #<sub1>, closes #<sub2>, closes #<sub3>"` (use the literal sub-issue numbers you recorded; for a single-unit task, just that one issue's number). The agents already closed those issues directly in the prompt above, so the `Closes #` references here primarily link the PR to them for traceability (and will harmlessly no-op on issues that are already closed).

Wait for all units across all waves to complete before moving to quality gates. Mark the Implement task `completed`.


## Phase 5: Verify

Mark the Verify task `in_progress`. Spawn an autonomous `Agent` with the following goal condition (adapt to the specific task). Instruct it to iterate — running tests, fixing failures, re-checking criteria — until everything passes, then return its result:

```
All acceptance criteria from Phase 1 are met. All existing tests pass. No linting errors or type errors. The feature works end-to-end including edge cases defined during Phase 1.
```

**Loop bound (prevents an infinite fix/re-run cycle):** instruct the agent to make at most a bounded number of fix attempts — roughly 5 iterations, or fewer if it makes no measurable progress (the same test fails the same way twice in a row, or the failure count stops dropping). If it exhausts that budget without meeting the goal, it must stop and return a clear report of what still fails and why, rather than looping indefinitely. When the agent returns unmet, do not silently advance: surface the blocking failures to the user and get direction (fix manually, relax a criterion, or abort) before continuing.

If the repository has no test suite at all, "all existing tests pass" is vacuously satisfied — do not invent or scaffold a test framework here just to have something to run; verify the acceptance criteria by running the feature directly (the optional Phase 6/7 gates are where new tests get added). If linting or type-checking is also absent, skip those checks rather than treating their absence as a failure.

If spawning an agent is not suitable, invoke the `verify` skill using the `Skill` tool. Pass the acceptance criteria and changed files as args so the skill knows what to check: `Skill({ skill: "verify", args: "<acceptance criteria + changed files>" })`.

Do not proceed until every criterion passes (or the user explicitly accepts an unmet criterion per the loop-bound guidance above). Mark the Verify task `completed`.


## Phase 6: Edge Cases

*Skip if edge cases were opted out in Phase 1, or if the `edge-cases` skill is unavailable (declined or failed install in Phase 1). When skipping, do nothing here — there is no "Edge cases" task if it was opted out, and if the task exists (opted in but skill missing) leave it as-is — and move on to Phase 7.*

Mark the Edge cases task `in_progress`. Invoke the `edge-cases` skill using the `Skill` tool, passing the feature area and changed files as args:

```
Skill({ skill: "edge-cases", args: "<feature area or changed files>" })
```

This runs 8 parallel subagents to enumerate edge cases across boundary values, null inputs, invalid types, error states, concurrency, adversarial data, state machine violations, and auth boundaries. It then writes tests for every unhandled P0/P1 case, confirms each test fails before the fix and passes after, and verifies no regressions.

Do not proceed until all P0 and P1 edge cases are covered and the full test suite passes. Mark the Edge cases task `completed`.


## Phase 7: E2E Tests

*Skip if E2E tests were opted out in Phase 1, or if the `e2e` skill is unavailable (declined or failed install in Phase 1). When skipping, do nothing here — there is no "E2E tests" task if it was opted out, and if the task exists (opted in but skill missing) leave it as-is — and move on to Phase 8.*

Mark the E2E tests task `in_progress`. Invoke the `e2e` skill using the `Skill` tool, passing the feature area and flows as args:

```
Skill({ skill: "e2e", args: "<feature or flow to cover>" })
```

This discovers user flows, sets up Playwright (web) or Maestro (mobile) if needed, writes golden-path and critical edge-case tests, runs them, and fixes any failures. All tests must pass before proceeding. Mark the E2E tests task `completed`.


## Phase 8: Simplify

Mark the Simplify task `in_progress`. Spawn an autonomous `Agent` with the following goal condition. Instruct it to iterate — removing dead code, flattening unnecessary abstractions, simplifying logic — until the condition is met, then return:

```
All code added or modified for this task is as simple as possible. No unnecessary abstractions, dead code, over-engineered patterns, or speculative generality. Every line serves a concrete current requirement. All existing tests still pass.
```

**Loop bound (prevents an infinite simplify/re-test cycle):** instruct the agent to make at most a bounded number of simplification passes — roughly 5 iterations, or fewer once each new pass yields no further safe simplification. Correctness always wins over simplicity: if a simplification breaks a test, the agent reverts that specific change rather than continuing to chase it. If after a pass the tests cannot be made to pass again, the agent must revert to the last green state and return a report of what it could not safely simplify — it must never leave the tree with failing tests, and must never loop indefinitely trying to make a broken simplification work. Treat "all existing tests still pass" as a hard gate: the phase ends in a state where they do, even if that means accepting less simplification.

Mark the Simplify task `completed` only once the tree is green and the agent has returned.


## Phase 9: Security Review

Mark the Security review task `in_progress`. Invoke the `security-review` skill using the `Skill` tool. The skill audits the pending changes on the current branch on its own, so args are optional — but pass the feature area and the changed files so it can prioritize the code this task actually touched:

```
Skill({ skill: "security-review", args: "<feature area + changed files from this task>" })
```

If the `security-review` skill is unavailable, spawn an autonomous `Agent` with this goal condition (scope it to the files changed in this task):

```
All changes have been audited for: (1) input validation at system boundaries; (2) authentication and authorization on new endpoints; (3) no injection vulnerabilities (SQL, XSS, command injection, path traversal); (4) no hardcoded secrets or tokens; (5) intentional and documented trust boundary crossings. All HIGH and CRITICAL findings are fixed.
```

**Loop bound (fallback agent only):** if a HIGH/CRITICAL finding cannot be safely fixed within roughly 5 attempts, the agent stops and returns the unresolved finding with its analysis rather than looping — surface it to the user for a decision before continuing.

Document any accepted LOW or MEDIUM findings with explicit rationale before proceeding. Mark the Security review task `completed`.


## Phase 10: Final Verify

Mark the Final verify task `in_progress`. Run the verification exactly the way you ran it in Phase 5 — using the same mechanism you chose there: if Phase 5 used an autonomous `Agent`, spawn a fresh `Agent` here with the goal condition below (and the same loop bound as Phase 5); if Phase 5 used the `verify` skill, invoke it again here with `Skill({ skill: "verify", args: "<acceptance criteria + all files changed across Phases 4–9>" })`. Either way the goal is to confirm the codebase is shippable after hardening, simplification, and security fixes:

1. All original acceptance criteria still pass
2. No regressions from Phase 6 (edge cases), if it ran
3. No regressions from Phase 7 (E2E tests), if it ran
4. No regressions from Phase 8 (simplify)
5. No regressions from Phase 9 (security)
6. Application is in a clean, deployable state

If verification comes back unmet, handle it the same way as Phase 5 (surface the blocking failures to the user and get direction before declaring the work shippable). Mark the Final verify task `completed`.


## Completion Report

Report the following regardless of which path was taken. Omit the line for any phase that did not run — whether it was opted out or skipped because its skill was unavailable (e.g. drop the edge-cases line if Phase 6 was skipped for either reason):

- What was implemented and which files changed
- Edge cases found and hardened (count by priority tier)
- E2E tests written (golden path + edge cases, if opted in)
- Test coverage added or modified
- Security findings and their resolutions
- Any open limitations or recommended follow-up tasks

**If `SHIP_GH_ENABLED=false`**, also include the PR/branch state if you created one; there is no issue bookkeeping to do, so the report is complete at this point.

**If `SHIP_GH_ENABLED=true`**, additionally include the issue URLs (the epic and every sub-issue; for a single-unit task, just the one issue created in Phase 3 — there is no epic) **and the PR URL(s)** in the report — the single combined PR the orchestrator opened in Phase 4 (shared-workspace / "let the agent decide" paths) or each agent's PR (isolated-worktrees path). Then verify all sub-issues are closed and the epic reflects completion. Use the literal issue numbers you recorded in your notes — the `$EPIC_NUM`/`$SUB_ID` shell variables from Phase 3 are no longer in scope here.

First, check that every sub-issue you created is closed. Listing by label is not enough — the epic itself also carries the `ship` label, so it would appear in the results. Check each sub-issue you recorded explicitly:

```bash
# Replace with the actual sub-issue numbers you recorded in Phase 3.
for n in <sub1> <sub2> <sub3>; do
  printf '#%s: ' "$n"
  gh issue view "$n" --json state -q .state
done
```

Any sub-issue still open here means its agent did not close it (the agent closes its own issue on completion, per Phase 4) — so the work likely did not finish. Close it with a brief note explaining why it was left incomplete:

```bash
gh issue close <number> --comment "<reason this unit was not completed>" --reason "not planned"
```

Once all sub-issues are closed (single-unit tasks have only that one issue and no epic — stop here), close the epic using its recorded number:

```bash
gh issue close <EPIC_NUM> --reason completed
```
