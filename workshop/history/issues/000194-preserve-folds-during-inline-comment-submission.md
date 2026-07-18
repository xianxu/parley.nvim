---
id: 000194
status: done
deps: [193]
github_issue:
created: 2026-07-17
updated: 2026-07-17
estimate_hours: 2.5
started: 2026-07-17T11:07:51-07:00
actual_hours: 1.03
---

# Preserve folds during inline-comment submission

## Problem

Submitting a ready inline comment/drill-in rewrites the entire chat buffer via
`buffer_edit.replace_all_lines`. Neovim treats that operation as one replacement
covering every manual fold. Existing summary folds may disappear, while other
fold ranges can migrate into question text and leave incorrect gutter markers.

This regresses #193's invariant that fold updates and chat mutations must not
disturb unrelated completed semantic blocks or user-created folds.

## Spec

Inline-comment submission must mutate only the text it logically changes:

- Plan every marker/anchor transformation as a bounded byte edit in original-
  buffer coordinates: marker replacement/removal, explicit-anchor replacement,
  and inferred-anchor bracket insertion. No edit may include unchanged text
  merely to simplify application.
- The pure planner emits a deterministic normalized list of non-overlapping
  edits. It must merge or suppress interacting inferred-anchor and neighboring
  marker/anchor candidates without duplicating brackets or losing a marker;
  tests define those conflict semantics. Apply edits from the end of the buffer
  toward the beginning so earlier coordinates remain stable.
- Share the bounded byte-edit representation and applicator for marker/anchor
  transformation between both paths (`ARCH-DRY`). Destination mutation remains
  path-specific and uses narrow `buffer_edit` line operations: end submission
  appends formatted blocks within the existing final unanswered user turn and
  preserves trailing-blank normalization; past-exchange branching inserts a new
  prefixed user turn at the parser/model-derived boundary.
- Keep marker discovery and edit planning pure. The plan describes ordered,
  non-overlapping replacements and insertions; `buffer_edit` remains the thin
  Neovim mutation shell (`ARCH-PURE`).
- Do not use a whole-buffer replacement, clear/rebuild the fold tree, or
  snapshot/recreate user folds. Unchanged questions, answers, thinking,
  summaries, tool blocks, and manual folds must never fall inside a submitted
  edit range (`ARCH-PURPOSE`).
- If a marker or explicit/inferred anchor edit overlaps a folded semantic block,
  only that exact edit span may affect the overlapping fold. This exception does
  not extend to unrelated text or folds.

The resulting serialized chat and API payload must remain equivalent to the
current drill-in behavior: markers collapse to their bracketed/plain anchor,
end submission extends the existing unanswered user turn, branch submission
creates a new turn, and branching still excludes later exchanges from the
request context.

## Done when

- [x] Submitting an inline comment preserves a previously closed one-line
      summary fold and its gutter marker.
- [x] Submission creates no fold ranges inside an unchanged question or answer.
- [x] Unrelated user-created manual folds retain the same covered logical text
      and closed state through both paths. Ranges before an edit remain
      numerically unchanged; ranges after an insertion/replacement shift only by
      that edit's line-count delta.
- [x] Marker removal/replacement and new-turn insertion use bounded edits; the
      production submission paths never call `replace_all_lines`.
- [x] Existing drill-in serialization, request-targeting, and payload assertions
      pass without expectation changes; added end and branch assertions prove
      the serialized buffer and dispatched payload retain pre-change behavior.
- [x] Automated pure tests cover ordered edit planning, including nearby
      unquoted markers with interacting inferred source regions. Real Neovim
      integration tests cover the reported fold-loss/fold-migration behavior.

## Plan

- [x] Add a pure bounded drill-in edit plan with multi-marker ordering tests.
- [x] Apply the plan through narrow `buffer_edit` operations in both submission
      paths.
- [x] Add real Neovim regressions for summary and unrelated manual folds.
- [x] Update lifecycle documentation and run mapped/full verification.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.25 impl=0.02
item: lua-neovim design=0.5 impl=0.4
item: lua-neovim design=0.3 impl=0.4
item: lua-neovim design=0.12 impl=0.25
item: atlas-docs design=0.03 impl=0.02
item: milestone-review design=0.0 impl=0.15
design-buffer: 0.06
total: 2.5
```

Derived against `estimate-logic-v3.1.md`. The existing drill-in parser already
computes absolute byte spans and the buffer mutation shell is established; the
remaining uncertainty is normalization of interacting inferred-anchor edits and
Neovim fold behavior across multi-edit application.

## Log

### 2026-07-17
- 2026-07-17: closed — User smoke-tested inline-comment submission successfully. Fresh verification: make test JOBS=1 passed all unit, integration, and architecture tests; make test-changed passed all mapped changed specs; git diff --check passed; working tree was clean. Parallel make test exposed a pre-existing test race where tools_builtin_find_spec traverses concurrently deleted .test-tmp directories; the exact spec passed 4/4 and the full serial suite passed.; review verdict: FIX-THEN-SHIP

Created from the operator's smoke-test report after #193. Root-cause tracing
found both drill-in submission paths reconstruct the full line array and pass it
to `replace_all_lines`, allowing Neovim to invalidate or migrate unrelated
manual folds. Approved direction: pure bounded edit planning plus narrow buffer
application; no fold snapshot/rebuild workaround.

Fresh spec review clarified that anchor bracketing is itself a bounded edit,
that folds after an insertion must shift with their logical text, and that end
submission appends within an existing turn while branching inserts a new turn.
It also required deterministic normalization for interacting inferred anchors.

Fresh plan review replaced ambiguous inclusive edit coordinates with a
half-open contract, required exact conflict precedence and EOF placement, and
expanded the real-window regression to prove both logical fold coverage and the
rendered gutter marker. Estimate revised from 1.8h to 2.5h after correcting the
arithmetic and accounting for those boundary cases.

Implemented normalized half-open marker/anchor edit plans and a validating
bottom-to-top Neovim adapter, then replaced both drill-in whole-buffer rewrites
with bounded marker edits plus path-specific narrow destination operations.
Production regressions prove a closed one-line summary retains its gutter fold,
a later user fold shifts with its logical text, and no fold migrates into an
unchanged question (`ARCH-DRY`, `ARCH-PURE`, `ARCH-PURPOSE`).

TDD evidence: `drill_in_spec.lua` failed 5 new cases before
`gather_edit_plan`, then passed 113/113; `buffer_edit_spec.lua` failed before
`apply_text_edits`, then passed 23/23; `chat_respond_spec.lua` failed both new
paths on the `replace_all_lines` sentinel, then passed 63/63. `make test-spec
SPEC=chat/drill_in`, `make test`, `make test-changed`, and `git diff --check`
all passed. A transient real-process fixture port failure passed on exact rerun
and the subsequent full suite.
