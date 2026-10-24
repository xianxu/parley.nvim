---
id: 000433
status: wontfix
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
collaboration-mode: collaboration
card_mirror: '01b4b4c770748033a3cda68af4f5ba0e5bdda704' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T23:11:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits releases synthetic move protection only at the unchanged acquisition baseline]
---

# Synthetic move release native test intermittently fails its baseline assertion

## Problem

The native case session-sync native edits releases synthetic move protection only at the unchanged acquisition baseline intermittently fails its embedded assertion at session_sync_native_spec.lua:1415 (fixture Lua line11). This reproduced on pure main, independently of #418's parser-only code.

## Spec

Reproduce the synthetic acquisition-baseline/move-protection ordering and identify whether the failing assertion races fixture readiness or exposes a production transition defect. Preserve the baseline/ownership distinction; do not weaken protection or mask the race with a larger fixed delay.

## Done when

- The original native assertion failure has deterministic ordering coverage.
- The owning transition or fixture readiness is corrected while retaining all synthetic-move protection invariants.
- Exact-case and complete native-spec qualification pass on both supported runtimes.

## Plan

- [ ]

## Log


- 2026-10-24: abandoned (wontfix): fixed in parley.nvim#431 (PR 348, merge 58228d3d): stale-clock vim.system kill of the operator release; regression in session_sync_native_spec
2026-10-23: found during TL-capped pure-main qualification for a separate #418 integration failure. On exact main28526aa8eefe4da49b28bac04456f56e564ecaf2, Neovim0.11.7, the unchanged complete tests/integration/session_sync_native_spec.lua fails only this case in run8 (143pass/1fail,0 errors). Runs7/9/10 all144 pass on the same head, establishing pass/fail/pass. Every census is clean; no source edits, artificial load or changed deadlines. Original8-turn target passes all10 whole-spec runs and is separate; journal before-restore sibling failed in run4 and is separately#431.

Failure excerpt: session-sync native edits releases synthetic move protection only at the unchanged acquisition baseline; tests/integration/session_sync_native_spec.lua:1415; embedded_nvim.exec line61; embedded Lua line11 assertion failed. Evidence /Volumes/TestScratch/parley-418-native-ltjs_uc3/main-full-8.log, main-full-7.log, main-full-9.log, main-full-10.log and full-results.json; run-full.py preserves the original spec/fixtures. Filed unclaimed; no fix is stacked into #418.
