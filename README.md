# 📦 ship.md

A thin, structured workflow for shipping features with Claude Code. Not a full-blown framework like [GSD](https://github.com/gsd-build/get-shit-done) or [bmad-method](https://github.com/bmad-method/bmad-method). Just a wrapper around Claude Code's own built-in commands (`/batch`, `/goal`, `/model`, `/security-review`) that adds structure, quality gates, and optional GitHub issue tracking so nothing falls through the cracks.

Simple, minimal, lean. One interview, one plan, ship the thing.

```mermaid
flowchart TD
    subgraph sf["⚡ /ship-fast"]
        A["🎤 Interview (Sonnet)\nSurface requirements + quality gates"] --> B["🔍 Explore (Sonnet)\n3-5 parallel subagents map the codebase"]
        B --> C["🧠 Plan (Opus)\n/model opusplan"]
        C --> D["⚡ Implement (Sonnet)\n/batch: parallel isolated worktrees"]
        D --> E["✅ Verify (Sonnet)\n/goal: all acceptance criteria must pass"]
    end
    E --> H["✂️ Simplify (Sonnet)\n/goal: no dead code or over-engineering"]
    E -.-> F["🧪 Edge Cases (Sonnet)\n8 parallel subagents across boundary categories"]
    F -.-> G["🌐 E2E Tests (Sonnet)\nPlaywright or Maestro: golden path + edge cases"]
    G -.-> H
    H --> I["🔒 Security Review (Sonnet)\n/security-review: HIGH/CRITICAL fixed"]
    I --> J["🏁 Final Verify (Sonnet)\n/goal: clean deployable state confirmed"]
```

## Works great with

- 🪅 **[vibe.md](https://github.com/amajorai/vibe.md)** to spin up your production server, deploy pipeline, and scaffold your project before you start shipping.
- 🌈 **[rainbow.md](https://github.com/amajorai/rainbow.md)** to run ship.md autonomously 24/7. Drop issues into a GitHub Projects board; rainbow.md picks them up and delegates building to `/ship` automatically.

## Skills

| Skill | What it does |
|-------|-------------|
| [`/ship`](skills/ship/SKILL.md) | Full 10-phase pipeline: interview, explore, plan, implement, verify, edge cases, e2e tests, simplify, security review, final verify. Optionally creates atomic GitHub issues per unit (asked during interview) |
| [`/ship-fast`](skills/ship-fast/SKILL.md) | Lightweight 5-phase flow for simple features. Skips security review, edge cases, and simplification |

## GitHub issue tracking

`/ship` can create and manage GitHub issues throughout the pipeline. Opt in during the interview. When enabled:

**Labels** are auto-created on your repo for each phase so you can filter issues in GitHub's UI:

| Label | Phase |
|-------|-------|
| `📦 ship` | Parent epic |
| `📋 plan` | Planning in progress |
| `🔨 implement` | Implementation in progress |
| `✅ verify` | Verification in progress |
| `🔍 edge cases` | Edge case hardening |
| `🧪 e2e` | E2E test writing |
| `✂️ simplify` | Simplification pass |
| `🔒 security` | Security review |

**Issues** are structured with goal, task, context, acceptance criteria, and explicit "out of scope" sections. The phase label on the epic updates live as the pipeline progresses so you can watch the work move through stages in GitHub.

**Epic + sub-issues** are linked via GitHub's sub-issue API so the hierarchy shows up in project views. Each sub-issue is self-contained enough that a single agent can pick it up and close it independently.

**PRs** are created and linked to their issues (`Closes #N`) at the end of Phase 4. On the shared-workspace path (recommended), one PR covers the full branch. On isolated worktrees, each unit gets its own PR.

**Closing** is automatic: each implementing agent closes its own sub-issue on completion; the orchestrator closes the epic at the end of the pipeline.

## Built-in commands used

`/ship` orchestrates these Claude Code built-ins:

- `/model opusplan`: Opus for planning, auto-switches to Sonnet for execution
- `/batch`: parallel implementation across isolated git worktrees
- `/goal` behavior: verify, simplify, and final verify phases replicate `/goal`'s external-evaluator loop — one agent pass per iteration, the orchestrator evaluates the result (the role Haiku plays in `/goal`), and spawns another pass with failure context if unmet. `/goal` can't be invoked programmatically from within a skill, so this is the equivalent.
- `/security-review`: built-in security audit
- `/edge-cases`: from [amajorai/skills](https://github.com/amajorai/skills) (Phase 6, optional)
- `/e2e`: from [amajorai/skills](https://github.com/amajorai/skills) (Phase 7, optional)
- **Task tools** (`TaskCreate`, `TaskUpdate`): creates a task per phase after the interview so you can watch live progress in Claude Code's task UI

## Quickstart

```bash
npx skills add amajorai/ship.md
```

Then in Claude Code:

```
/ship add dark mode to the settings page
```

or for something quick:

```
/ship-fast fix the typo in the onboarding copy
```

### Auto-Update

Auto-update is **disabled by default**. Skills do not self-update unless you explicitly opt in (supply chain hygiene). To enable, pass `--update` to your command or set `SKILLS_AUTO_UPDATE: true` in your project CLAUDE.md.

`/ship` also checks whether its optional dependencies (`/edge-cases` and `/e2e`) are installed and offers to fetch them from [amajorai/skills](https://github.com/amajorai/skills) if missing.

### Claude Code plugin

```
/plugin marketplace add amajorai/ship.md
/plugin install shipmd@amajorai
```

Invoke as `/shipmd:ship <task>` or `/shipmd:ship-fast <task>`.

Part of [amajorai/skills](https://github.com/amajorai/skills). For more skills check out the full collection.
