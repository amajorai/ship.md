# ship.md

The end-to-end skill for shipping features without gaps — 9 phases from interview to final verify. Wraps Claude Code's built-in `/batch`, `/goal`, and `/model` commands into a single quality-gated pipeline.

```
skills/
  ship/
    SKILL.md
  ship-simple/
    SKILL.md
.claude-plugin/
  plugin.json
  marketplace.json
install.sh
```

## Skills

| Skill | What it does |
|-------|-------------|
| [`/ship`](skills/ship/SKILL.md) | Full 9-phase pipeline: interview, explore, plan, implement, verify, edge cases, simplify, security review, final verify |
| [`/ship-simple`](skills/ship-simple/SKILL.md) | Streamlined 4-phase pipeline for tasks where requirements are already clear: explore, plan, implement, verify |

## Installation

### Claude Code plugin (recommended)

```
/plugin marketplace add amajorai/ship.md
/plugin install shipmd@amajorai
```

Invoke as `/shipmd:ship <task>` or `/shipmd:ship-simple <task>`.

### install.sh (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/amajorai/ship.md/main/install.sh | bash
```

```bash
# Codex
curl -fsSL https://raw.githubusercontent.com/amajorai/ship.md/main/install.sh | bash -s -- --codex
```

Or clone and run manually:

```bash
git clone https://github.com/amajorai/ship.md.git
cd ship.md

./install.sh           # Claude Code → ~/.claude/skills/  → /ship
./install.sh --codex   # Codex       → ~/.codex/skills/  → $ship
```

### Copy a single skill

```bash
# Claude Code
cp skills/ship/SKILL.md ~/.claude/skills/ship.md

# Codex
mkdir -p ~/.codex/skills/ship && cp skills/ship/SKILL.md ~/.codex/skills/ship/SKILL.md
```

## Built-in commands used

`/ship` orchestrates these Claude Code built-ins — no external dependencies needed:

- `/model claude-opus-4-7` — switches to the strongest model for planning
- `/batch` — parallel implementation across isolated git worktrees
- `/goal` — autonomous quality loops for verify, simplify, and security phases
- `security-review` skill — built-in security audit

---

Part of [amajorai/skills](https://github.com/amajorai/skills)
