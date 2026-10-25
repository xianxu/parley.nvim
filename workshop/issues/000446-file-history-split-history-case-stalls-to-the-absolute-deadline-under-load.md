---
id: 000446
status: open
deps: []
github_issue:
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
card_mirror: '7364e419a3e1febb65ec2cb8e6566030330adcb9' # card fields mirrored from issue-cards; edit via sdlc
---

# file_history split-history case stalls to the absolute deadline under load

## Problem

tests/integration/file_history_spec.lua hit the spec runner's 200 s absolute deadline under load. Its 24th case, 'per-window file Back (#333) copies the parent's history into a split and keeps later cursors and visits independent', made no progress for 138 s after 23 cases completed. The case is fully synchronous: edit, vsplit, set the cursor, FileBack. It has no waits and no child process. The spec normally takes about 67 s.

This is the class ariadne#622 swept in ariadne: a wall-clock bound that fails under machine load rather than on a defect.

## Spec

Find what a synchronous case spends 138 s on under load. Make the spec's budget scale with load, or remove the bound that fails on load alone, keeping its behaviour assertions. Note: the landing that hit this was a docs-only move (#445), which should not need a full suite at all (ariadne#632).

## Done when

- The mechanism is named from evidence: load slowdown, or a hang in the case.
- The spec passes under load without a fixed wall-clock bound failing it, or the hang is fixed.
- The flake registration is retired.

## Plan

## Log

Evidence: sdlc merge of #445 (PR #355), local suite on head ae62beed52cc642c45b5808595425e6480a46131, attempt e39946321e686a7334bcf483d229bf4c, log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/e39946321e686a7334bcf483d229bf4c.log (sha256:d652422557af). 'DEADLINE: tests/integration/file_history_spec.lua absolute-expired after 23 completed case(s); idle 138334ms, absolute 200000ms'. The 1-minute load was 29 to 33 at the time. The same spec passed in 67 s on a0d2a98c's pre-close suite (#442). The change under test was docs-only, so it cannot have caused this. Filed at hub direction (6670f8b9).
