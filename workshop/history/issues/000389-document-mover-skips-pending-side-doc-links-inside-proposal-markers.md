---
id: 000389
status: done
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'b91872e8dc1b3f70d25316a0ab9fcebe75abdab9' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T12:21:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "ae4ba6ed", done: "86c723f3"}
actual_hours: 0.08
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

- [x] Pin single-backslash pending-link failure plus the issue's literal double-backslash spelling; preserve marker bytes and reject escaped prose/code examples.
- [x] Give the mover's existing Markdown span/rewrite path a narrow proposal-link exception, preserving byte coordinates, code masks and destination validation (ARCH-DRY, ARCH-PURE). Limit recognition to complete same-line robot insertion proposals carrying a side-doc link; do not broaden navigation parsing.
- [x] Verify parent index, moved side folder, child backlink and resolving pending link through a native filesystem migration fixture; run focused tests and the required suite.

Close review and normal landing follow these implementation checks.

## Log


- 2026-10-18: closed — Pending one-backslash Pair proposal links now move with their discussions index, side folder and child backlink; exact marker bytes remain intact and the link resolves. Double-backslash spelling remains supported; escaped prose,inline/fenced code and malformed marker examples stay unchanged. Focused78 migration+51 projection cases pass; counted8/16-link scan stays one pass. Required suite on470b5df5de1d350bb619e0728f120f2b75b3f9c4 exit0:479 unique spec paths pass,803 lint files clean,no survivors; retained suite.log SHA2560bdd051bd951b474ca0818dd500c87bb16900bccde0f3d41154108c45e5b47a9. Current code differs only by committed evidence prose; atlas updated. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- Filed from ariadne#437 close-review follow-up on 2026-10-18. Pair live conformance provided the exact marker bytes; ariadne's shared side-doc parser is being updated there. This Parley follow-up does not block #437.

- Claimed after the card showed no owner; start-plan refreshed the ariadne tool build and was rerun as directed. Read-only probe `/tmp/parley389-probe.lua` confirms one literal backslash before each bracket is skipped; the issue's literal two-backslash spelling already rewrites because the existing escaped predicate counts parity. Pin both byte spellings without changing existing two-backslash behavior. The implementation will preserve all marker bytes and change only destination spans. No new state, recovery action or filesystem effect; existing leased migration/CAS/retry protocol stays authoritative. Existing scan bounds remain; add one linear per-line proposal recognition pass, no per-link suffix rescans.

- RED `/tmp/parley389-red.log` reproduced the single-backslash unit and actual filesystem-move failure: the discussions index changed while the proposal destination remained old. The issue's double-backslash spelling already passed. An extra human-comment-chain negative initially failed against existing Markdown behavior; removed that out-of-scope assertion rather than changing comment-chain navigation semantics. The first GREEN attempt found a Lua pattern string escaping error (retained `/tmp/parley389-green.log`); corrected with a literal long-bracket pattern. Final `/tmp/parley389-final-green.log` passes78 migration +51 pure projection cases, zero failures/errors, no surviving processes. Includes destination-only marker preservation for single/double spelling and proposal/discussion labels, CRLF/fragments/idempotence, native index/folder/backlink/resolution, unchanged escaped prose/inline/fenced/malformed examples, and a counted8/16-link check that the shared scanner receives the document once. Three-file luacheck and whitespace checks pass.
- Implemented25 added/changed production lines in the existing pure mover module: recognize complete one-line insertion-link openers, admit their existing Markdown destination span through the escape guard, retain fence/code masks and path validation. Only side-folder references enable this; ordinary navigation and child-parent parsing stay on their existing rules. Atlas updated. Required suite and close review follow on the pushed source head.

- Required suite passed on `470b5df5de1d350bb619e0728f120f2b75b3f9c4` (exit0,4m53s): all479 unique spec paths pass (958 PASS records),803 lint files clean, no surviving processes. Retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/470b5df5de1d350bb619e0728f120f2b75b3f9c4/suite.log`, SHA256 `0bdd051bd951b474ca0818dd500c87bb16900bccde0f3d41154108c45e5b47a9`. Hub directed close and normal landing without a separate staging hold (submitted receipt39689127-cae7-444d-ae9c-80edd93d185f).

## Revisions

### 2026-10-18 — Keep workflow gates after implementation checks

The third plan checkbox combined native verification and the suite with future close/landing gates. Separate those gates into follow-on prose so the pre-close checklist records completed verification honestly; no scope or implementation change.
