---
id: 000337
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '7517acc769841145e4f217b02898452f10a8a42e' # card fields mirrored from issue-cards; edit via sdlc
---

# Flake: integration files exceed a load-dependent whole-file deadline

## Problem

First seen 2026-10-15 during #332 verification: three integration files passed in one full run and were killed by the harness deadline in the next full run with identical code/tests. The variable deadline reports50s x1.0 on12CPUs (loads8–10) in the failed run. This is recorded as an intermittent timing/deadline failure; cause is not established.

## Spec

Investigate the shared deadline/whole-file workload interaction for entity_delete_parity_spec.lua, file_history_spec.lua and issue_tracker_spec.lua. Preserve their behavioral assertions and the machine-wide suite budget. Fix the root cause rather than adding retries, sleeps or blindly increasing timeouts; split bounded workloads if evidence supports it.

## Done when

A controlled schedule or deterministic regression identifies why these passing files can overrun the selected deadline, a root-cause fix preserves their assertions, and focused plus full-suite evidence verifies bounded completion.

## Plan

- [ ]

## Log

First seen:2026-10-15. Failing head1eaefd96df59afcb8d0880ec621864b137a596a7, command sdlc local-check run --name suite. Log:/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/572dbf1a77bfb77320a173d6409874e8.log. All three were killed at50s; no failed behavioral assertion preceded the kill. Previous full suite on e9a1622d2102e71e66dc44d3a0dacb70e9921f92 passed entity_delete_parity in83s, file_history in63s, issue_tracker in67s; log:/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/894c995da011381b869a9bd450c9545b.log. The only diff between these heads is #332 issue documentation. That preceding run failed only the separate packaging VM flake #336, which passed on this run. No suite waiver or quarantine.
