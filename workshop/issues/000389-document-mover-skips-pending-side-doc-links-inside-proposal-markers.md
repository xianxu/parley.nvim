---
id: 000389
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '95801f015aeddf8fac54f60aad0a84d09f573c6e' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T12:21:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "ae4ba6ed", done: "86c723f3"}
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

- [ ] Pin single-backslash pending-link failure plus the issue's literal double-backslash spelling; preserve marker bytes and reject escaped prose/code examples.
- [ ] Give the mover's existing Markdown span/rewrite path a narrow proposal-link exception, preserving byte coordinates, code masks and destination validation (ARCH-DRY, ARCH-PURE). Limit recognition to complete same-line robot insertion proposals carrying a side-doc link; do not broaden navigation parsing.
- [ ] Verify parent index, moved side folder, child backlink and resolving pending link through a native filesystem migration fixture; run focused tests, required suite, close and normal landing.

## Log

- Filed from ariadne#437 close-review follow-up on 2026-10-18. Pair live conformance provided the exact marker bytes; ariadne's shared side-doc parser is being updated there. This Parley follow-up does not block #437.

- Claimed after the card showed no owner; start-plan refreshed the ariadne tool build and was rerun as directed. Read-only probe `/tmp/parley389-probe.lua` confirms one literal backslash before each bracket is skipped; the issue's literal two-backslash spelling already rewrites because the existing escaped predicate counts parity. Pin both byte spellings without changing existing two-backslash behavior. The implementation will preserve all marker bytes and change only destination spans. No new state, recovery action or filesystem effect; existing leased migration/CAS/retry protocol stays authoritative. Existing scan bounds remain; add one linear per-line proposal recognition pass, no per-link suffix rescans.
