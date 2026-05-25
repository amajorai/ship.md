# GitHub Labels

## Check for existing plain `ship` label

```bash
gh label list --json name -q '.[] | select(.name == "ship") | .name'
```

If output is `ship`, ask the user: **"There's an existing `ship` label without the box emoji. Would you like to rename it to `📦 ship`?"**

- **Yes** → rename in place:
  ```bash
  gh label edit ship --name "📦 ship" --color "BFD4F2" --description "Tracked by the ship skill"
  ```
  Record `SHIP_LABEL=📦 ship` in your notes.
- **No** → keep `ship`. Record `SHIP_LABEL=ship` in your notes.

If no plain `ship` label found: record `SHIP_LABEL=📦 ship` in your notes.

## Create or update all ship labels

Idempotent — `--force` updates if they already exist. Substitute the literal `SHIP_LABEL` value into the first command.

```bash
gh label create "<SHIP_LABEL>"  --color "BFD4F2" --description "Tracked by the ship skill"   --force
gh label create "🔍 explore"    --color "E3F2FD" --description "ship: explore phase"          --force
gh label create "📋 plan"       --color "FFF3E0" --description "ship: plan phase"             --force
gh label create "🔨 implement"  --color "E8F5E9" --description "ship: implement phase"        --force
gh label create "✅ verify"     --color "F3E5F5" --description "ship: verify phase"           --force
gh label create "🔍 edge cases" --color "FBE9E7" --description "ship: edge-cases phase"       --force
gh label create "🧪 e2e"        --color "E0F7FA" --description "ship: e2e phase"              --force
gh label create "✂️ simplify"   --color "F9FBE7" --description "ship: simplify phase"         --force
gh label create "🔒 security"   --color "FCE4EC" --description "ship: security phase"         --force
```

No issues are created at this point — that happens in Phase 3 once work is decomposed into units.
