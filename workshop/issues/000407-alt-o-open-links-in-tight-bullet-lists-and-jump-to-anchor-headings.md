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

- [x] Add red headless regressions for tight/loose/nested bullet items and direct links; anchored headings with digits/parentheses/colons, unknown anchor and plain links.
- [x] Narrow navigation-only bullet ranges to the enclosing item, reusing fence/bounds context; keep editing ranges and numbered-item behavior intact (ARCH-DRY).
- [ ] Split file/fragment before existing path resolution; pure heading lookup uses GitHub-style slugs, then the editor jumps only after confirmed destination arrival (ARCH-PURE, ARCH-ORDER).
- [ ] Run mapped tests and recorded suite; update README/atlas.

Close review and normal landing follow verification. Per the hub, no stage: operator receives the landed change in normal use.

Actions: follow a link; retry/correct a missing heading. Found anchor: show destination heading. Unknown anchor: show file top plus short notice; correct the fragment and retry. Missing file: retain existing failure notice and source. No file bytes or durable navigation state are added; existing history owns navigation lifetime. Scans run only on Alt+O, linear in source lines plus destination heading bytes, not per edit. Reuse the existing occurrence scanner rather than parsing links twice; no new parser or background task.

## Log

### 2026-10-21

- Root-cause inspection: ordinary Markdown resolution requires a URL ending in .md, so a fragment bypasses that opener and reaches gf without a heading jump. Navigation owns numbered items but unordered items fall back to a paragraph spanning adjacent list items. Existing issue/chat slug helpers have different punctuation/stopword semantics; use a heading-specific pure lookup rather than changing their contracts. No persisted format changes or external service dependencies.

- Implementation: navigation-only unordered item stack chooses the enclosing item and bounds tight siblings; editing ranges and existing numbered tests remain unchanged. File resolution now returns path plus optional fragment. Pure heading lookup skips fenced examples, drops ASCII punctuation while keeping hyphens/underscores, supports percent-encoded fragments and duplicate suffixes. The editor verifies destination arrival before moving its cursor; missing headings go to top with a warning. Same-file item jumps skip source-cursor restoration.
- Red evidence: /tmp/parley407-red2.log and /tmp/parley407-unit-red.log expose tight sibling candidate merging and missing anchor lookup. The literal direct-link label itself already opened; the reproduced list gap is navigation from item prose/continuations. Native fixture corrections: record offered picker rather than entering the blocking built-in picker; compare RPC nil as a boolean; correct Lua long-string index syntax. /tmp/parley407-samefile-red2.log fails Normal and Insert cases at row1 vs expected4 before the restoration fix. An earlier condition-only same-file fixture stalled; command-completion instrumentation now gives the immediate cursor assertion instead.
- GREEN: make -k test-spec SPEC=context/file_references passed, /tmp/parley407-final-targeted.log (native mapping26/26, navigation range78/78, heading6/6 plus existing mapped tests). make -k lint passed across818 files,0 warnings/errors (/tmp/parley407-lint.log); git diff --check clean. README, existing atlas map and traceability updated. Required recorded suite and close remain pending; no live-editor acceptance claimed.

- Recorded suite passed on c4d2222ad0fd0dbe0db443e0d0ac7e247b634ccb, attempt b82743bbb46e9281aaf07b62cd3fa8a5, exit0 in 316.35s; log SHA256 961fd0842cf8941980c82abd3298a2d23c5a496bbb2cbda78b0f150ac2dcda9e. GitHub merge-check and local-gates guard passed on PR328. Hub explicitly directed no stage because :0 holds #404; land after suite and close, then the hub fast-forwards the operator's live checkout for normal-use acceptance.

## Revisions

### 2026-10-21 — Close round 1: complete Markdown normalization and containment

Close returned REWORK with BR-1/2/3. Reopen verification for all three families:

- Heading-content normalization: trim heading edges, turn spaces into hyphens and remove other whitespace; remove paired inline formatting, link destinations and HTML tags before slugging while preserving literal intra-word underscores. Cover whitespace, emphasis, inline code, links and HTML plus duplicate suffixes. Keep this pure and inside the existing heading lookup.
- Shared fence containment: replace the memo's boolean delimiter toggle with opener character/run-length state; only a same-character, sufficient-length, whitespace-only closer ends it. Preserve configured transcript partition resets and plain-Markdown non-partition mode, the memo API, and its existing indentation dialect. Do not change the separate render/ordinary fence dialect.
- Navigation item boundaries: treat a dedented fence opener as a block boundary before excluding fenced contents; retain indented fenced blocks inside their item. Cover all three bullet markers and both fence characters, with an outside-link negative mapping case.

The simpler alternative (extra anchor-local fence matching) duplicates the shared memo and leaves its other consumers wrong, so repair the shared owner (ARCH-DRY). Regex punctuation stripping alone cannot distinguish formatting underscores from literal text; normalize the heading's inline content first. No persistent state, new background work or new external dependency. All changes remain command-time linear scans; no edit hot path is added. New regression cases must fail before the fixes, then pass with the existing mapped tests, fresh recorded suite and re-close. If the implementation leaves the quick shell, the normal full boundary review applies.

- Close evidence: round1 REWORK, three open Critical findings; prior suite success does not cover these counterexamples. GitHub section-link rules and GFM fence rules checked against their official references. Await hub approval of the shared-memo correction before implementation.
