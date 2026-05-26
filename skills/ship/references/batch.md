# Batch Reference

> This is the original Claude Code `/batch` skill prompt, reproduced verbatim below as Mode A. Mode B (shared workspace) is an extension added by ship.md for tasks where units share files.

Two modes depending on the strategy chosen in the Phase 1+2 loop.

---

## Mode A: Isolated Worktrees (one PR per unit)

Use when: the user chose isolated worktrees, or units have no shared files.

### Decompose into units

Break the plan into **5–30 self-contained units**. Each unit must:
- Be independently implementable in an isolated git worktree (no shared state with sibling units)
- Be mergeable on its own without depending on another unit's PR landing first
- Be roughly uniform in size (split large units, merge trivial ones)

Scale the count to actual work: few files → closer to 5; hundreds of files → closer to 30. Prefer per-directory or per-module slicing over arbitrary file lists.

### E2E recipe

Before spawning workers, determine how a worker can verify its change works end-to-end. Look for:
- A browser-automation tool (for UI changes: click through the affected flow, screenshot the result)
- A CLI verifier (for CLI changes: launch the app interactively, exercise the changed behavior)
- A dev-server + curl pattern (for API changes: start the server, hit the affected endpoints)
- An existing e2e/integration test suite the worker can run

If no concrete e2e path exists, ask the user. Offer 2–3 specific options based on what you found. Write the recipe as a short, concrete set of steps a worker can execute autonomously — include any setup (start dev server, build first) and the exact command/interaction to verify.

### Spawn workers

Launch one background agent per unit in a **single message block** so they run in parallel. Every agent must use `isolation: "worktree"` and `run_in_background: true`.

Each agent prompt must be fully self-contained and include:
- The overall goal
- This unit's specific task (title, file list, change description — verbatim from the plan)
- Codebase conventions discovered during Phase 2 (Explore)
- The e2e recipe (or "skip e2e because …")
- These worker instructions verbatim:

> 1. **Implement** the change described above.
> 2. **Code review** — invoke `Skill({ skill: "code-review" })` to find correctness bugs. Fix any findings before continuing.
> 3. **Unit tests** — run the project test suite (`bun test`, `npm test`, `pytest`, `go test`, etc.). Fix failures.
> 4. **E2E** — follow the e2e recipe from above. Skip only if the recipe says so.
> 5. **Commit and push** — commit with a clear message, push the branch, open a PR with `gh pr create`. Descriptive title.
> 6. **Report** — end with exactly: `PR: <url>` or `PR: none — <reason>`.

### Track progress

After launching, render a status table and update it as agents complete:

```
┌─────┬──────────────────────┬─────────┬─────┐
│  #  │ Unit                 │ Status  │ PR  │
├─────┼──────────────────────┼─────────┼─────┤
│ 1   │ <title>              │ running │ —   │
└─────┴──────────────────────┴─────────┴─────┘
```

Parse `PR: <url>` from each agent result. Re-render with `done` / `failed` and PR links. When all done, render final table and a one-line summary (e.g., "8/10 units landed as PRs").

---

## Mode B: Shared Workspace (one PR for everything)

Use when: the user chose shared workspace, or units share files/types that would cause merge conflicts in worktrees.

### Dependency waves

Group units into waves based on the dependency graph:
- **Wave 1** — no blockers (foundational types, schema, shared utilities)
- **Wave 2** — depends on wave 1 output
- **Wave N** — depends on wave N-1

Dispatch all units in the current wave in parallel (single message block, `run_in_background: true`, **no** `isolation: "worktree"`). Wait for all to return before dispatching the next wave. Never instruct an agent to self-wait.

### Spawn workers

Each agent prompt must include:
- The overall goal
- This unit's specific task (title, file list, change description — verbatim from the plan)
- Codebase conventions discovered during Phase 2 (Explore)
- Which wave this is and what the previous wave delivered (so it knows what it can import/use)
- These worker instructions verbatim:

> 1. **Implement** the change described above. Edit only the files listed for your unit — do not touch files owned by sibling units in this wave.
> 2. **Unit tests** — run the project test suite. Fix failures caused by your changes only.
> 3. **Commit** — commit with a clear message. Do not push or open a PR.
> 4. **Report** — end with: `DONE: <one-line summary of what changed>` or `FAILED: <reason>`.

### After all waves

Once all waves complete, one person (the coordinator, in-session) opens a single PR covering the full branch:

```bash
gh pr create --title "<overall feature title>" --body "<summary of all units>"
```
