---
id: 000353
status: open
deps: [parley.nvim#332]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'ac1e3075007217de632fc4f806e9b291dede9d95' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-16
