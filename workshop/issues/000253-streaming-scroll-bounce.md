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

- [ ] Add failing attached-UI regressions for fold view and wrapped-tip following.
- [ ] Preserve maintenance view and follow real text endpoint; update atlas.
- [ ] Verify real UI behavior, test suites and close through fresh review.

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
