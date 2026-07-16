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
readiness/swap failures. The clean local full suite passed before and after this
review, including that integration spec.

## Review 3 — REWORK

Critical: Vision's pre-#189 settled title `Vision (N initiatives)` regressed to
the permanent loading-shell title `Vision`, contrary to the explicit title
compatibility requirement. Resolved by adding an optional materialized title to
the shared loader/picker settlement bridge and returning the counted Vision
title for both empty and nonempty outcomes (`ARCH-PURPOSE`; other principles
passed).

## Evidence

- `finder_loader_spec.lua`: 10 successes, 0 failures.
- `float_picker_spec.lua`: 72 successes, 0 failures.
- `vision_finder_spec.lua`: 9 successes, 0 failures, including empty/nonempty
  settled title checks.
- `make test-changed`: exit 0.
- `make lint`: zero warnings/errors across 301 files.
- `make test`: exit 0; every unit, architecture, and integration spec PASS,
  including `chat_progress_process_spec.lua`.
- `git diff --check`: clean.
