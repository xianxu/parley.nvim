---
id: 000269
status: open
created: 2026-09-18
updated: 2026-09-18
estimate_hours:
github_issue:
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
