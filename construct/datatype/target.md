---
type: type
name: target
description: Use when capturing the durable narrative intent behind a piece of work — what we want and what for, sitting above projects and issues in the dependency graph. Triggers on "create a target for X", "write a target file", "extract this problem section to a target", "/xx-datatype target". Distinct from project (execution container with done_when), product (durable charter), pensive (moment-in-time thought). Under-specified by design — let the substrate derive specifics.
---

# target

A target is the *intent layer* — durable narrative prose describing what the operator wants and what for. Distinct from execution containers (projects), durable charters (products), and moment-in-time thinking (pensives). A target gets referenced by one or more projects and issues that descend from it; the substrate of work flows down the dependency graph while the target itself stays slim.

Targets are deliberately under-specified. The discipline: **only get more specific when the agent fills the gap wrong.** A target that says "create a shared brain infrastructure and user interface" doesn't enumerate features; trust the projects and issues that descend from it to derive specifics, and only refine the target when a later read reveals that the agent's natural decomposition was wrong.

## Distinct from sibling datatypes

- `product` — durable *charter* ("what is being built"). A target is more narrative-driven and may not yet have a defined product behind it. Targets can crystallize into products as the shape firms up.
- `project` — *execution container* ("what we've decided to do, by when"). A project advances one or more targets via tracked tasks and a `done_when` criterion.
- `pensive` — captures a *moment of thought*. A target captures durable *commitment*, refined across many sessions. Pensives can promote to targets when the operator's intent crystallizes.
- `issue` — leaf *work unit*. Small issues embed their target inline as `## Problem`. Larger initiatives extract that section into a standalone target file and reference it via `target: <slug>` frontmatter.

In short: **target describes what we still want and what for; project describes the execution flowing from it; issue describes a unit of work that advances it.**

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `target` |
| `slug` | yes | Lowercase-hyphenated. Matches the filename without `.md`. |
| `status` | yes | `active` \| `achieved` \| `split` \| `deferred` \| `abandoned`. See *Lifecycle* below. |
| `created` | yes | ISO date the target was first written. |
| `updated` | yes | ISO date of the last edit. |
| `supersedes` | optional | Slug of a prior target this one supersedes (when intent shifted enough that the old framing is no longer right). |
| `superseded_by` | optional | Slug of a successor target (set when `status: split` or when superseding via a fresh framing). |
| `sources` | optional | Lineage — parley chat ids, pensives, prior conversations that crystallized into this target. List of strings. |

Notably *absent* (relative to `project`): `done_when`, `operator`, `mvp_scope`, `explicitly_out`. Targets are narrative. If you need an MVP boundary or operator assignment, you're writing a project, not a target.

## Body skeleton

An instance of `target` has, in order:

1. `# Target: <title>` — first line of the file. Title is what shows up when someone greps for `^# Target:`.
2. **Lede** — 1-3 paragraphs of "what we want and what for." The *what for* gets most of the words. This is the durable centerpiece; the rest is supporting.
3. `## Why now` — 1-2 paragraphs of motivation. What's making this matter at this moment? What changed that surfaced this target?
4. `## What this is NOT` — under-specification by negation. Narrows the intent space *without* enumerating sub-features. Examples: "not a rewrite of X," "not solving Y," "scope stops at Z." The conversation about what's *out* is more useful than the in-list, same as it is for projects.
5. `## Open questions` — intent-level uncertainties the operator is explicitly *not* committing on yet. Distinguished from project's task list (those are execution todos); these are commitments-not-yet-made. Live indefinitely; close out when the operator commits one way or the other (delete the question, fold the answer into the lede).

Optional later additions:

- `## Children` — list of slugs that descended from this target via `split`. Only present when status is `split`.
- `## Revisions` — when intent shifts mid-stream (the lede gets meaningfully edited), append a timestamped revision note. Same posture as `workshop/plans/*` revisions per `AGENTS.md` §1.

## Lifecycle

Targets transition on *intent* boundaries, not execution states:

- `active` — current commitment.
- `achieved` — the world now looks the way the target wanted. The descendant projects/issues closed and the cumulative result matches the intent.
- `split` — single target broke into two or more separable commitments. Each gets its own file with `supersedes: <original-slug>`; original gets `status: split` and a `## Children` list. Git history preserves the lineage.
- `deferred` — still want it, eventually. Not now. Distinguished from `abandoned` by the operator's belief that it'll come back.
- `abandoned` — no longer want it. Kept for context; doesn't get deleted. The narrative remains useful for "why we *didn't* do this."

`split` is the interesting one. A target getting split as understanding evolves is the natural way to honor "scope-shift-friendly." Use it.

## Agent ↔ human inline-marker convention

Targets are human-centric documents — the operator must fully understand and own the content. Agent contributions go in via inline `🤖{...}` / `🤖~X~` / `🤖<X>[H]` markers, never as direct edits to the operator's prose. The full grammar (markers, combinations, `Alt+q` / `Alt+a` / `Alt+r` resolution semantics, agentic resolution flow) is specified in [`workshop/targets/review-convention.md`](../../workshop/targets/review-convention.md). Direct overwrites of operator prose are a discipline failure.

## Authoring instructions

When the dispatcher applies this prototype:

1. **Distill before asking.** Pull target slug, candidate lede, and motivating context from recent conversation. Pre-fill what's clear; ask only for what's missing.

2. **Required fields the dispatcher must resolve before writing:**
   - `slug` (kebab-case) — usually obvious from "target for X" or the conversation topic. Confirm if it's not unambiguous.
   - Lede — distill 1-3 paragraphs from conversation. *What for* gets most of the words.

3. **Force the under-specification discipline.** Resist the PRD-shaped instinct to enumerate sub-features. If the operator starts listing features, redirect: those belong in projects/issues that descend from this target. The target itself stays narrative.

4. **Default to including `## What this is NOT`.** Even one bullet is useful. The negation is what makes the target a durable commitment instead of a wishlist.

5. **Default location:** `workshop/targets/<slug>.md` in the relevant project's repo (the repo where the descendant work will primarily live). For cross-repo targets that span multiple peer repos, pick the home repo by where the *primary* operator-attention will sit.

6. **Backfill references.** If existing issues or projects are clearly advancing this target, propose adding `target: <slug>` frontmatter to them.

7. **Updates preserve everything.** Common edits: refining the lede, adding to `## Open questions`, resolving an open question into the lede, appending to `## Revisions` on a meaningful shift. Direct edits to operator prose without `🤖{}` wrappers if the agent is making them are a discipline failure — push for the convention.

8. **Confirm before writing** a new target file: show destination path, lede paragraph(s), the `## What this is NOT` bullets, and any open questions. One round of confirmation. After confirmation, write; subsequent refinement is in-place edits.

## Search recipes

```sh
# All targets
rg -l "^type: target" workshop/targets/

# Active targets
rg -l "^type: target" workshop/targets/ | xargs rg -l "^status: active"

# Targets that have been split (history-worth)
rg -l "^type: target" workshop/targets/ | xargs rg -l "^status: split"

# Issues + projects that reference a given target
rg "^target: <slug>" workshop/

# Lede paragraphs for all active targets (skim across)
rg -A5 "^# Target:" $(rg -l "^status: active" workshop/targets/)

# Open questions across all targets (operator review session)
rg -A20 "^## Open questions" workshop/targets/

# Targets that supersede or are superseded — the intent-evolution chain
rg "^supersedes:\|^superseded_by:" workshop/targets/
```

## Rules

- One target per file. Slug, filename, and `slug:` field must agree.
- Targets live in `workshop/targets/` in the repo where the descendant work primarily happens. Cross-repo targets pick the *primary attention* repo as home.
- A target is narrative. If you need a `done_when` criterion, you're writing a project, not a target.
- Under-specify by design. Only get more specific when the agent fills the gap wrong. PRD-shaped feature enumeration is a smell.
- `## What this is NOT` is the load-bearing structure. The negation makes the commitment durable.
- Agent edits to the operator's prose go via `🤖{...}` inline markers. Direct overwrites are a convention violation.
- A target that splits keeps the original file with `status: split` and a `## Children` list; the original's narrative remains a useful read-from for the successors.
- Issues and projects reference targets via `target: <slug>` frontmatter. Multiple issues/projects can reference the same target; that's the dependency graph the datatype is designed to express.
- A target's relationship to its descendant work is *one-way reference*: targets don't track their descendants in body (other than the `## Children` list on split). Grep for `target: <slug>` to find descendants — the index is the file system, not duplicated in the target itself.
