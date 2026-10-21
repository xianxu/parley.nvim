---
id: 000407
status: working
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: '0fbb7e39bc504a3b65d5a721421879c1dab9ebc1' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-21T08:52:51-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "ba2d58a3", done: "957e14cc"}
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

- [ ] Add red headless regressions for tight/loose/nested bullet items and direct links; anchored headings with digits/parentheses/colons, unknown anchor and plain links.
- [ ] Narrow navigation-only bullet ranges to the enclosing item, reusing fence/bounds context; keep editing ranges and numbered-item behavior intact (ARCH-DRY).
- [ ] Split file/fragment before existing path resolution; pure heading lookup uses GitHub-style slugs, then the editor jumps only after confirmed destination arrival (ARCH-PURE, ARCH-ORDER).
- [ ] Run mapped tests and recorded suite, update README/atlas, close review; coordinate live check with hub before normal landing.

Actions: follow a link; retry/correct a missing heading. Found anchor: show destination heading. Unknown anchor: show file top plus short notice; correct the fragment and retry. Missing file: retain existing failure notice and source. No file bytes or durable navigation state are added; existing history owns navigation lifetime. Scans run only on Alt+O, linear in source lines plus destination heading bytes, not per edit. Reuse the existing occurrence scanner rather than parsing links twice; no new parser or background task.

## Log

### 2026-10-21

- Root-cause inspection: ordinary Markdown resolution requires a URL ending in .md, so a fragment bypasses that opener and reaches gf without a heading jump. Navigation owns numbered items but unordered items fall back to a paragraph spanning adjacent list items. Existing issue/chat slug helpers have different punctuation/stopword semantics; use a heading-specific pure lookup rather than changing their contracts. No persisted format changes or external service dependencies.
