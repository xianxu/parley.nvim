---
id: 000335
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '130b0a702b52fdff36dda69a3fdfb15b9496912d' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-15
