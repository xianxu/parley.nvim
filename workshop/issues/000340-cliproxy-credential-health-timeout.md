---
id: 000340
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'faa018dd8454bff3433c4d101a4cafcddfeff381' # card fields mirrored from issue-cards; edit via sdlc
---

# Credential-health persistent-404 test times out in the required suite

## Problem

The required suite for #332 completed every recipe but failed one unchanged cliproxy lifecycle case. First seen 2026-10-15 in run acebcf70a6676a7e2e96ef8c6624e95a, on pushed code b5de7d2b4c3d336679135d016baeb58654f262aa. This is independent of the agentic document changes and should be fixed from main.

## Spec

Investigate tests/integration/cliproxy_lifecycle_spec.lua, credential_health case “does not restart twice — a persistent 404 is reported, not looped”. Its first await at line 778 exceeded the shared 8000 ms case budget, failing tests/helpers/await.lua:30 with “async call timed out”. Distinguish a short budget from a lost callback or fixture teardown race. Preserve the single-restart/persistent-404 contract; derive any budget change from the actual repair path rather than increasing it blindly. Use controlled scheduling/fixture completion so the cause is reproducible.

## Done when

- The persistent-404 case deterministically proves one restart attempt, reports unknown after failed restart, and leaves the second keyless proxy alive.
- A controlled regression reproduces the observed cause and passes after the fix, with explicit callback completion or a derived budget covering the real bounded path.
- Focused lifecycle and the required suite pass, with no weakened assertions, skips or blind deadline increase.

## Plan

- [ ]

## Log

- First seen 2026-10-15 in #332 PR241. Code b5de7d2b4c3d336679135d016baeb58654f262aa; this file and production cliproxy code are unchanged by #332. The previous #337 full suite passed this file. Current suite: 442 passed spec files, one failed; this file 53 successful cases/1 failure/0 errors in 64 s. Full run took 3m11s after a 2043 s machine-cap queue; all recipes finished, no surviving test processes. Earlier #336/#337 failures passed in this run.
- Full retained log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/acebcf70a6676a7e2e96ef8c6624e95a.log; SHA256 e330d2ee07a369850bc8d6bb9233559fa4b86a510c95acd6cef89e06672a5548. Local status sdlc-local/suite is failure on the exact code head. A single focused same-code reproduction is pending; no clean full-suite or live acceptance is claimed.
