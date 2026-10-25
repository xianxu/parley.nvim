---
id: 000446
status: working
deps: []
github_issue:
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
card_mirror: '8228bf87349030a2a5b07099ef0b50a9c5d0f8eb' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-25T16:34:12-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flake_tests: [lua:tests/integration/file_history_spec.lua#per-window file Back (#333) copies the parent's history into a split and keeps later cursors and visits independent]
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

Mechanism (measured, 2026-10-25): load slowdown against a fixed whole-file ceiling, not a hang. The DEADLINE line's "idle 138334ms" is the load-scaled idle budget (50 s x 2.77), not observed idle; the status was absolute-expired, the unscaled base x4 = 200 s ceiling #337 added. Quiet (load 12): 47 cases in 19.7 s, slowest case 0.86 s. The failed suite ran 23 cases in 200 s, about 14x slower, and its sibling specs were as slow in the same window against the passing rerun bpx4caybq: entity_textobj 58 s vs 4 s, branch_child 120 s vs 4 to 6 s, starter_config 63 s vs 9 s. The startup load sample (2.77) understates such a window, so no fixed or load-scaled whole-file wall-clock budget can be right.

Proposed (a design change to #337, waits for hub approval): drop the absolute ceiling as a kill trigger. The no-completed-case watchdog (load-scaled idle budget, renewed only by harness-framed case completions) stays the one bound, so a stuck bootstrap, case or teardown still dies, and a spec that keeps completing cases is never killed for being slow. A spec's case count is finite, so its total stays bounded by (cases + 1) x idle, an event-derived bound (ARCH-CONSTRAINTS still holds). The runner's outer vim.wait(ceiling + 1000) becomes a wait on result or a non-running status, repeated in idle-sized slices.

- [ ] spec_deadline: remove absolute_ms and absolute-expired; update tests/unit/spec_deadline_spec.lua (the three absolute cases become: progress past base x4 keeps running; a stall still expires).
- [ ] spec_runner: outer wait no longer derived from a ceiling; DEADLINE line names the idle budget and the observed idle time.
- [ ] spec_runner_native_spec: "enforces the absolute ceiling while cases keep completing" becomes "a progressing child past base x4 completes"; capped-load precedence case becomes stalled.
- [ ] atlas/infra/test_harness.md Deadlines section; unregister the #446 flake.

Alternative, smaller: scale the ceiling by the same load factor (max 800 s). Rejected as primary: the measured window was 14x slow at a sampled factor of 2.77, so it would still fail.

## Log

Evidence: sdlc merge of #445 (PR #355), local suite on head ae62beed52cc642c45b5808595425e6480a46131, attempt e39946321e686a7334bcf483d229bf4c, log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/e39946321e686a7334bcf483d229bf4c.log (sha256:d652422557af). 'DEADLINE: tests/integration/file_history_spec.lua absolute-expired after 23 completed case(s); idle 138334ms, absolute 200000ms'. The 1-minute load was 29 to 33 at the time. The same spec passed in 67 s on a0d2a98c's pre-close suite (#442). The change under test was docs-only, so it cannot have caused this. Filed at hub direction (6670f8b9).
