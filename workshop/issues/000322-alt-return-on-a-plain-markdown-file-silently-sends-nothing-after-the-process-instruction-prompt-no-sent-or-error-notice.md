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

~~Covered by #332: Couch-pane Alt+Return saves, registers and submits named Markdown without prompting for process instructions; it shows completed submission owner/time or an explicit visible error. No separate implementation remains on this duplicate card.~~ Superseded by the 2026-10-23 combined #418/#322 dispatch below.

Every Alt+Return ends with a visible outcome: confirmed sent owner/time, an explicit unchanged/no-work/cancel result, a named refusal/error, or the existing submitting/not-confirmed state with its retry action. Outside Couch, identify local review explicitly. Preserve save→register→submit in a valid pane, never silently fall back to local processing after actor lookup fails. The [shared #418 plan](../plans/000418-first-submit-frontmatter-plan.md) covers first-submit front matter preparation plus this issue's visible-outcome acceptance; the deprecated required process-instruction prompt is not a route to recreate.

## Done when

~~The parent #332 owns implementation, verification, review, staging/live acceptance and landing. This duplicate is closed as superseded; it does not claim the parent has landed.~~ Reopened under the 2026-10-23 TL dispatch; the following acceptance belongs to this card.

- Native mapping tests prove plain Markdown in a valid Couch pane is prepared, saved, registered and submitted exactly once to that pane's owner, with visible confirmed owner/time feedback.
- Owner resolution, edit/save/metadata failure, pending lookup, deadline/late reply, duplicate press and outside-Couch local/no-work/cancel paths all expose their actual result; failed/uncertain work cannot silently claim sent or reroute locally.
- In ops:0's right pane, a hub-coordinated live Alt+Return on plain and partial Markdown reaches ops:0 and shows the corresponding visible result. Both supported Neovim runtimes pass affected automated coverage.

## Plan

- [ ] Implement and verify the visible-outcome portion of the [shared #418 plan](../plans/000418-first-submit-frontmatter-plan.md), retaining the original incident as historical evidence.
- [ ] Complete this card's separate automated/live acceptance and binary-owned close/landing evidence with #418.

## Log

### 2026-10-23 — reopened with #418 by TL assignment

Authenticated dispatch 24886cea-c7ae-4329-a81f-ec5c69c35332 explicitly assigns this card with #418. `sdlc claim --issue 322` correctly refused its wontfix status; `sdlc issue set-status working --issue 322` reopened and claimed it through the legal lifecycle edge. Planning occurs on #418's main-based branch per the explicit combined-work instruction, not a stacked issue branch. Current Couch-pane code already has registry/receipt feedback; new acceptance defends those paths when first-submit preparation is introduced and removes a required legacy prompt outside Couch. No claim is made that the exact historical failure is newly reproduced. No implementation has started; shared plan goes to the hub.

- 2026-10-15 — operator requested folding this into #332. Its feedback implementation passes18 production-door admission cases and64 native edit cases, including first-submit success and pre-attachment/attached error visibility. Close this duplicate as superseded by #332; remaining suite, review and operator acceptance stay on the parent.

### 2026-10-14


### 2026-10-23 — shared implementation staged; live acceptance pending

The shared #418 implementation now owns exact witnessed preparation before ordinary save/register/send, preserving one submit owner and its visible result. Native fake-Couch tests prove saved bytes and persisted registration before delivery; model/native tests passed on Neovim 0.12.5 and 0.11.7. Outside-Couch review explicitly announces local processing and no longer requires the legacy prompt. Current-route failures and duplicate/pending behavior remain under the existing admission tests. The historical 2026-10-14 failure is not claimed reproduced.

PR 338 is staged on parley.nvim:0 at code head 9a5967f4768a181522ba89fa2ddfaf5d746750a7. Authenticated TL cf318a62 schedules the morning operator check of plain/partial headers and second press, with submissions to ops:0; waiting for the relayed result. The #418 Log owns current recorded-suite lease and remaining automated preflight. This card is authoritatively working/claimed via tracker verbs despite its checkout's old mirror; do not edit mirrored card fields manually. Exact next step: collect that acceptance and the final corrected-head check, then close this card with its separate verified evidence through the binary.

## Revisions

### 2026-10-23 — reopen for combined first-submit acceptance

The new TL dispatch supersedes the duplicate-only disposition, preserving the old Log and report. Acceptance now exercises the current save/register/submit path and explicit local processing outcomes. #418 owns shared canonical front matter resolution/preparation; this card owns the silent-submit regression and real-pane acceptance, using one shared plan and separate verified close evidence.

### 2026-10-15 — Superseded by #332 at operator request

The requested Couch-pane workflow now uses save→register→submit rather than the original process-instruction prompt→placement→resubmit route. #332 owns visible owner/time success and visible errors, plus the remaining combined live check. Preserve the original report and acceptance text as evidence; close this card as a superseded duplicate, not as a claim that its original prompt route or outside-pane flow was newly implemented.
