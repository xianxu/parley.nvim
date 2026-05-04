---
type: type
name: roadmap
description: Use when planning one product's work for a target month — capacity, scope decisions, target state per component. Lives at data/roadmap/YYYYMM/<product>.md. Triggers on "let's roadmap <product> for <month>", "plan <product> for end of <month>", "/xx-datatype roadmap".
---

# roadmap

A roadmap is the *plan* for one product across one month. It states what we want to be true at end of that month, the capacity available, and the scope decisions forced by the gap between desired work and available capacity. The roadmap is the artifact of the planning act itself — the cost-vs-capacity tradeoff happens in the open.

A roadmap is forward-looking. It is not a snapshot of where we are now (that lives in the product file's per-component `**State:**` line) and not a changelog (git diff between adjacent roadmaps shows the trajectory).

A roadmap is per-product. The proto-company view is the *aggregate* of `data/roadmap/YYYYMM/*.md` — multiple per-product files in one month directory. Cross-product dependencies are expressed by `` `other-product:slug` `` references in component prose, not by combined docs.

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `roadmap` |
| `product` | yes | The product slug. Must reference an existing `data/product/<product>.md`. |
| `month` | yes | `YYYYMM`. Target end-of-period. |
| `target_event` | optional | Free-form short tag if this month is gated to a specific external event (e.g., `external launch`, `investor meeting`). |
| `created` | yes | ISO date. |
| `updated` | yes | ISO date of the last edit. |
| `sources` | optional | Lineage — files, parley chat IDs, URLs the agent read when authoring. |

## Body skeleton

An instance of `roadmap` has, in order:

1. `# <product> — <month>` — title (e.g., `# ariadne — 202610`).
2. `**Target:** <one sentence describing the desired end-of-month state, often event-anchored>` — the target line.
3. `## plan` — capacity, scope, reasoning. See *Plan section* below.
4. `## components` — per-component target state and effort. See *Component section* below. Only components being touched this month appear.
5. `## postmortem` — added after the month concludes. See *Postmortem section* below.

### Plan section

`## plan` body, in order:

- `**Capacity:** <free-form, normalized to dev-weeks where possible>` — e.g., `~3 dev-weeks (1 founder × 3 weeks)`. If the previous roadmap of this product is non-adjacent (e.g., last roadmap was 202608, this one is 202610), state the actual horizon: `~6 dev-weeks total, covering 202609–202610`.
- `**In scope:**` followed by a priority-ordered bulleted list of work items. Top of the list is highest priority.
- `**Out of scope:**` followed by a priority-ordered bulleted list. The boundary between in and out is the capacity boundary — items just below the cut are the first to pull in if capacity expands; items just above are the first to drop if capacity shrinks.
- `**Reasoning:**` followed by a paragraph explaining why these scope decisions were made — what was forced, what's gated, what to revisit.

### Component section

Each component being touched this month appears as `### <slug>`, where the slug matches a `### <slug>` in the corresponding product file.

- `**Target state:** <what this component should look like at end of month>`
- `**Effort:** <free-form estimate>` — e.g., `~2 weeks`, `medium`, `unknown`.
- Free prose body — gap from current state to target, plan, blockers, dependencies. Cross-product dependencies as `` `product:slug` ``.

Components NOT being touched this month do NOT appear. Their current state lives in the product file's `**State:**` line and is unchanged by this roadmap's authoring.

### Postmortem section

Empty placeholder (`*(added after month concludes)*`) until the month is over. Once added: free-form prose covering what shipped vs in-scope, what slipped, what surprised (cost overruns, unexpected wins, mid-month scope changes), what to change for the next planning cycle. No required subsections.

## Authoring instructions

When the dispatcher applies this prototype:

1. **Resolve `product` and `month` first.**
   - `product` — must reference an existing `data/product/<product>.md`. If that file doesn't exist, ask the user — usually the answer is "create the product first, then come back."
   - `month` — `YYYYMM`. Default to current month if unstated.
   - Default location: `data/roadmap/<month>/<product>.md`.

2. **Check for prior roadmaps of this product.**
   - List `data/roadmap/*/<product>.md` to find the most recent prior roadmap.
   - If non-adjacent (gap of ≥1 month), the capacity statement must explicitly cover the gap.
   - If a prior roadmap exists, read its `## components` to understand what was in flight; pre-fill components that likely carry forward.

3. **Read the product file.** `data/product/<product>.md` lists the components and their current `**State:**`. Use this as the starting reference. Roadmap component slugs MUST exist in the product file.

4. **Distill the user's intent before asking.** Common signals:
   - "Plan ariadne for 202610" → product=ariadne, month=202610.
   - "Roadmap for the launch" → ask: which product? which month is the launch?
   - "Targeted at external launch" → set `target_event`.

5. **Required to gather before writing:**
   - **Target line** — one sentence. If not extractable, ask: "What's the target for this month?"
   - **Capacity** — explicit, normalized to dev-weeks when possible. Ask if not stated.
   - **In-scope / out-of-scope** — ask the user to enumerate work items in priority order; help them draw the cut at the capacity boundary. Out-of-scope items are *the bottom of the same list*, not a separate concept.

6. **For each in-scope component:**
   - Confirm the slug exists in `data/product/<product>.md`. If it doesn't, ask whether to add the component to the product file first (the product is the canonical source of components).
   - Ask for **Target state** and **Effort**. Both are required.

7. **Postmortem starts empty.** A new roadmap creates an empty `## postmortem` section with the placeholder line. Don't write postmortem content for a future or current month.

8. **Updating an existing roadmap** is the common case — adding a component, revising effort, capturing scope changes. Edit in place; don't rewrite.

9. **Confirm before writing:** show destination path, target line, in-scope and out-of-scope lists. One round of confirmation.

## Search recipes

```sh
# All roadmaps
rg -l "^type: roadmap"

# All roadmaps for a product (across months)
ls data/roadmap/*/<product>.md 2>/dev/null

# All roadmaps in a month (proto-company view)
ls data/roadmap/202610/ 2>/dev/null

# All roadmaps gated to a specific event
rg -l "^type: roadmap" | xargs rg -l "^target_event: external launch"

# Capacity statements across all roadmaps in a month
rg "^\*\*Capacity:\*\*" data/roadmap/202610/

# Component-level target states for a specific component across months
rg -B1 -A1 "^### substrate-skill-management" data/roadmap/

# Trajectory for a component (changes across months via git)
git log -p --follow data/roadmap/*/<product>.md | rg -A 5 "^### substrate-skill-management"
```

## Rules

- One roadmap per (product, month) pair. The filename is `data/roadmap/<month>/<product>.md` and the frontmatter `product` + `month` must match the path.
- A roadmap targets one product. Cross-product dependencies are expressed by `` `other-product:slug` `` references in component prose, not by combined docs.
- Component slugs in the roadmap MUST exist as `### <slug>` sections in the corresponding product file. If a slug doesn't exist there yet, add it to the product file first.
- The roadmap is forward-looking. Current state of components lives in the product file's `**State:**` line. Don't duplicate.
- `**In scope:**` and `**Out of scope:**` lists are priority-ordered. The cut between them is the capacity boundary. Both lists together = the full priority-ordered backlog for the month.
- Postmortem content is added only after the month concludes. A future-month or current-month roadmap has the empty placeholder.
- Multi-month gaps are allowed. A roadmap's `**Capacity:**` line must cover the actual horizon since the previous roadmap.
