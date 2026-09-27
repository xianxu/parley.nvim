---
id: 000286
status: done
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
started: 2026-09-26T18:14:37-07:00
flow: {kind: quick, provenance: inferred, spec: "f9d917a7", done: "94a22b16"}
actual_hours: 0.00
---

# remove redundant starter welcome notification

## Problem

## Spec

When the starter opens the default `welcome.md`, do not show a duplicate
notification overlay. The welcome chat remains the onboarding source of truth.

## Done when

- A no-argument starter launch opens `welcome.md` without the redundant welcome notification.
- Startup continues to seed the edited multi-exchange tutorials; the stacked
  launcher, shortcuts, and response lifecycle pass their focused suites before
  the accumulated completed issues are landed.

## Plan

- [x] Remove the duplicate notification and keep starter onboarding intact.

## Core concepts

The landing review includes the stacked #280 and #285 changes; these entries
record their public surface for the branch-wide architecture check.

| Entity | Kind | Location | Status |
|---|---|---|---|
| `create_child_chat` | INTEGRATION | `lua/parley/init.lua` | modified |
| `set_pending_previous_answer` | INTEGRATION | `lua/parley/document/init.lua` | new |
| `clear_pending_previous_answer` | INTEGRATION | `lua/parley/document/init.lua` | new |

## Log

### 2026-09-26

- Boundary follow-up: an isolated tracked worktree at 241ca4f0 passes all 183
  starter cases with process inspection enabled and no surviving test processes
  (`/tmp/parley-final-starter.log`). The concurrent welcome-creator case passes;
  the review's repair failure was not reproduced in this environment. Earlier
  root execution also passed 183/183 with a clean census. README now documents
  the private-note shortcut and pruning migration.

- Closure verification: all 183 starter and 302 shortcut-slice cases pass;
  eight local launcher cases pass. Startup asserts the welcome buffer opens
  without the redundant notification. The tutorial probe now accepts the
  operator's multi-exchange examples while still requiring a practice question.

## Revisions

- 2026-09-26: User requested closing and landing the accumulated completed work.
  Record the stacked branch surface and add a startup regression asserting both
  the welcome buffer and absence of the duplicate notification (ARCH-PURPOSE).

## Manual shipment — 2026-09-26

Closed and archived at the operator’s explicit direction as part of the completed local stack. Prior SDLC review records remain historical; no new gate verdict is claimed.

Final findings resolved: startup opens welcome.md without the duplicate prompt; isolated starter and shortcut suites passed with process census enabled. The sole full-suite performance timeout passed on its isolated rerun.

Final verification: lint passed all 656 Lua files; `make test` passed 391 spec files, with the remaining performance spec passing all three cases on a standalone normal-harness rerun. Both runs ended with no surviving test processes. Startup also passed 183 cases in a tracked isolated checkout.
Actual hours adopt the measured value printed by the preceding SDLC close attempt.
