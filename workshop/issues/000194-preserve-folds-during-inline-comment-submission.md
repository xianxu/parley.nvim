---
id: 000194
status: working
deps: [193]
github_issue:
created: 2026-07-17
updated: 2026-07-17
estimate_hours:
started: 2026-07-17T11:07:51-07:00
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

- Replace or remove each resolved inline marker at its original bounded span.
  Apply multiple marker edits from the end of the buffer toward the beginning so
  earlier positions remain stable.
- Insert the formatted follow-up turn independently at the existing
  model/parser-derived exchange boundary. End-append and past-exchange branch
  submission must share the same bounded mutation mechanism (`ARCH-DRY`).
- Keep marker discovery and edit planning pure. The plan describes ordered,
  non-overlapping replacements and insertions; `buffer_edit` remains the thin
  Neovim mutation shell (`ARCH-PURE`).
- Do not use a whole-buffer replacement, clear/rebuild the fold tree, or
  snapshot/recreate user folds. Unchanged questions, answers, thinking,
  summaries, tool blocks, and manual folds must never fall inside a submitted
  edit range (`ARCH-PURPOSE`).
- If a marker itself lies inside a folded semantic block, editing that marker's
  exact span is allowed to affect that overlapping fold. This exception does
  not extend to other lines in the block or unrelated folds.

The resulting serialized chat and API payload must remain equivalent to the
current drill-in behavior: markers collapse to their bracketed/plain anchor,
formatted quote/question blocks appear in the new user turn, and branching
still excludes later exchanges from the request context.

## Done when

- [ ] Submitting an inline comment preserves a previously closed one-line
      summary fold and its gutter marker.
- [ ] Submission creates no fold ranges inside an unchanged question or answer.
- [ ] Unrelated user-created manual folds retain their exact ranges and closed
      state through both end-append and past-exchange branch submission.
- [ ] Marker removal/replacement and new-turn insertion use bounded edits; the
      production submission paths never call `replace_all_lines`.
- [ ] Existing drill-in serialized output, request targeting, and payload tests
      remain unchanged.
- [ ] Automated pure tests cover ordered edit planning and real Neovim
      integration tests cover the reported fold-loss/fold-migration behavior.

## Plan

- [ ] Add a pure bounded drill-in edit plan with multi-marker ordering tests.
- [ ] Apply the plan through narrow `buffer_edit` operations in both submission
      paths.
- [ ] Add real Neovim regressions for summary and unrelated manual folds.
- [ ] Update lifecycle documentation and run mapped/full verification.

## Log

### 2026-07-17

Created from the operator's smoke-test report after #193. Root-cause tracing
found both drill-in submission paths reconstruct the full line array and pass it
to `replace_all_lines`, allowing Neovim to invalidate or migrate unrelated
manual folds. Approved direction: pure bounded edit planning plus narrow buffer
application; no fold snapshot/rebuild workaround.
