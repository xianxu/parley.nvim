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
- [x] Document the corrected navigation behavior; run mapped and full verification before SDLC close and land on SHIP.

## Core concepts

| Entity | Kind | Location | Status | Responsibility |
| --- | --- | --- | --- | --- |
| `markdown_spans` | PURE | `lua/parley/reference_candidates.lua` | new | Paragraph-scoped Markdown spans with row/byte coordinates and raw text. |
| `markdown_links` | PURE | `lua/parley/reference_candidates.lua` | modified | Existing string pattern, with internal scan barriers and single-line destinations. |
| `collect` | PURE | `lua/parley/reference_candidates.lua` | modified | Reserve full Markdown spans before collecting subordinate references. |
| `open_markdown_reference` | INTEGRATION | `lua/parley/init.lua` | new | Shared Markdown-only dispatch retaining destination identity. |
| `OpenFileUnderCursor` | INTEGRATION | `lua/parley/init.lua` | modified | Open direct/selected spans and retain fallback destination rows. |

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

### 2026-10-15 — first full verification and isolated corrections

The first full run passes wrapped-link unit/integration tests but fails the
Core-concepts guard (missing scanner table, plus stale local main including
already-landed #333 symbols) and one existing packaging VM state assertion.
Added the actual Core concepts table. Confirmed main is unoccupied, then safely
fast-forwarded it with git fetch origin main:main (6121476a→83f3893a), without
changing the issue branch or any checkout. Isolated reruns pass all 25 architecture
and 17 packaging cases (/tmp/parley-335-architecture-packaging.log); the packaging
test/implementation were untouched. Clean process censuses. Retrying the full
suite; /tmp/parley-335-full.log retains the first failure evidence.

### 2026-10-15 — full verification passes

Full retry exits 0: all 433 test files pass, lint reports zero warnings/errors
in 732 files, and the final process census is clean
(/tmp/parley-335-full-retry.log). Both architecture and packaging VM cases pass
in this full run. Mapped reference tests, check-vocabulary and git diff --check
also pass. Actual-time measurement succeeds; close can adopt measured hours
without a waiver. Ready for the single quick-flow boundary review.

### 2026-10-15 — review correction red/green

Round 1 returns REWORK with BR-1 (recognized Markdown identity) and BR-2
(document boundaries). Four new cases fail without errors before correction
(/tmp/parley-335-review-red.log). Both direct and selected Markdown dispatch
now share open_markdown_reference; scanners reuse the navigation memo and
receive transcript context, with lexical structural kinds as start barriers.
All eight configured prefixes and backtick/tilde fences are covered in pure
and command tests; existing/missing nested @@ destinations cannot override a
wrapped unsupported URL. Mapped suite passes with clean census
(/tmp/parley-335-review-green.log); vocabulary/whitespace pass. Full rerun
started at /tmp/parley-335-review-full.log. Lessons and atlas updated.

### 2026-10-15 — review correction full verification

The corrected branch passes full make test: exit 0, all 433 files pass, lint
zero warnings/errors in 732 files, clean process census
(/tmp/parley-335-review-full.log). Ready for a full close re-review disposing
BR-1/BR-2; the quick-flow production patch is 83 added lines.

### 2026-10-15 — BR-3 containment correction

Round 2 confirms BR-1/BR-2 addressed and returns BR-3 for remaining Markdown
block boundaries. New pure/command tests fail before correction
(/tmp/parley-335-blocks-red.log). Shared walls now cover thematic breaks,
Setext headings, quotes and all ATX heading levels. Further red/green checks
preserve complete same-line quote links and avoid classifying spaced equals
or four-space-indented continuation text as new blocks
(/tmp/parley-335-{quote,paragraph}-red.log). Final mapped suite passes with
no errors and clean census (/tmp/parley-335-paragraph-final.log); whitespace
passes. Positive list/chat-anchor spans remain supported. Atlas and lessons
updated. Full verification rerun follows; production patch is 88 added lines.

## Revisions

### 2026-10-15 15:30 — close review BR-1 and BR-2

Preserve recognized wrapped Markdown identity through Markdown-only dispatch in
both direct and selected opening (ARCH-DRY). Pass document context through both
scanner consumers: all eight transcript structural prefixes terminate a previous
span, and plain Markdown fences never reset at chat-looking text (ARCH-PURPOSE).
Add failing regressions for existing/missing nested @@ targets, each configured
structural prefix, and both backtick/tilde fenced examples before correcting.

### 2026-10-15 15:47 — BR-3 paragraph containment

Rule: join ordinary paragraph text only. Blank lines, fenced code, ATX and
Setext headings, thematic breaks, and blockquote rows are hard walls; list and
transcript structural anchors may begin a span but cannot continue a previous
one. Existing scan range edges remain walls. The shared adapter enforces this
for both direct navigation and entity collection. Enumerate compact/spaced
thematic forms, Setext variants, indented quote markers and ATX levels 4–6 in
regressions, plus positive list/chat-anchor wrapping to preserve supported
paragraph starts. This refines containment without changing the existing
inline-link syntax or adding container/HTML parsing.
