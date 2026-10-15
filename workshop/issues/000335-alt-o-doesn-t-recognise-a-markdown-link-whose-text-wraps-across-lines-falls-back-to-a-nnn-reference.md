---
id: 000335
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '568c79004bc3b5309020624871ccb5ed32eca7e4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T14:41:15-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "ca1ac352", done: "68026ca0"}
---

# Alt+o doesn't recognise a markdown link whose text wraps across lines (falls back to a #NNN reference)

## Problem

2026-10-15: the operator pressed Alt+o on the second line of a markdown link whose **link text wraps across two lines**:

```
… stateful fakes. → [discussion: is this a new
"landing" workflow?](000390-test-economy-pattern-plan.side/01-landing-admission.md)
```

Instead of opening the side doc, parley showed "Resolve #370" (an issue picker): the reference scanner didn't recognise
the wrapped link at all, so #327's enclosing-entity fallback found only the paragraph's `#370` reference and resolved
that. A link with a line break inside its text is valid CommonMark, and agents' hard-wrapped prose produces them.

## Spec

- The reference scanner recognises inline links whose `[text]` spans line breaks (within one paragraph), for both
  "reference under the cursor" (the cursor on any part of the text or the target) and the entity scan.
- With the link recognised, Alt+o under the cursor opens it; in the entity fallback, a paragraph holding both the link
  and a `#370` reference offers both (the picker), per #327.
- Reference-style and autolinks unchanged.

## Done when

- Headless tests: cursor on line 1 and on line 2 of a wrapped link opens its target; the entity fallback lists the
  wrapped link alongside other references; an unclosed `[` across lines is not treated as a link.

## Plan

- [x] Add failing headless tests for wrapped labels under the cursor and in entity/picker scans, including nested references, byte positions, invalid links and scan boundaries.
- [x] Reuse the existing Markdown pattern through one pure multiline scanner; carry full spans and destination row/column through both consumers (ARCH-DRY, ARCH-ORDER).
- [ ] Document the corrected navigation behavior; run mapped and full verification before SDLC close and land on SHIP.

## Log

### 2026-10-15

Claimed from ops:0 delivery c44a6d6a-aa88-48ac-927e-9003073efd81. The Lua
label pattern already accepts newlines, but consumers pass individual lines.
Join eligible paragraph rows at the shared parsing boundary, retain byte/row
coordinates, and mask complete link spans before subordinate reference scans.
Reuse existing destination opening and fallback policies; no new link dialect,
resolver, or second parser. Blank/fenced/range boundaries terminate a span.
Keep the string parser API for existing consumers; this issue changes Alt+o's
direct and entity paths. Quick flow authorized by the dispatch.

### 2026-10-15 — red/green evidence

The mapped context/file_references baseline fails four new cases: direct wrapped
opening, entity choice/opening, fallback destination row, and cross-row masking.
The shared pure markdown_spans adapter reuses markdown_links and maps full spans
to row/byte coordinates; both direct and selected navigation consume those spans.
An added list-boundary case then fails until list anchors become span boundaries.
Blank/fence/heading/range barriers preserve paragraph scope. Final mapped suite
passes with no errors and a clean process census. Evidence:
/tmp/parley-335-{red,block-red,final-targeted}.log. README and atlas updated;
full verification remains pending. No external dependency or state is introduced.
