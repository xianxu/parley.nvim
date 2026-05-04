---
type: type
name: project
description: Use when starting an execution container — a focused push of work toward a defined MVP, cutting across issues and possibly across products. Triggers on "let's start a project for X", "set up a project file for the launch push", "create a project to track this", "/xx-datatype project". Distinct from product (durable charter) and roadmap (month-level aggregate). One operator per project.
---

# project

A project is the *execution container* — what we've decided to do for a defined purpose, with an explicit MVP boundary, sequenced top-down. Operator-POV; cuts across issues, products, and repos.

A project is forward-looking and time-bounded — it has a `done_when` criterion. When the criterion is met, status flips to `done` and the file becomes a record. When the criterion stops being worth pursuing, status flips to `dropped` (also archival).

Distinct from sibling datatypes:

- `product` — the durable charter ("what is being built"). Static. A project advances one or more products.
- `roadmap` — month-level aggregate ("what we want true by month T"). A project lives inside a roadmap month.

A project is where the velocity calibration loop closes: each completed task records `actual_hours`, which propagates to the issue's frontmatter and to the velocity-skill validation table.

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `project` |
| `name` | yes | Slug form, lowercase-hyphenated. Matches the filename without `.md`. |
| `goal` | yes | One sentence. Why this project exists. |
| `done_when` | yes | The MVP boundary as a falsifiable criterion. *"What would make me say this project is finished?"* |
| `status` | yes | `active` \| `paused` \| `done` \| `dropped`. |
| `operator` | optional | Persona / name of the single human running this project. Default = self. **Exactly one** — see Single-operator discipline below. |
| `mvp_scope` | optional | List of issue refs (`[<repo>#<id>, ...]`) declared in MVP at project start. Anchors what counts as "done." |
| `explicitly_out` | optional | List of issue refs deliberately excluded from MVP. The conversation about what's *out* is more useful than the in-list — record it here. |
| `created` | yes | ISO date. |
| `updated` | yes | ISO date of the last edit. |
| `sources` | optional | Lineage — files, parley chat IDs, URLs the agent read when authoring. |

## Body skeleton

An instance of `project` has, in order:

1. `# <name>` — title matching the slug.
2. **Lede paragraph** — one short paragraph. **Explicitly call out the headline omission** (what's NOT in MVP) — that's the discipline this datatype enforces.
3. `## tasks` — a single ordered list, top-down execution. See *Task line format* below.
4. `## details` (optional) — per-task detail blocks for tasks with state worth recording. See *Per-task details*.
5. *Reference definitions at end of file* — see *Jump-link convention*. One line per task that has a detail block.

### Task line format

Keep one line per task short — **title + ref only**. Nothing else. No inline est, no inline status, no inline blocking reason. Those live in `## details`.

```markdown
- [ ] provider interface skeleton [charon#13 M1]
- [.] OpenAI provider impl [charon#13 M2]
- [ ] Anthropic mirror [charon#13 M3]
- [x] initial provider design sketch [charon#13 sketch]
- [ ] write release notes
```

#### Checkbox states

- `[ ]` — open / not started
- `[x]` — done
- `[.]` — blocked (reason in detail block)
- `[-]` — cancelled / removed from scope mid-project

#### Reference syntax

- `[<repo>#<id>]` — issue in any repo with an issue tracker. Product repos (`charon`, `ariadne`, etc.) and shared brain repos (`brain-team`, `brain-family`, etc.) work uniformly.
- `[<repo>#<id> M<N>]` — milestone-level granularity within an issue.
- Plain text — for items that don't fit any issue tracker (e.g., `write release notes`, `email investors`).

The ordered list is the execution order. Top to bottom. The first `[ ]` task is "what I'm working on next." When something is `[.]` blocked, skip it and pick the next `[ ]`; the blocking detail explains why.

### Per-task details

Optional. A task earns a detail block when it has state worth recording: estimate, started/closed dates, actual hours, blocking reason, prose notes. Open-not-started tasks with no notes need no detail block.

Detail block format:

```markdown
<a id="charon-13-m2"></a>
### charon#13 M2 — OpenAI provider impl

**est:** 10–16h
**status:** blocked — need OpenAI Admin API access verified before mint testing
**started:** 2026-04-30

(free prose — design notes, partial progress, decisions made during work)
```

When closed:

```markdown
<a id="charon-13-sketch"></a>
### charon#13 sketch — initial provider design

**est:** ~2h
**actual:** 1h
**closed:** 2026-04-29

Reused keychain ACL pattern from M4. Anthropic mirror should be straightforward as a result.
```

Convention:
- **Heading** = `<ref> — <title>`. Repeating the ref makes `rg <ref>` find both the task line and the detail block.
- **Bold-labeled fields** for the structured bits: `**est:**`, `**actual:**`, `**status:**`, `**started:**`, `**closed:**`. Free prose follows after a blank line.
- **`<a id>` anchor** above the heading — see *Jump-link convention*.

Field semantics:
- `**est:**` — estimate range, mirrors the issue's `estimate_hours` frontmatter when one exists. Free-form (`10–16h`, `~2h`, `medium`).
- `**actual:**` — actual focused hours spent. Set on close.
- `**status:**` — used when state isn't conveyed by the checkbox alone. Common: `blocked — <reason>`, `in progress — <note>`. Drop when the checkbox is sufficient.
- `**started:**` / `**closed:**` — ISO dates.

### Jump-link convention

The bracketed `[<ref>]` in task lines becomes a clickable link to the corresponding detail block when a reference definition is present at the file bottom. Combination of markdown shortcut-reference links + explicit `<a id>` anchors.

**Slug rule (deterministic, renderer-independent):** lowercase the ref, replace each `#` and whitespace character with `-`. Examples:

- `charon#13 M2` → `charon-13-m2`
- `charon#13 sketch` → `charon-13-sketch`
- `brain-team#40 doc-cleanup` → `brain-team-40-doc-cleanup`

**Three pieces, in order in the file:**

1. **Task list line** (literal, unchanged): `- [ ] OpenAI provider impl [charon#13 M2]`
2. **Detail block:**
   ```
   <a id="charon-13-m2"></a>
   ### charon#13 M2 — OpenAI provider impl
   ...
   ```
3. **Reference definition at end of file:**
   ```
   [charon#13 M2]: #charon-13-m2
   ```

Behavior at render time:

- Task with a matching reference definition → `[<ref>]` is a clickable link, jumps to the `<a id>` anchor.
- Task without a reference definition → `[<ref>]` renders as plain bracketed text. Nothing breaks.

The task line never changes syntax. Slug derives from the ref alone (not the heading text), so renaming the title doesn't break the link. `rg <ref>` is always a working fallback.

### Single-operator discipline

`operator` carries a single persona name. **Exactly one operator per project.** This is the discipline that makes AI-centric flow viable — no synchronization needed, no blocked-on-each-other patterns, throughput is preserved.

If two people need to work on overlapping concerns, split into two projects with a clear interface (e.g., one project produces an artifact, another consumes it). The dispatcher should flag any "we'll split this between A and B" framing as a smell.

For solo founders today, `operator` is optional and defaults to self. Becomes load-bearing when 2+ people share a brain.

## Authoring instructions

When the dispatcher applies this prototype:

1. **Distill before asking.** Pull project name, goal, candidate issues from recent conversation. Pre-fill what's clear; ask only for what's missing.

2. **Required fields the dispatcher must resolve before writing:**
   - `name` (slug) — usually obvious from "project for X". Confirm if X has spaces.
   - `goal` — one sentence. If not extractable, ask.
   - `done_when` — the MVP boundary. **Force this conversation upfront** even if the user resists; this is the discipline the datatype enforces. Push for a falsifiable criterion ("daily reliance on charon for ≥1 week") not a vague goal ("charon is good").

3. **Force the MVP scoping conversation.** Ask explicitly: *"What's NOT in this project? What's the smallest version that delivers external value?"* Resolve `mvp_scope` and `explicitly_out` as `[<repo>#<id>, ...]` lists. The conversation about what's *out* is the load-bearing part.

4. **Confirm operator.** Default to self for solo founders. If the user says "we" or names multiple people, flag the multi-operator smell and suggest splitting.

5. **Build the initial `## tasks` list, top-down by execution order.**
   - For tasks already in flight or with known estimates, create detail blocks.
   - For tasks not yet started, just task lines. Detail blocks are added later as state accumulates.
   - Pull estimates from the corresponding issue's `estimate_hours` frontmatter when authoring detail blocks.

6. **Add reference definitions** at the end of the file for each task with a detail block. Slug per the rule above.

7. **Default location:** `data/project/<slug>.md`.

8. **Updates preserve everything else.** Common edits: flipping a checkbox state, adding a detail block, recording `actual:` and `closed:` on completion, adding or removing tasks. Edit in place — never rewrite the file.

9. **Velocity calibration loop discipline.** When a task closes (checkbox flips to `[x]` and `actual:` is recorded in the detail block), the dispatcher should also:
   - Update `actual_hours: <N>` in the corresponding issue's frontmatter (in the product repo's `workshop/issues/`).
   - Append a row to `brain/data/life/42shots/velocity/estimate-logic-v1.md`'s validation table.
   - State the calibration analysis ("estimate was X, actual was Y, off by Z×") to the user.

10. **Confirm before writing** a new project file: show destination path, lede line, mvp_scope, explicitly_out, initial task list. One round of confirmation.

## Search recipes

```sh
# All projects
rg -l "^type: project"

# Active projects
rg -l "^type: project" | xargs rg -l "^status: active"

# Projects involving a specific repo (look for refs in the body)
rg -l "^type: project" | xargs rg -l "\[charon#"

# All open tasks across all active projects
rg "^- \[ \] " data/project/

# All blocked tasks
rg "^- \[\.\] " data/project/

# Tasks in a specific project, in order
rg "^- \[" data/project/charon-release-push.md

# All issue refs touched by a project
rg -o "\[[a-z][a-z0-9-]*#[a-z0-9 -]+\]" data/project/<name>.md | sort -u

# Closed tasks with their actual hours (across projects)
rg -B1 "^\*\*actual:\*\*" data/project/

# Lede lines for all projects
rg -A2 "^# " data/project/
```

## Rules

- One project per file. Slug, filename, and `name:` field must agree.
- One operator per project. Multiple operators on one project is a smell — split instead.
- A project always has a falsifiable `done_when`. "Vague goal" is a planning failure; force the conversation at authoring time.
- `mvp_scope` and `explicitly_out` together form the MVP commitment. The `out` list is the load-bearing one.
- Task lines stay short — title + ref only. State and detail belong in `## details`.
- Reference definitions and detail blocks are paired: when adding a detail block, add the reference definition; when removing one, remove the other.
- Closing a task triggers the velocity calibration loop — propagate `actual_hours` to the issue's frontmatter and to the validation table. Without this discipline, calibration drifts.
- A project doesn't replace an issue tracker. Issues describe units of work that exist regardless of timing; a project is the operator's view of what's currently in flight. The same issue can appear in multiple projects over its lifetime.
