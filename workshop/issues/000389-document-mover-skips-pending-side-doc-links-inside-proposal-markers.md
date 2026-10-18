---
id: 000389
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '86880d9df4d78e115aaa0f6ce456cc045fbd7d6b' # card fields mirrored from issue-cards; edit via sdlc
---

# Document mover skips pending side-doc links inside proposal markers

## Problem

A marker-free side-doc link under `presentation: propose` is emitted by the installed Pair apply engine as `🤖{ → \\[proposal\\](design.side/01-release.md)}`. The parent also gets a direct `discussions:` entry in the same apply. Parley's S3 document mover scans Markdown links through `reference_candidates.markdown_spans`, then `document_move_plan.rewrite_links` skips an escaped opening bracket. Moving `design.md` and its `.side/` folder rewrites the index and side-doc paths but leaves the pending marker's destination pointed at the old folder. The attention finder discovers side docs by scanning `.side/*.md` and `type: side-doc`, independently of the link, so the move is the observed gap.

## Spec

Treat an engine-generated pending side-doc link inside a `🤖{…}` proposal marker as a document reference for the mover. Preserve its marker escaping and rewrite only the destination when the parent and side folder move. Keep unrelated escaped Markdown or code-fenced examples outside the move rule.

## Done when

- A move fixture with the exact Pair output `🤖{ → \\[proposal\\](design.side/01-release.md)}` rewrites the pending destination to the new side folder and keeps the marker grammar valid.
- The matching `discussions:` entry, side-doc folder and backlink move together; the pending link resolves after the move.
- Escaped Markdown outside a proposal marker and fenced examples remain unchanged, with focused tests.

## Plan

- [ ] Add the red mover fixture using the installed Pair output above.
- [ ] Extend the one mover reference path to include the pending marker and prove the move and negative cases.

## Log

- Filed from ariadne#437 close-review follow-up on 2026-10-18. Pair live conformance provided the exact marker bytes; ariadne's shared side-doc parser is being updated there. This Parley follow-up does not block #437.
