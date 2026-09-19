---
id: 000269
status: open
deps: [ariadne#238]
github_issue:
created: 2026-09-18
updated: 2026-09-18
estimate_hours:
---

# atlas: migrate to purpose split (map / journeys / workflow)

## Problem

ariadne#238 splits atlas by purpose:
- **the map** (`atlas/` root and feature folders): short pointers, terminology,
  design reasons
- **user journeys** (`atlas/journeys/`): steps in the user's words plus an
  interruption table of current behavior
- **workflow** (`atlas/workflow/`)

It also sets a sorting rule for existing content: user-visible behavior goes to
`journeys/`, an invariant goes to `workshop/targets/`, a pointer or design reason
stays in the map (short), and prose that restates the code is deleted.

This repo's atlas predates that split.

**Survey (2026-09-18).**
- **Size:** 60 own pages, about 6,200 lines including `traceability.yaml`.
  About 43 pages describe features the user sees, about 11 are internals
  (`chat/document.md`, `chat/ownership.md`, `chat/exchange_model.md`,
  `providers/tool_execution.md`, …), and 6 are infra.
- **No journeys.** The only step-by-step content is the three tutorials under
  `packaging/tutorials/`, all happy path.
- **Failure behavior is scattered:** Stop in `chat/lifecycle.md` and
  `providers/tool_use.md`, batch pause, recovery. Some cases are missing from the
  user's view entirely: quitting or crashing mid-stream (what's left on disk?), a
  dropped network connection, undoing file edits a tool made.
- **Implementation words leak into user-facing text:** "generation" in 20 files,
  "grant" in 15, and "Editing an active answer revokes its writer".
- **Settled rules are buried in prose:** "no Parley trash or undelete"; a failed
  or unknown tool call is "never replayed automatically". These go into the
  always-on product section (ariadne#236), not atlas.
- **Invariant:** half of `chat/ownership.md` is already the target
  `transcript-is-the-whole-truth`.

**Central journeys:** first run (install → connect → pick a model → first
answer); the ask/answer loop (send → streaming → next question); regenerate and
recover an answer; branch off a side question; a turn where tools act on files;
find, resume, move or delete a chat; run a review.

**Contradiction:** `atlas/chat/lifecycle.md:4` says "save edits with `:write`",
while `packaging/tutorials/basics.md:35` says Parley autosaves about a second
after leaving insert mode.

## Spec

Apply ariadne#238's convention (AGENTS.md §8; `datatype show journey`):

1. **`atlas/index.md` sections by purpose:** Map, Journeys, Workflow. Every file
   stays linked.
2. **`atlas/journeys/`:** one `journey` page per central journey, listed above,
   in user vocabulary. For each interruption row, say what the user sees today.
   Mark a row *undecided* when no source (code, README, help text, tutorials)
   settles it, and list the undecided rows in the Log for the operator. A repo
   with no user surface can say so in `index.md` and skip this step.
3. **Sort each existing page, section by section**, using the rule above. Move
   invariants into `workshop/targets/`, cut map pages to pointers, and delete
   prose that restates the code.
4. **Fix the contradictions** listed above, and any others found while sorting,
   against the code, which is the source of truth.

## Done when

- `atlas/index.md` is organized by purpose and links every file.
- `atlas/journeys/` covers the central journeys (or `index.md` says why there are
  none). Undecided rows are listed in the Log.
- No map page restates code at length; each moved section is noted in the Log
  with its destination.
- The listed contradictions are resolved.

## Plan

- [ ] Journeys: draft, mark undecided rows, get the operator's review.
- [ ] Sort existing pages and fix contradictions.
- [ ] Rebuild `index.md` by purpose.

## Log

### 2026-09-18

Filed from a brain advisor session as one of the per-repo migrations under
ariadne#238. Order: ariadne#238, then these migrations, then `prd` (ariadne#237).
