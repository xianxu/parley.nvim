---
id: 000310
status: working
deps: []
github_issue:
created: 2026-10-02
updated: 2026-10-02
estimate_hours:
card_mirror: '811b1e36e7655b6d73fcaed17af8d338fc004734' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-02T09:57:52-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Issue view: overlay all tracker card fields generically

## Problem

ariadne added more fields to the issue-tracker card (`started`, `actual_hours`,
`estimate_hours`, `claimant`). They are already declared in the vocabulary's
`card.fields` (`construct/generated/vocabulary/issue.json`), but a viewed
details file never shows them.

Why: `issue_cards.annotations()` (#308) only annotates frontmatter lines that
**already exist** in the details file and disagree with the card. Details
files carry only `id/status/created/updated/github_issue/estimate_hours` plus
`card_mirror`, so a card-owned field with no local line (e.g. `started`,
`actual_hours`, `claimant`) can't be displayed. The finder overlay has the same
problem: `RECORD_FIELDS` in `lua/parley/issue_cards.lua` is a hardcoded list
(`status, title, created, updated, github_issue`), so every new card field
needs a parley change.

## Spec

Make it generic: **the tracker card is the source of truth for every
card-owned field, and it overrides the local frontmatter on display**. Use the
same amber `ParleyIssueTracker` highlight as today.

- The field set comes from the vocabulary (`issue_tracker.field_names()`),
  never a parley-side list. A new card field in ariadne shows up with no parley
  code change (ARCH-DRY: single-sourced from the vocabulary).
- For a field that **has** a local frontmatter line and disagrees: keep today's
  `← tracker: <value>` eol annotation.
- For a field that is **missing** locally and has a non-blank card value:
  render it as an amber virtual line inside the frontmatter (e.g. a
  `virt_lines` extmark before the closing `---`), shaped `key: value`, so it
  reads like frontmatter. Buffer bytes are never changed (card fields stay
  sdlc's to write).
- Skip internal keys: `id` (already skipped) and the `tracker:` envelope (it is
  nested, so the parser never sees it).
- Finder overlay (`M.overlay`): replace the hardcoded `RECORD_FIELDS` with the
  vocabulary names, so card values also take precedence over local values in the
  finder records.
- Field order for virtual lines follows the vocabulary's `card.fields` order.

## Done when

- Opening a tracked details file whose card has `started`/`actual_hours`/
  `claimant` (e.g. a done issue such as #294) shows those values as amber
  virtual frontmatter lines; an existing-but-stale line still gets the
  `← tracker:` annotation.
- Adding a fake field to the vocabulary's `card.fields` in a unit test makes it
  render with no other code change.
- `RECORD_FIELDS` is gone; the overlay is driven by the vocabulary names.
- Unit tests in the `issue_cards` spec cover: missing field → virtual line,
  stale field → eol annotation, matching field → nothing, blank card value →
  nothing, ordering. `make test` is green.

## Plan

- [ ] `issue_cards.annotations` → return both eol notes and `missing` virtual
  lines (pure, unit-tested)
- [ ] `issue_tracker_buffer.paint` renders virtual lines with the amber highlight
- [ ] `overlay` driven by vocabulary names; drop `RECORD_FIELDS`
- [ ] Manual check on #294's details in a tracked checkout

## Revisions

### 2026-10-02 — scope folded in at planning
- `claimant` is a nested map on the card (operator, machine, workspace, …);
  `parse_card` only read flat `key: value` lines, so it came back as `""`.
  Nested values now parse as a block (the child lines, dedented, in order), and
  render as YAML-shaped virtual lines, or inline in an eol note.
- The card-only view (`view_lines`, #309) has the same hardcoded list
  (`VIEW_FIELDS`); it now takes the vocabulary names too. Same class, same fix.

## Log

### 2026-10-02

Filed from operator request: ariadne's tracker gained fields that parley's
issue view doesn't show. Root cause: annotations only cover fields with an
existing local line, and the finder overlay uses a hardcoded field list.
