# #189 close reviews

- Review window: `925c046..HEAD`
- Reviewer: SDLC-dispatched fresh-context Codex

## Review 1 — REWORK

Critical: Issue Finder released its open guard immediately after launch, and
async enrichment relinquished descriptor ownership before queued close work
started. Resolved by retaining each owner through its actual terminal boundary,
with duplicate-picker and saturated queued-close regressions (`ARCH-PURE`,
`ARCH-PURPOSE`; `ARCH-DRY` passed).

## Review 2 — REWORK

Critical: action-only Chat/Note recency and Issue view mappings received raw UI
teardown during `scanning…`, bypassing loader cancellation before reopening.
Resolved once in `float_picker`: mappings receive cancellation-aware dismissal
only while status is active and raw action teardown after settlement. Direct
picker plus real delayed Chat/Note/Issue regressions prove exactly one old scan
cancels before one replacement opens (`ARCH-PURPOSE`; other principles passed).

The reviewer also saw unrelated `chat_progress_process_spec.lua` sandbox
readiness/swap failures. Clean local full-suite runs passed before and after the
review, including that integration spec.

## Review 3 — REWORK

Critical: Vision's pre-#189 settled title `Vision (N initiatives)` regressed to
the permanent loading-shell title `Vision`, contrary to the explicit title
compatibility requirement. Resolved by adding an optional materialized title to
the shared loader/picker settlement bridge and returning the counted Vision
title for both empty and nonempty outcomes (`ARCH-PURPOSE`; other principles
passed).

## Review 4 — REWORK

Critical: Issue and Vision compared native IO paths after their primary fields,
preventing the shared sorter from applying the all-five canonical
`identity.key` tie-break promised by the Spec. Resolved by making their local
comparators express primary ordering only and defer ties to `finder_scan.sort`.
Adversarial regressions use native paths and canonical identities in opposite
orders (`ARCH-DRY`, `ARCH-PURPOSE`).

Critical: the plan's Core concepts table used conceptual type names rather than
greppable code entities. Resolved by naming the exact exported module entry
points, including `finder_scan.snapshot`, `finder_scan.path_identity`,
`finder_loader.new_session`, and each record module's adaptation/materialization
functions.

## Evidence

- `issue_finder_records_spec.lua`: 8 successes, 0 failures, including the
  adversarial canonical/native ordering regression.
- `vision_finder_records_spec.lua`: 8 successes, 0 failures, including the
  adversarial canonical/native ordering regression.
- Earlier review fixes: `finder_loader_spec.lua` 10/10,
  `float_picker_spec.lua` 72/72, and `vision_finder_spec.lua` 9/9.
- Full verification is refreshed before each close invocation and recorded in
  the issue Log.
