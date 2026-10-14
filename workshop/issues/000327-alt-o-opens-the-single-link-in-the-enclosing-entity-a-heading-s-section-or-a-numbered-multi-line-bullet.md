---
id: 000327
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '63c491722b5f743d4efd45c8ff3998d0426393ae' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+o opens the single link in the enclosing entity: a heading's section, or a numbered multi-line bullet

## Problem

The operator (2026-10-14) navigates the TL session file and QA answers with Alt+o. Today Alt+o acts only on the
reference under the cursor, so to follow an answer link (`→ [answer](qa/…)`) at the end of a long, multi-line
Operator-instructions bullet you must first move the cursor onto the link.

## Spec

When Alt+o finds no reference under the cursor, it looks at the enclosing **entity**, using parley's existing entity
notion: on a markdown heading, the section from that heading to the next heading of the same or higher level; on a
numbered item (`N. `), the whole multi-line item up to the next `N. ` line or heading, with the same rule as ops'
`skills-draft/xx-tl/scripts/opinstr.py` (blank lines inside included, trailing ones not). If that entity contains
exactly one link or reference, open it. With several, show a picker (or say how many). With none, keep today's
fallback (`sdlc resolve`, then `gf`). A reference directly under the cursor always wins.

## Done when

- On an Operator-instructions bullet whose last line ends in `→ [answer](qa/…)`, Alt+o anywhere in the bullet opens
  the answer (test); on a heading with one link in its section, Alt+o opens it (test); several links → picker;
  cursor-on-link unchanged (regression test).

## Plan

- [ ]

## Log

### 2026-10-14
