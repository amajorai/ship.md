# Agent Prompt Templates for Phase 4

## Isolated worktrees (each agent on its own branch — opens its own PR)

> "Your task is fully specified in this GitHub issue: `<issue URL>`. Read the Goal, Task, Context, Acceptance Criteria, and Notes before writing any code. (Your orchestrator has already confirmed that everything this unit depends on is complete — implement immediately; do not wait on other issues.) When all acceptance criteria are satisfied and your changes are committed, open a PR that closes the issue:
> ```
> gh pr create --title "feat: <unit name>" --body "Closes #<number>"
> ```
> Then close the issue: `gh issue close <number> --reason completed`"

## Shared workspace (all agents on one branch — orchestrator opens one PR)

> "Your task is fully specified in this GitHub issue: `<issue URL>`. Read the Goal, Task, Context, Acceptance Criteria, and Notes before writing any code. (Your orchestrator has already confirmed that everything this unit depends on is complete — implement immediately; do not wait on other issues.) When all acceptance criteria are satisfied and your changes are committed, do NOT open a pull request (the orchestrator will open one covering the whole branch). Close your issue: `gh issue close <number> --reason completed`"

After all shared-workspace waves finish, the orchestrator opens a single PR referencing every issue:

```bash
gh pr create --title "feat: <feature name>" --body "Closes #<sub1>, closes #<sub2>, closes #<sub3>"
```

## Non-GitHub path

Each agent's prompt must contain the unit's goal, the specific change to make, relevant context and file paths from Phase 2, and acceptance criteria inline. Agents implement and commit only — no PRs, no issue management.

## Dependency ordering reminder

Spawned agents run concurrently and cannot observe each other. You (the orchestrator) enforce ordering by:

1. Building a dependency graph from the plan (or sub-issue "Blocked by" fields).
2. Grouping units into waves: wave 1 = no blockers, wave 2 = blocked only by wave 1, etc.
3. Dispatching all units in the current wave in parallel, waiting for all to return, then dispatching the next wave.
