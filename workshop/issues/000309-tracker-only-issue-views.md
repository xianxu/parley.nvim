---
id: 000309
status: open
deps: []
github_issue:
created: 2026-09-30
updated: 2026-09-30
estimate_hours:
card_mirror: '9eb24473db49de82ec8d916b855358e949f9995b' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ] Design and implement card-only discovery and viewing on top of #308.

## Log

### 2026-09-30

- Filed from operator request after checking #308's scope and implementation:
  remote-card reading and amber overlays exist, but standalone card rows and
  read-only views do not. This task records the extension; implementation has
  not started.
