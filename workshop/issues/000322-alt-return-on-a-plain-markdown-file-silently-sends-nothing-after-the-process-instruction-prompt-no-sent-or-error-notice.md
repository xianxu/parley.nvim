---
id: 000322
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: 'e982489459a2f8006b78c461c3ef49cc31d9a866' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+Return on a plain markdown file silently sends nothing after the process-instruction prompt (no 'sent' or error notice)

## Problem

2026-10-14, the operator in ops:0's right pane: Alt+Return on `ops/teams/devinfra/qa/xian-xu/2026-10-14-01-following-operator-instructions.md` (plain markdown, no frontmatter) prompted for `process-instruction:`; the operator answered and nothing was sent. `:messages` shows only the file write ("… 25L, 1899B written"), no `review: sent to …` and no error. The file on disk had the operator's 🤖 comment but no `process-instruction:` line, so the flow stopped between `M.placement` (lua/parley/review_send.lua ~151–157) and `send_to_slot` (which saves first). Suspects: `couch.own_slot` returned `actors == nil` and fell into `run_via_invoke` (the outside-pair local review) silently, or its callback never fired; either way the operator got no signal.

## Spec

Every Alt+Return ends with exactly one visible outcome: `review: sent to <slot>`, a named error (cannot resolve this slot; couch unavailable; save failed), or, outside pair, an explicit "no slot: running the review here". Find the actual path on the operator's setup (ops:0's right pane, Couch with several hubs since pair#546) and fix the resolution if it's wrong there.

## Done when

- Reproduced with a test of the prompt → placement → resubmit path; each branch of `own_slot` notifies.
- In ops:0's right pane, Alt+Return on a plain markdown file reaches ops:0 (`review: sent to ops:0`).

## Plan

- [ ]

## Log

### 2026-10-14
