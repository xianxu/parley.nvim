---
id: 000253
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.83
started: 2026-09-14T13:32:30-07:00
---

# Streaming fold updates bounce the viewport during scrolling

## Problem

Mouse-wheel scrolling toward the streaming tip sometimes bounces back until generation finishes. Reproduced in an attached Neovim UI: fold maintenance changes cursor170/topline160 to170/157, and a second split105to97, even without cursor-follow. Plain headless tests miss this redraw behavior. Separately, smoothscroll plus a long wrapped pending line reaches col2960/skipcol2880 by wheel, then next token resets col0/skipcol0.

## Spec

Fold maintenance must preserve each window’s complete view without undoing deliberate cursor movement during stream writes. Cursor-follow should target the actual end of generated text, including a long wrapped line, rather than its first column. Follow disabled remains free scrolling; existing global toggle/explicit override precedence is unchanged. Apply the same stream-tip endpoint on completion to avoid a last-token jump. Do not introduce wheel mappings, automatic follow policy or persistent state.

## Done when

- Attached-UI regressions preserve topline/cursor per split through fold maintenance and allow intentional follow movement during mutation.
- Real wheel/long wrapped-line streaming remains at the tip when follow enabled, and preserves manual view when follow disabled; completion does not reset to column zero.
- Error-path cleanup preserves view; affected suites, lint and starter-profile reproduction pass.


## Plan

- [x] Add failing attached-UI regressions for fold view and wrapped-tip following.
- [x] Preserve maintenance view and follow real text endpoint; update atlas.
- [x] Verify real UI behavior and test suites; submit close through fresh review.

## Log

### 2026-09-14


Reproduction scripts: /tmp/parley-fold-ui-repro.lua, /tmp/parley-fold-ui-multi.lua, /tmp/parley253-wrap-smooth-repro.lua. Independent experiment adding winsaveview/winrestview only around clear_folds_in_span fixes the split drift and preserves explicit follow within mutation. No production files changed during diagnosis.

## Estimate

Derived after plan approval: Lua/Neovim design 1h × 0.2 = 0.2h; implementation and attached-UI verification 1.25h × 0.4 = 0.5h; boundary review 0.25h × 0.4 = 0.1h; design buffer 15% adds 0.03h.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.2 impl=0.5
item: milestone-review design=0 impl=0.1
design-buffer: 0.15
total: 0.83
```

### Implementation evidence

Plan-quality round3 CLEAN. Estimate-quality INFO: budget includes already-completed design/reproduction plus implementation, native UI verification and boundary review; no fan-out discount. Added shared pure query endpoint projection (ARCH-DRY/PURE), optional byte-column placement and matching completion endpoint. Fold clear now preserves view and foldenable around only its own walk, including exceptions, retaining intentional follow movements.

Six native attached-UI fold regressions failed before the patch and pass after; completion regression failed with column0 and passes with the endpoint. Additional actual dispatcher/native-wheel cases cover visible-bottom crossing, wrapped text, free scrolling, prefix/multibyte/newline endpoints and helper guards. `make test-spec SPEC=chat/exchange_model` passed. Full suite and isolated starter smoke in progress.

Isolated actual starter smoke passed without a second setup(): default follow=true, wrap/linebreak enabled; 3500-byte paragraph ends at screen row22 of24 in Normal mode, appended text remains visible in Insert mode without leaving Insert. Two split views and intentional mutation movement preserved. Scripts: /tmp/parley253-starter-runner.py and /tmp/parley253-starter-ui-probe.lua.

Initial full run: all behavior tests passed; fresh_clone required staging new module and single_source_sweeps required exact function names in plan inventory. Both corrected before the rerun.

Verification complete: full suite rerun passed258 of259 spec files; remaining single_source_sweeps required additions in the first Core concepts table (its parser ignores revision tables). Corrected table and reran that spec:21/21 pass. Thus all259 files pass across full + targeted rerun; luacheck451 files,0 warnings/errors. No runtime changes after full run. Actual app UI smoke passed Normal/Insert and split-view cases.
