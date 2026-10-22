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
flow: {kind: full, provenance: inferred}
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

Current scope (hub Revision2026-10-21): anchors refer to Markdown ATX headings1–6 with inline Markdown formatting stripped. HTML headings/inline HTML and character-reference decoding are outside this feature. Unsupported or unmatched anchors retain the file-top notice; no HTML renderer/entity database is introduced.

## Done when

- Headless Alt+O tests open links in tight and loose bullet lists, nested items and paragraphs, confined to the enclosing item's content indentation; plain file links retain existing behavior.
- Local file fragments match Markdown ATX headings1–6 using bundled markdown_inline structure for emphasis, code and inline-link label text. Both sides use the same key: lowercase/keep ASCII letters and digits, drop other ASCII and U+2000–U+206F/U+3000–U+303F, preserve every other non-ASCII codepoint unchanged.
- The first equal key answers the bare fragment and subsequent equal keys answer -1, -2, etc. A complete fragment key takes priority over duplicate-suffix interpretation, including natural numeric headings such as10-21-0040.
- Parser absence uses raw heading content through that key. Empty/unmatched keys and unsupported HTML/entity headings open the file at top with a notice. An exotic symbol outside the two punctuation ranges can cause a stripped GitHub fragment to miss visibly; exact GitHub slug reproduction is not required.
- Regression tests cover the reviewer's eight Markdown/duplicate cases, CJK and accented headings, em dashes/curly quotes, numeric precedence, missing parser, empty keys and unknown-anchor notices in real editor mappings.

## Plan

- [x] Add red headless regressions for tight/loose/nested bullet items and direct links; anchored headings with digits/parentheses/colons, unknown anchor and plain links.
- [x] Narrow navigation-only bullet ranges to the enclosing item, reusing fence/bounds context; keep editing ranges and numbered-item behavior intact (ARCH-DRY).
- [x] Split file/fragment before existing path resolution; ~~pure heading lookup uses GitHub-style slugs~~ parser-backed text uses the approved shared codepoint key (latest Revision), then the editor jumps only after confirmed destination arrival (ARCH-PURE, ARCH-ORDER).
- [x] Run mapped tests and recorded suite; update README/atlas.

Close review and normal landing follow verification. Per the hub, no stage: operator receives the landed change in normal use.

Actions: follow a link; retry/correct a missing heading. Found anchor: show destination heading. Unknown anchor: show file top plus short notice; correct the fragment and retry. Missing file: retain existing failure notice and source. No file bytes or durable navigation state are added; existing history owns navigation lifetime. Scans run only on Alt+O, linear in source lines plus destination heading bytes, not per edit. Reuse the existing occurrence scanner rather than parsing links twice; no new parser or background task.

## Log



- 2026-10-22: closed — Required recorded suite passed on6dddbafefbc497873df9f87147a9839c59b96082, attempt d4c3cbfb60b5dc221e3b92784ca6c6fa, exit0 in290.1445s, log SHA2563bd0f2ce93b36fae91335d82028b2476539bd27180dd995d1aaf64c95c79607d. Reviewer8 fail before replacement; actual bundled grammar heading33/33 passes after. Serial complete mapped navigation passes native54/range256/scanner22/heading33; native old-resolver counterfactual fails4 Unicode cases. Conformance1/docs4/lint818 clean; diff-check clean. Handwritten inline normalizer removed. Hub-approved codepoint key keeps/lowercases ASCII alnum, drops other ASCII plus U+2000–206F/U+3000–303F, preserves all other nonASCII unchanged; documented on both sides with full-fragment-first duplicate precedence and raw fallback when parser unavailable. HTML/entity scope excluded. No stage/live acceptance. Further review rule gap returns to hub rather than another patch. (done-when: contract moved since change-code; judged by the close review); review verdict: FIX-THEN-SHIP
- 2026-10-22: flow upgraded quick → full — 188 added lines in code files (limit 100); an earlier round of this close already ran the full review
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

### 2026-10-21 — Approved repair recorded as durable plan

Hub approved all three families and existing shared-consumer verification. The inline normalization makes the final patch likely to exceed the quick shell; preserve the already-approved design and remaining checks in workshop/plans/000407-alt-o-navigation-plan.md. This is one atomic close repair, not new milestone boundaries. The close gate upgrades its review as required.

- Repair evidence: BR-1 RED /tmp/parley407-heading-red.log (3 normalized-heading failures), then rendered-edge/autolink/comment RED /tmp/parley407-heading-inline-red.log (3), and literal-autolink underscore RED /tmp/parley407-heading-autolink-red.log (1). Final pure heading checks pass16/16, including duplicate slugs, code/escaped/intra-word/URL underscore controls, delimiter-aware anchor consumers and a counted malformed-tag scan budget.
- BR-2/3 RED /tmp/parley407-fences-red.log shows five false-closer memo failures and outside-link navigation across both dedented fence styles. GREEN /tmp/parley407-fences-green.log; shared consumers passed in /tmp/parley407-memo-consumers.log (highlight_structure, outline, outline_parity, picker_items, copy_fence and entity_textobj). Public is_fence_delim keeps its single length result; private geometry feeds the memo state. A scanner fixture previously called a fence with a link suffix a closer; added a genuine whitespace-only closer after that invalid candidate, preserving the hidden-link assertion.
- Infrastructure interruption, not assertion evidence: an overlapping same-checkout targeted make invoked orphan cleanup and SIGKILLed the active open_reference_spec PID69525. The exact reaping line is in /tmp/parley407-heading-inline-red.log and the matching Killed:9 line is in /tmp/parley407-rework-targeted2.log. Filed independent parley.nvim#409 unclaimed and reported it to the hub. All subsequent targeted checks run serially.
- Final serial mapped context/file_references passed (/tmp/parley407-rework-serial.log), including native30/30, range84/84, lexical10/10 and heading16/16. Final lint passed818 files with0warnings/errors (/tmp/parley407-rework-lint-final.log), and git diff --check passed. Durable plan tracks the repair; fresh recorded suite and re-close remain pending. No stage per hub direction.

- Corrected-head recorded suite passed on 053bf88b2b1a03d33a1c70d53cc1704c6ce6a062, attempt 61931a910072cb5f0afd04b1c306ef11, exit0 in289.04s, log SHA256 e817c0fe22944f47f182b5b90a45a5846a54e9e2d8e1febd989b9f84abbf5499. This is a complete fresh pass, not a flake resume or reuse of the pre-repair result. Re-close now reviews the complete repair and disposes BR-1/2/3; no stage per hub.

### 2026-10-21 — Round 2 REWORK and rule-level replan

BR-2 and BR-3 are addressed. BR-1 remains for quoted HTML attribute delimiters and character references; new BR-4 repeats the item-boundary family for outside headings1–6/empty/indented, walls and quotes. Durable plan now proposes one shared navigation block classifier with content indentation, and quote-aware HTML plus a complete finite character-reference decoder. No additional local patches proceed before hub approves the revised mechanism and bounded named-reference data artifact. Existing passing suite applies only to reviewed head2222dd74's executable ancestor053bf88b, not these pending corrections.

### 2026-10-21 — Narrowed heading scope approved; shared block rule retained

Hub delivery8887bf7d-ec9d-40df-8c27-89b898c13b51 rejects full HTML5 decoding and approves proceeding with Markdown ATX headings plus inline Markdown formatting only. Raw HTML headings/inline HTML and entity decoding are out of scope; document that limit and preserve unmatched-anchor fallback. The shared markdown_blocks/content-indentation repair remains approved. Durable plan retires the data-table proposal. This supersedes the pending decoder proposal above; no new artifact family is created.

- Narrowed-contract RED: /tmp/parley407-narrow-red.log; boundary RED: /tmp/parley407-boundary-red.log. Pure narrowed heading GREEN passed15/15 in /tmp/parley407-narrow-green.log. The first corrected mapping attempt was interrupted after exposing a fixture error: uncaught gf missing-file fallback prevented the completion signal; capture the known fallback exception while asserting source/history unchanged. This is fixture correction, not flake evidence. /tmp/parley407-narrow-mapped-green2.log then passed native48/48, range256/256, heading15/15 and document_move_plan51/51, but failed the existing scanner four-space quote continuation. Preserve scanner barrier indentation separately from navigation ownership metadata; rerun before claiming the corrected surface green.
- Residual BR-1 HTML/entity cases disputed through sdlc finding dispute under the hub's explicit scope Revision, with measured RED/GREEN controls. Critical remains blocking until the next reviewer withdraws it; no gate waiver.

- Final narrowed correction GREEN: make -k test-spec SPEC=context/file_references and a serial temporary-map document_move_plan consumer both exit0, /tmp/parley407-narrow-final.log (native48/48, range256/256, scanner22/22, heading15/15, move51/51 plus existing mapped tests). The scanner keeps its established up-to-three-literal-space wrapped-link barriers while navigation uses the same block classes relative to item content indentation. Native zero-candidate controls accept only existing gf E447 errors and still assert unchanged source/history. make -k lint passes818 files with0warnings/errors, /tmp/parley407-narrow-lint.log; git diff --check passes. Fresh recorded suite and re-close remain pending; no stage.

- Narrowed corrected-head recorded suite passed on 0f58fb2ebe5c8414088acf323969d9da7484a557, attempt aa7b70d092639e85051983e51eb972a5, exit0 in317.3249s; log SHA256862333076c811bfa93f74de3dca1b1ed74429e98feee9df9c48c9c592d768ff7. Exact queue endpoints are retained in the attempt. Fresh full pass, not a flake resume. Hub delivery f23e4ddf-6fbc-45e2-9727-8a3c8669a460 directs re-close, then hold merge until hub confirms machine-wide GitHub DNS recovery. No stage or live acceptance claimed.

### 2026-10-21 — Round 3 REWORK; parser-backed canonical matching direction

The full re-close returned REWORK before any codecomplete publication. BR-4, BR-2 and BR-3 are addressed; the HTML/entity exclusion is accepted, but BR-1 remains for eight in-scope emphasis/code/link-label and duplicate checks. Hub directs replacing the hand-written inline normalizer with bundled markdown_inline structure, canonical letter/digit matching for headings and fragments, numbered duplicates, and raw-text fallback when grammar is unavailable. Durable plan records that replacement architecture, actual grammar design probe and the two matching-rule details awaiting confirmation. No new production edits; no merge. Another gap in the next rule-level review goes back to the hub rather than another patch.

### 2026-10-21 — Unicode canonical-key revision approved

Hub delivery9b6945ae-2054-4378-80d9-ee793674c844 approves structural markdown_inline text extraction and canonical matching on both sides, with Unicode letters/digits retained rather than ASCII only. First occurrence uses the bare key, second -1, and full-fragment matching precedes duplicate-suffix fallback. Empty keys return the existing top+notice behavior. This supersedes exact GitHub slug reproduction; ATX1–6/fences and unsupported HTML/entity scope are unchanged. Reviewer8, Unicode/key/fallback controls are RED in /tmp/parley407-parser-rule-red.log before replacement. Durable plan records integration classification and Unicode API verification.

### 2026-10-21 — Final canonical-key rule, no Unicode data artifact

Hub deliveryee127634-4137-417c-9b63-998d982fe878 replaces the general Unicode-letter requirement: lowercase/keep ASCII letters and digits; remove other ASCII and U+2000–U+206F/U+3000–U+303F; preserve every other non-ASCII codepoint unchanged. Apply identically to heading text and fragment, retaining full-key-before-duplicate precedence. Non-ASCII case stays unchanged. Document this one-line rule and the exotic-symbol fragment miss fallback. No generated data/dependency or editor word classes. RED /tmp/parley407-parser-rule-red3.log exposes17 failures before implementation, including reviewer8 and CJK/accented/em-dash/curly-quote controls.

- Parser replacement implemented: deleted the handwritten inline normalizer; bundled markdown_inline source spans omit delimiter/destination/title nodes. Raw heading fallback covers parser error/nil root. Exact approved codepoint rule is documented in README/atlas; complete-fragment priority protects naturally numeric headings before duplicate fallback. Public heading lookup is now explicitly INTEGRATION, while level/range/fence contracts remain unchanged.
- RED/GREEN: /tmp/parley407-parser-rule-red3.log17 failures before replacement, /tmp/parley407-parser-rule-green.log33/33 after. Native counterfactual /tmp/parley407-native-rule-red.log fails4 Unicode mapping checks against the previous resolver; restored replacement passes full context/file_references mapping, /tmp/parley407-parser-mapped-green.log (native54, heading33, range256, scanner22 plus all mapped consumers). Heading dialect conformance1/1 passes. A mistaken unit documentation-spec path produced a load failure; corrected integration path passes4/4 in /tmp/parley407-parser-docs.log. Lint818 files0warnings/errors (/tmp/parley407-parser-lint.log), diff-check clean. Required fresh suite and full re-close remain pending; another rule gap from review goes to the hub, without another patch.

- Parser/key replacement recorded suite passed on6dddbafefbc497873df9f87147a9839c59b96082, attempt d4c3cbfb60b5dc221e3b92784ca6c6fa, exit0 in290.1445s; log SHA2563bd0f2ce93b36fae91335d82028b2476539bd27180dd995d1aaf64c95c79607d. Queued/acquired/finished endpoints retained; fresh full pass, not a flake resume. Full re-close now disposes BR-1 against the approved parser/codepoint rule. Any further rule gap from review returns to the hub before additional patching; no stage/live acceptance claimed.

### 2026-10-22 — FIX-THEN-SHIP prose synchronization

Round4 accepts all behavioral findings BR-1–4. Synchronize Done when with the already-approved parser/codepoint rule instead of the superseded exact-GitHub-slug wording (BR-5); no scope or executable change. Correct the atlas module label to distinguish PURE level detection from INTEGRATION anchor lookup (BR-6), and replace the plan's obsolete used-slug-set description with the implemented duplicate counter/deferred candidate. Existing33 heading/54 native tests and the fresh full suite supply behavioral evidence; these are prose fixes. Finalize the pending FIX-THEN-SHIP receipt, then normal merge; no stage.
