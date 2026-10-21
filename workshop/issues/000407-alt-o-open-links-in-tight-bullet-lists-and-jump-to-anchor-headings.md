---
id: 000407
status: open
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: '354759d16815f4978f6beb2a7b8f3a2b474253c4' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+O: open links in tight bullet lists, and jump to #anchor headings

## Problem

## Spec

Operator report (ops session file, 10-21 09:20): Alt+O (open the link under the cursor) has two gaps:

1. **A link in a bullet item isn't found when the list has no blank line between items.** In a tight list
   (`- item one [x](a.md)` directly followed by `- item two …`), Alt+O on the link doesn't open it. It should work the
   same as in a loose list or a paragraph. (Likely the link scanner treats the whole tight list as one block, or
   anchors on paragraph boundaries.)
2. **A link with an anchor doesn't jump.** `[review](session.side/2026-10-20-37-agent-switch-plan.md#revised-plan-ready-10-21-0040)`
   should open the file and jump to the heading whose slug is `revised-plan-ready-10-21-0040` (GitHub-style slug:
   lowercase, spaces to `-`, punctuation dropped). Today the jump fails.

## Done when

- Headless tests: Alt+O opens links in tight and loose bullet lists, nested items and paragraphs; a link with
  `#anchor` opens the file and puts the cursor on the matching heading (GitHub-style slugging, including headings
  with digits, parentheses and colons); an unknown anchor opens the file at the top with a short notice.
- Plain file links without anchors behave as today.

## Plan

- [ ]

## Log

### 2026-10-21
