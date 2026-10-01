---
id: 000308
status: working
deps: [ariadne#252]
github_issue:
created: 2026-09-30
updated: 2026-09-30
estimate_hours:
card_mirror: 'c665520f81e5c7539038bb584a7305912b488ae1' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-30T17:08:06-07:00
---

# Issue finder folds in issue-tracker card fields

## Problem

Since ariadne#252 a tracked repository (cutover marker `workshop/issue-tracker.json`)
keeps card-owned fields — status, started, created, updated, estimate/actual hours,
github_issue, title — on the `issue-tracker` branch (`workshop/issue-cards/*.md`).
The details file in `workshop/issues/` only carries a `card_mirror` snapshot that
goes stale as soon as any `sdlc` verb (claim, set-status, close) moves the card.
Parley's issue finder and issue buffers read only the details file, so they show
stale status/dates (e.g. #296 reads `open` locally while its card is `wontfix`).

## Spec

Fold the tracker's card fields into parley's issue views, read-only.

- **Source.** Per repo root: tracked iff `workshop/issue-tracker.json` exists.
  Card dir + branch name + card-owned field list come from the vocabulary JSON
  (`discovery.cards`, `discovery.tracker`, `card.fields`) — no hardcoding (ARCH-DRY).
  Ref = `refs/remotes/<remote>/issue-tracker`, remote = upstream remote of the
  default branch, else the single remote carrying that ref. All slots share the
  ref via the common git dir.
- **Read.** Async: `git ls-tree` on the ref's card dir → blob OIDs; only blobs not
  in an OID-keyed cache go through one `git cat-file --batch`. Pure parser turns a
  card blob into `{id, title, fields}`.
- **Freshness.** Render immediately from the local ref; kick a throttled (≥60s)
  async `git fetch <remote> issue-tracker`; if the ref moved, re-overlay and
  refresh the open finder / issue buffers. No network on the render path; fetch
  failure is silent-ish (debug log), the local ref still shows.
- **Overlay (pure).** Card-owned fields from the card win over the details
  mirror; non-card fields (deps, body) stay from details. A field whose card value
  differs from the details mirror is marked `stale` per field. A card missing in a
  tracked repo → keep the details value (read-only view; no fabrication).
  Untracked repos: unchanged behaviour.
- **Finder.** Rows show card values (status, title, github_issue, created).
  Fields marked stale render in amber (`ParleyIssueTracker` highlight, default
  amber, user-overridable). Status sort uses the card status. Needs a small,
  generic per-item highlight-span extension to `float_picker`.
- **Issue buffer.** On open/refresh of a details file in a tracked repo, each
  card-owned frontmatter line whose card value differs gets amber end-of-line
  virtual text `← tracker: <value>` (title: on the H1). Buffer bytes untouched.

Out of scope (follow-up): the finder's cycle-status key and `:ParleyIssueStatus`
write `status:` into the mirror, which sdlc refuses in tracked repos; they should
route through `sdlc issue set-status`.

## Done when

- In parley.nvim (tracked), the finder shows #296 as `wontfix` with the status in amber.
- Opening a stale details file shows amber virtual text with the tracker values.
- Unit tests: card parser, overlay/stale-diff, ref resolution, highlight spans;
  integration test with a disposable git repo carrying an `issue-tracker` branch.
- Untracked repos and missing refs behave exactly as before (tests).

## Plan

Durable plan: [000308 plan](../plans/000308-issue-finder-folds-in-issue-tracker-card-fields-plan.md). Single pass, one close.

- [ ] T1 pure issue_cards
- [ ] T2 float_picker item highlight spans
- [ ] T3 segment-built finder rows
- [ ] T4 issue_tracker async reader + throttled fetch
- [ ] T5 finder overlay wiring
- [ ] T6 issue-buffer amber annotations
- [ ] T7 atlas + verification

## Log

### 2026-09-30
- Operator: amber for tracker values; scope = finder + issue buffer; freshness = local ref + throttled background fetch.
