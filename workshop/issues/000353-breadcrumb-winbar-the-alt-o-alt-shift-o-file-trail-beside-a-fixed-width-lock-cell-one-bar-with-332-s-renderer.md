---
id: 000353
status: working
deps: [parley.nvim#332]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'c329791d83c041854feeb0ae3577ba9a6a1d6ed3' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T09:59:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Breadcrumb winbar: the Alt+o / Alt+Shift+O file trail beside a fixed-width lock cell (one bar with #332's renderer)

## Problem

Moving through a tree of documents with Alt+o (into a link) and Alt+Shift+O (back up), the operator loses track of
where they are. Operator design, 2026-10-16 (ops QA `teams/devinfra/qa/xian-xu/2026-10-16-03-breadcrumb-winbar.md`):
show the trail in the winbar, combined with the Couch/parley lock bar. Part of ops project
universal-agent-input-interface.

## Spec

- **A per-window stack:** a file opened any way other than Alt+o is the root (the stack clears); Alt+o pushes the
  target; Alt+Shift+O pops. At the root, no breadcrumb.
- **One winbar, built by #332's shared renderer:** a fixed-width lock cell first (about 9 cells: `yours ●` with the
  dot meaning unsubmitted edits, `free`, `agent…`, `stale`), keeping the background colour for "needs submit"; then
  the breadcrumb: basenames without `.md` or a `YYYY-MM-DD-` prefix, joined by `›`; when too long, the middle
  collapses to `…`, keeping the root and the last two; same-named files gain their parent folder.
- Click-to-jump on a segment: out of scope (later).
- **Expose the per-file breadcrumb** (the trail at a moment) as a value other features can store and restore (the
  attention finder uses it).

## Done when

- Tests: push, pop, reset on non-Alt+o opens, per-window independence, truncation, same-name disambiguation, and
  lock-cell rendering for each state through the shared renderer; the operator's live check.

## Plan

Full-flow, single close boundary. Detailed design: [breadcrumb winbar plan](../plans/000353-breadcrumb-winbar-plan.md).

- [ ] Add pure breadcrumb transitions and display projection, with direct sequence/width tests.
- [ ] Record successful Alt+o destinations through the existing file history; expose snapshot/restore values and preserve native Back behavior.
- [ ] Compose a nine-cell lock state, breadcrumb and feedback in document_band; keep its restoration ownership and both file kinds identical.
- [ ] Exercise native keys, async resolution, split/window lifecycle and every lock/feedback state; update atlas/README/traceability.
- [ ] Run the required suite, close on SHIP, stage with the hub's coordination and perform the operator's live check before landing.

## Log

### 2026-10-16

- Planning follows landed #332 PR241, merge `3219cc0c705bd1a7c097bcf920135155892645b9` verified with git rev-parse; exact integrated-head suite passed, four CI checks green. Hub received the outcome (receipt 7d3db9df-927c-40ab-af86-588a7891a6e5 submitted).
- Existing `file_history` records every native file visit, not only Alt+o, and restores cursors/skips missing paths on Back. Breadcrumb is a value carried by those visits, not a replacement for this history (ARCH-DRY). `M.open_buf` may focus another editing window, so follow must commit against the actual destination window; async artifact/family resolution must carry the same explicit origin rather than leave a global pending flag.
- Staging lesson from #332: a later worker had replaced :0's stage with #257 at `d3909bd93e7cc6a0194fe255a1778099f489c5b7`; unconditional stage --clear removed that newer stage. Hub informed in the submitted landing report. Inspect the current stage identity before clearing; if another item's stage replaced ours, leave it to its owner.
- Design pending TL approval; no implementation started.

## Revisions

### 2026-10-16 — #354 persisted-trail coordination

Agreed with parley.nvim:3: retain snapshot(win)/restore(win,value), with an opaque JSON-safe value. Finder owns opening the selected file; restore owns removing missing ancestors and installing the surviving trail/Back stack without opening files. It returns false plus a reason for invalid values, uncertain ancestor checks or final-file mismatch; finder keeps the opened file as a root on refusal. Detailed contract and regression cases are appended to the durable plan. Awaiting TL approval before implementation.

- TL approved the design and contract Revision (receipt 5d93a58a-2467-42dd-bac4-6b468bbf15d1, submitted). Full-flow change-code next. Live-check override: report green without staging; :0 is reserved for a combined check and TL will sequence this one.
