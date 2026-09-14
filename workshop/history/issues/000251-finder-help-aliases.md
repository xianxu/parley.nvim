---
id: 000251
status: done
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.98
started: 2026-09-14T10:53:58-07:00
actual_hours: 0.60
---

# Align shortcut help with finder controls and aliases

## Problem

Help audit found stale branch wording, missing prompt navigation controls, and finder aliases advertised but not installed. A configured Chat Finder delete list `{ "<F8>", "<F9>" }` displays both but binds only F8.

## Spec

Update Alt+i wording to create/open a sub-chat. Include prompt navigation, selection, and cancellation in finder help. Keep configuration-aware registry output; consume all resolved aliases when installing picker mappings, including help bindings. Preserve primary-only display for compact titles. Chat, Note, and Issue Finder share this contract. Disabled entries remain unbound; reserved confirmation/cancellation keys remain protected.

## Done when

- Help describes current branch behavior and includes finder prompt basics.
- Every configured picker alias is installed and dispatches its action; disabling hides and unbinds it.
- Default string mappings and reserved-key protection remain compatible.
- Focused regressions, exact starter override smoke, full tests and lint pass.

## Estimate

Method estimate-logic-v3.1, provisional repo calibration. Familiar Lua/Neovim stack: design 2h × 0.2 resolved-scope factor = 0.4h; implementation 1h × 0.4 = 0.4h (shared alias installer plus mechanical consumers and tests); review 0.3h × 0.4 = 0.12h. 15% design buffer.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.4
item: milestone-review design=0 impl=0.12
design-buffer: 0.15
total: 0.98
```

## Plan

- [x] Implement the approved audit corrections following workshop/plans/000251-finder-help-aliases-plan.md.
- [x] Verify configured/default mappings, update atlas, and close through fresh review.

## Log

### 2026-09-14
- 2026-09-14: closed — 75 help tests and 80 picker tests pass; native exact-starter F8/F9 aliases both confirm/cancel. Full run passed 255 specs and lint; sole plan-table check corrected and its 21-test spec passes on rerun. All 256 specs verified. Atlas updated.; review verdict: SHIP

- User approved updates after audit. Native starter probe confirmed F8/F9 help versus F8-only mapping. No new product choice requires clarification; implementation follows the requested corrections.

- Plan review PQ-1/PQ-2/PQ-3 addressed: explicit per-function adversarial inputs and effective mapping oracles, alias-count expectations, and preserved lifecycle/collision behavior. Plan passed round 2. Estimate design allowance includes audit and planning already performed; implementation allowance includes docs, verification, and PR publication, with full test execution mostly unattended.
- Registry/help tests: 70 existing passed and 5 new failed before changes; all 75 now pass. Picker alias/empty/reserved-list test failed before changes; all 80 picker tests now pass, including dispatch via prompt i/n and results n mappings.
- Exact starter smoke passes: remapped help key and disabled branch entry reflected; both F8 and F9 delete aliases invoke native confirmation, cancellation preserves the temporary chat. /tmp/parley251-native.log, runner /tmp/parley251-help-runner.py.

- Full suite: 255 spec files passed and lint reported 0 warnings/errors in 447 files. The sole failure was the plan/entity documentation check for keys_for; after adding its exact exported name to the core-concepts table, all 21 checks in that final spec pass. Logs: /tmp/parley251-full.log and /tmp/parley251-arch-green.log. All 256 spec files are now verified across that run and the focused rerun; no production changes followed the suite.
- Updated atlas/ui/keybindings.md for picker aliases, fixed prompt controls, and the boundary between Parley configuration and arbitrary external remaps.
