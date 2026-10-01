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
flow: {kind: full, provenance: inferred}
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
- A tracker move, whether this session's fetch or a ref another slot's sdlc fetched, repaints every open finder and issue buffer on that repo, including hidden buffers, under the real throttle (tests). A failed re-read keeps the last good cards.

## Plan

Durable plan: [000308 plan](../plans/000308-issue-finder-folds-in-issue-tracker-card-fields-plan.md). Single pass, one close.

- [x] T1 pure issue_cards
- [x] T2 float_picker item highlight spans
- [x] T3 segment-built finder rows
- [x] T4 issue_tracker async reader + throttled fetch
- [x] T5 finder overlay wiring
- [x] T6 issue-buffer amber annotations
- [x] T7 atlas + verification

## Log

### 2026-09-30
- 2026-09-30: closed — Round 2 after BR-1 fix. New specs green: unit issue_cards(14), float_picker item spans, issue_finder_records render(4); integration issue_tracker(10: subscriber fan-out, closed-view pruning, plain-load move, failed re-read keeps cache, throttle, OID cache), issue_finder_tracker(4: incl. another view moving tip), issue_tracker_buffer(4: hidden buffer repaint under real 60s throttle). make lint clean. Manual on this repo: 307 cards load, #296 finder [wontfix] amber, buffer "← tracker: wontfix". make test residuals pre-existing/unrelated: arch buffer_mutation (spell_source.lua from #304, identical to main), #294 parallel-load flakes passing in isolation.; review verdict: SHIP
- 2026-09-30: flow upgraded quick → full — 744 added lines in code files (limit 100); an earlier round of this close already ran the full review
- Operator: amber for tracker values; scope = finder + issue buffer; freshness = local ref + throttled background fetch.
- Implemented T1–T7: pure `issue_cards`, `float_picker` item highlight spans, segment-built finder rows, async `issue_tracker` (ls-tree + one cat-file batch, OID cache pruned per tip, throttled fetch), finder overlay with selection-preserving repaint, buffer virt_text, atlas. ARCH-MOCK: real git in throwaway repos (`tests/helpers/tracker_repo.lua`). ARCH-FUNERAL: in-memory state only, blob cache pruned to the current tree.
- Discovery: the single-source arch guard needs every export as its own backticked name in a Core-concepts row, so the plan tables were split (plan Revisions).
- Added `fetch_enabled`, off under `PARLEY_TEST_MODE`, so no spec reaches a real remote.
- Manual check on this repo: 307 cards load; #296 shows `[wontfix]` with an amber span in the finder, and its buffer shows `← tracker: wontfix` beside `status: open`.
- `make test`: the new specs pass. Pre-existing failures unrelated to this diff: `tests/arch/buffer_mutation_spec.lua` (spell_source.lua from #304, identical to main) and parallel-load flakes (#294) that vary per run and pass in isolation (document_semantic, branch_child, document_append_extent). `make lint` is clean.
- Close round 1, FIX-THEN-SHIP, BR-1 Important: a moved tip reached only the view that triggered the fetch. Fixed the class: per-root `subscribe` notifies every live view on any tip change, and an issue buffer's BufEnter re-reads the local ref. Specs: subscriber fan-out, a pruned closed view, a hidden buffer under the real throttle, finder notified by another view's read. Minors also fixed: a failed re-read keeps the cache, a blank card title is ignored, a dropped GitHub link shows `(#-)`, and the Spec wording is corrected (Revisions).

## Revisions

- 2026-09-30 — Spec "Source": the remote is the **current branch's** upstream remote (else the single remote carrying the ref), not the default branch's. "Freshness": a moved tip is pushed to every open view through a per-root subscription, and issue buffers also re-read the local ref on BufEnter.

