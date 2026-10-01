---
id: 000309
status: working
deps: []
github_issue:
created: 2026-09-30
updated: 2026-09-30
estimate_hours:
card_mirror: 'f4061c0190b460e9d7fa657df6de0c97c78726fc' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-30T22:11:00-07:00
flow: {kind: quick, provenance: inferred, spec: "dd4ea307", done: "d4c100c7"}
---

# Show tracker-only cards in issue finder and viewer

## Problem

Follow-up to #308. Its tracker overlay enriches rows discovered from local
details files; a card with no details in this checkout is absent from the finder
and cannot be viewed. Details may still live on another local issue branch,
while the shared card is already available on origin/issue-tracker.

## Spec

Include tracker cards without local details in issue discovery and viewing.
Reuse #308's tracker reader and refresh machinery (ARCH-DRY), fetching the
tracker branch asynchronously and updating open views from the fetched ref.
Cached cards may render immediately while refresh runs; network failure must
not discard the last readable snapshot or imply it was freshly fetched.

Card-only finder rows carry an explicit amber "card only · read only" label.
Opening one shows a nonmodifiable, read-only scratch view of the available
card content, including its Problem when present, with the source ref (normally
origin/issue-tracker) and an explanation that details are unavailable in this
checkout. Do not fabricate Spec/Plan content or a local details file. Disable
file-editing, status-mutation, and deletion actions for these entries.

Join cards and local details by repository and issue ID so an issue appears
once. Preserve normal local-file behavior when details are available. Amber
and a textual provenance label must identify remote card content without
relying on color alone.

## Done when

- A card present only on origin/issue-tracker appears in the finder even when
  its details exist only on another branch; normal search/filter/sort work.
- Opening it displays available card content in a read-only, nonmodifiable
  scratch buffer with an amber label and source ref; mutation actions refuse.
- An asynchronous fetch discovers newly published cards and refreshes open
  views; a repository without an existing local tracker ref can load cards
  after fetching. Fetch failure preserves cached content and reports freshness.
- Local details and tracker cards produce one row per repository/ID; local
  details remain openable normally, and untracked repositories are unchanged.
- Tests cover card-only discovery and opening, mutation refusal, fetch success
  and failure, first-fetch bootstrap, and deduplication with local details.

## Plan

Durable plan: [000309 plan](../plans/000309-tracker-only-issue-views-plan.md). Single pass, one close.

- [x] T1 pure card model: card body, card-only records, freshness, card view text
- [x] T2 card-only finder row label
- [x] T3 tracker first-fetch bootstrap + fetch status
- [x] T4 read-only card view + buffer-command refusals
- [x] T5 finder card-only rows, open, refusals
- [x] T6 atlas + live check (#305 is card-only in this repo today)

## Log

### 2026-09-30

- Filed from operator request after checking #308's scope and implementation:
  remote-card reading and amber overlays exist, but standalone card rows and
  read-only views do not. This task records the extension; implementation has
  not started.

- Design: durable plan `workshop/plans/000309-tracker-only-issue-views-plan.md`;
  a fresh-context plan review found 5 blocking issues. The main one: the finder
  spec's relative history_dir resolved to this repository through the real
  parley's `project_root()`. Fixed, then approved on re-review.
- change-code inferred the quick flow (design under the limit); the code diff
  (~360 lines) leaves the shell, so close runs the full review.
- Arch: the card view's render first called `nvim_buf_set_lines` directly and
  tripped `tests/arch/buffer_mutation_spec.lua`. It now goes through a new
  `buffer_edit.replace_all` instead of widening the allow list.
- Live check in this repo (outside the harness, so fetch is on) found two bugs
  the specs had missed, both now pinned by tests:
  - the view stayed on "refreshing…": the finder's fetch was in flight, the
    view's refresh settled at once, and an unchanged tip never notifies. A
    refresh now joins the fetch in flight and gets a throttled follow-up. This
    also fixed a pre-existing race in #308's "background fetch moves the
    tracker" spec, which the longer `fetching` window exposed.
  - every re-render raised W10 because the buffer was `readonly`.
  Final live state: #305 is the only card-only row, and its view reads
  `card only · read only — origin/issue-tracker @ 4a0d2e4 · fetched 22:38`
  with the card's fields and Problem heading, nonmodifiable.
- Suite: green except the two arch specs that also fail on main (only
  `spell_source.lua:61` remains in buffer_mutation) and document-fold specs
  that time out under parallel load but pass alone.

