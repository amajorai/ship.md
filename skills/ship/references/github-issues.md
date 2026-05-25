# GitHub Issue Creation

## Single-unit shortcut

If the plan is a single atomic unit, skip the epic hierarchy. Create one issue using the sub-issue template below (its "Blocked by" = "none"), record its number/URL, tell the user, and proceed. Skip Steps 1, 3, and 4 entirely.

---

## Step 1: Create the parent epic issue

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
  --label "<SHIP_LABEL>" \
  --label "📋 plan")
EPIC_NUM=$(echo "$EPIC_URL" | grep -oE '[0-9]+$')
EPIC_ID=$(gh issue view "$EPIC_NUM" --json id -q .id)
```

Record `EPIC_NUM`, `EPIC_URL`, and `EPIC_ID` in your notes — shell variables don't survive between command blocks.

## Step 2: Create sub-issues (one per atomic unit)

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

```bash
SUB_URL=$(gh issue create \
  --title "feat: <unit name>" \
  --body "<sub-issue body using the template above>" \
  --label "<SHIP_LABEL>")
SUB_NUM=$(echo "$SUB_URL" | grep -oE '[0-9]+$')
SUB_ID=$(gh issue view "$SUB_NUM" --json id -q .id)
```

Keep an ordered list of every sub-issue's number, URL, and node ID in your notes.

## Step 3: Link sub-issues to the epic

Run once per sub-issue. Pass node IDs as typed GraphQL variables:

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

If `addSubIssue` is rejected, fall back to listing sub-issues in the epic body tasklist (Step 4 still gives a visible checklist).

## Step 4: Update the epic body with the sub-issue tasklist

Substitute the literal epic number and real sub-issue numbers/titles:

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

Tell the user the epic URL and all sub-issue URLs.

## Phase label transitions

Transition labels on the epic as phases progress:

```bash
# Entering a phase:
gh issue edit <EPIC_NUM> --add-label "<phase-label>" --remove-label "<previous-label>"
# Exiting a phase:
gh issue edit <EPIC_NUM> --remove-label "<phase-label>"
```

Phase labels: `🔍 explore`, `📋 plan`, `🔨 implement`, `✅ verify`, `🔍 edge cases`, `🧪 e2e`, `✂️ simplify`, `🔒 security`

## Closing at completion

Check each sub-issue explicitly by number (not by label — the epic also carries the ship label):

```bash
for n in <sub1> <sub2> <sub3>; do
  printf '#%s: ' "$n"
  gh issue view "$n" --json state -q .state
done
```

Close any still open:

```bash
gh issue close <number> --comment "<reason this unit was not completed>" --reason "not planned"
```

Then close the epic:

```bash
gh issue close <EPIC_NUM> --reason completed
```
