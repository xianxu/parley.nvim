---
id: 000322
status: wontfix
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-15
estimate_hours:
card_mirror: 'd56be9bc35ab53437810cc616f9baee33d34518c' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+Return on a plain markdown file silently sends nothing after the process-instruction prompt (no 'sent' or error notice)

## Problem

2026-10-14, the operator in ops:0's right pane: Alt+Return on `ops/teams/devinfra/qa/xian-xu/2026-10-14-01-following-operator-instructions.md` (plain markdown, no frontmatter) prompted for `process-instruction:`; the operator answered and nothing was sent. `:messages` shows only the file write ("… 25L, 1899B written"), no `review: sent to …` and no error. The file on disk had the operator's 🤖 comment but no `process-instruction:` line, so the flow stopped between `M.placement` (lua/parley/review_send.lua ~151–157) and `send_to_slot` (which saves first). Suspects: `couch.own_slot` returned `actors == nil` and fell into `run_via_invoke` (the outside-pair local review) silently, or its callback never fired; either way the operator got no signal.

## Spec

Covered by #332: Couch-pane Alt+Return saves, registers and submits named Markdown without prompting for process instructions; it shows completed submission owner/time or an explicit visible error. No separate implementation remains on this duplicate card.

Every Alt+Return ends with exactly one visible outcome: `review: sent to <slot>`, a named error (cannot resolve this slot; couch unavailable; save failed), or, outside pair, an explicit "no slot: running the review here". Find the actual path on the operator's setup (ops:0's right pane, Couch with several hubs since pair#546) and fix the resolution if it's wrong there.

## Done when

The parent #332 owns implementation, verification, review, staging/live acceptance and landing. This duplicate is closed as superseded; it does not claim the parent has landed.

- Reproduced with a test of the prompt → placement → resubmit path; each branch of `own_slot` notifies.
- In ops:0's right pane, Alt+Return on a plain markdown file reaches ops:0 (`review: sent to ops:0`).

## Plan

- [ ]

## Log

- 2026-10-15 — operator requested folding this into #332. Its feedback implementation passes18 production-door admission cases and64 native edit cases, including first-submit success and pre-attachment/attached error visibility. Close this duplicate as superseded by #332; remaining suite, review and operator acceptance stay on the parent.

### 2026-10-14

## Revisions

### 2026-10-15 — Superseded by #332 at operator request

The requested Couch-pane workflow now uses save→register→submit rather than the original process-instruction prompt→placement→resubmit route. #332 owns visible owner/time success and visible errors, plus the remaining combined live check. Preserve the original report and acceptance text as evidence; close this card as a superseded duplicate, not as a claim that its original prompt route or outside-pane flow was newly implemented.
