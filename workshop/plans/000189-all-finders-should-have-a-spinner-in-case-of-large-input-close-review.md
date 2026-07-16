# #189 close reviews

- Review window: `925c046..HEAD`
- Reviewer: SDLC-dispatched fresh-context Codex

## Review 1 — REWORK

Two Critical ownership findings:

1. Issue Finder released `_issue_finder.opened` immediately after launch,
   permitting duplicate pickers during loading or after settlement.
2. Async enrichment relinquished descriptor ownership before a queued close
   started, so queue cancellation could discard the only cleanup operation.

Resolution: retain the picker guard until selection/cancellation/action-owned
reopen, and retain descriptors until close work actually starts. Focused tests
pin both windows. `ARCH-PURE` and `ARCH-PURPOSE` were flagged; `ARCH-DRY` passed.

## Review 2 — REWORK

One Critical shared-picker finding:

1. Action-only Chat/Note recency and Issue view mappings received raw
   `close_all` while `scanning…` was active. Closing and reopening bypassed the
   loader's cancellation-aware dismissal, leaving the first subscription or
   picker-owned acquisition alive.

Resolution: `float_picker` now supplies cancellation-aware `dismiss` as the
mapping close callback only while a status row is active; settled action
mappings retain raw action-owned teardown. A direct picker regression plus real
delayed-acquisition Chat, Note, and Issue mapping tests prove exactly one old
scan is canceled before one replacement scan opens, then clean up the replacement.
`ARCH-PURPOSE` was flagged; `ARCH-DRY` and `ARCH-PURE` passed.

The reviewer also saw unrelated `chat_progress_process_spec.lua` readiness/swap
failures in its sandbox. The implementor's clean local `make test` had passed
before the review; full verification is refreshed after each accepted fix.

## Evidence

- `float_picker_spec.lua`: 71 successes, 0 failures.
- `chat_finder_logic_spec.lua`: 48 successes, 0 failures.
- `note_finder_logic_spec.lua`: 36 successes, 0 failures.
- `issue_finder_spec.lua`: 28 successes, 0 failures.
- `make test-changed`: exit 0.
- `make lint`: zero warnings/errors across 301 files.
- `make test`: exit 0; every unit, architecture, and integration spec PASS,
  including `chat_progress_process_spec.lua`.
- `git diff --check`: clean.
