---
id: 000352
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '23795ae49a37f9235c15d95ff01021d3d979374b' # card fields mirrored from issue-cards; edit via sdlc
---

# Send side chats off the path to the root as their summary lines

## Problem

## Spec

Follow-up to #233 (operator request, 2026-10-16). #233 sends the whole chat tree in depth-first order, cut at the submitted exchange, and renders every exchange the same way, so a side chat's exchanges go out in full (or under the memory rule) like any other.

Asides are usually side conversations: the model needs to know they happened, not their full transcript. Add a config flag that sends side chats NOT on the path from the current file to the root as their summary lines only (the exchange's summary line, the same one memory uses for an omitted exchange). Exchanges in files on the path to the root (the current file and its ancestors) keep the memory rule as today.

- The flag's name and its default are decided in the plan, with the request-size numbers from #233's measured tree (before and after, both values of the flag).
- An off-path exchange without a summary line: the plan decides (skip it, or send it under the memory rule).
- Nested asides off an off-path aside are off-path too.

## Done when

- A config flag controls how off-path side chats are rendered; with it on, every off-path exchange is sent as its summary line only, and on-path exchanges are unchanged.
- Tests cover: an aside off the root seen from a later root question, a nested aside, an on-path ancestor (unchanged), the flag off (#233 behaviour), and an off-path exchange without a summary.
- The atlas and the config docs describe the flag and its default.

## Plan

- [ ]

## Log

### 2026-10-16
