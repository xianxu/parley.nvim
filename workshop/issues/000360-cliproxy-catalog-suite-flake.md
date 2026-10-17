---
id: 000360
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
card_mirror: '55b3865f127c3f2d413aa36a90f85e75d5118f92' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T22:33:58-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "b627919e", done: "2d376e3d"}
actual_hours: 1.17
---

# Cliproxy catalog joins-routes case intermittently returns empty under suite load

## Problem

tests/integration/cliproxy_catalog_spec.lua intermittently fails “joins both routes and caches the result to disk” at line75: fetch_catalog resolves to an empty model list after the process-level fake reports listening. The whole spec passed on a focused run of the exact same head. This independently blocks #353's suite; it is not folded into the breadcrumb implementation.

First seen: 2026-10-16 during #353's final-head full suite. Head: f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1. Failed run finished with446 spec files passing, two failing, lint749 clean and no surviving processes.

Retained failed-suite log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/bd9f02e9a941c6a23073857764765ecb.log (SHA256 3c666a396002ea5ad421f2d8042d2bb452182ddea7f675de21a3b2607d7a470a). Same-head focused rerun of both affected specs passed all43 cases: /tmp/parley353-cliproxy-repro.log. Earlier full suite on ed5af56cef2c8b6b917f0bd932eb18c1a36c0591 passed448/448; the only subsequent production change returns a snapshot failure reason in file_history.lua. Cliproxy source and these spec files are unchanged by #353.

## Spec

Determine why the ready fake/catalog HTTP routes can yield an empty catalog under parallel suite load. Capture request/result/timing evidence at the production seam; distinguish a readiness race from bounded HTTP request expiration or shared state. Keep operator endpoints and credentials isolated.

## Done when

- A controlled test reproduces the failing dependency state without relying on blind full-suite retries.
- Fix readiness/deadline/state ownership at its cause; preserve intentional unreachable-proxy behavior.
- Focused real-fake catalog tests and the declared suite pass with retained evidence.

## Plan

- [x] Reproduce under parallel load with the curl exit code recorded per fetch.
- [x] `ready_port.is_listening` confirms a completed connect with a LISTEN socket (lsof, hang guard 10 s after round 1, only after a connect succeeds).
- [x] Route the four hand-copied connect polls through `ready_port.wait_listening` (ARCH-DRY).
- [x] Deterministic unit regressions in `tests/unit/ready_port_spec.lua`; stress before/after.
- [x] Full suite, close; atlas Fixture readiness gains the LISTEN-confirm rule.

## Log

Filed under the test-economy flake rule after one failed full run and one same-head focused pass; root cause not yet established. No production fix or waiver claimed.

### 2026-10-16 — root cause: the readiness probe, not the product

- Three retained failures (bd9f02e9, 220afa67: joins-routes line 75; 967cf6ec: the 401 case's warm fetch, line 136) share one shape: the first fetch against a fresh fake comes back empty.
- Reproduction: 12 parallel nvim processes × 20 fresh-fake first fetches (scratch probe recording curl's exit code and timing). 6/240 failed, every one curl code 7 (connection refused) right after `wait_listening` returned true. The failures came in adjacent-port pairs across processes (65046/65047, 55546/55547). lsof 300 ms later showed our fake LISTENing, exit status nil, stderr empty. CPU load alone (36 busy loops) kept the first response at 10–90 ms, so it is not curl's 2 s `--max-time`.
- Mechanism: on macOS one sequential ephemeral counter serves both `bind(0)` and connect autobinds (measured). `free_port` releases its number to that pool; a parallel spec's probe can take it as a source port, and two probes aimed at each other's freed ports complete a TCP simultaneous open with nothing listening. `is_listening` read that handshake as "the fake is up", and curl then hit a port the fake had not bound yet.
- Fix (fixture, no product change): `is_listening` keeps its connect and then requires a LISTEN socket on the port (`lsof -sTCP:LISTEN -t`, 2 s bound per the TL; a timeout is "unconfirmed", never "listening"). lsof runs only after a connect succeeds, so polling a refusing port costs nothing extra. With no lsof installed the connect stands alone, as before. The four specs that hand-copied the connect poll now call the helper, so all ~48 readiness waits share the check.
- Not swept: `cliproxy.callback_port_blocked` (product) also connect-probes, but its fixed OAuth callback port is a "something holds it" warning, not a readiness wait; a false positive there needs a simultaneous open on that exact port. Left as is.
- Regressions: `ready_port_spec` stages a connect that succeeds with nothing listening (must be false) and runs a real listener (must be true), and asserts lsof never runs while a port refuses. Mutation: making `is_listening` trust the connect alone fails the first case. A real-kernel self-connect adversary was tried and does not complete on macOS (connect never settles), so the false positive is staged through the `_connect` seam.
- After the fix: the same 12×20 stress twice, 0/480 failures; readiness wait p50 654 ms, p95 1.36 s, max 2.08 s under that load (5 s budget). Focused: ready_port 9/9; catalog, lifecycle, update, auth_login, dispatch, caller_teardown, openai_tool_loop and stream_integrity specs all pass.
- This mechanism can also put a spec on the wrong fake's port timing; #361 (auth) uses the same helper and is checked next under the same probe before assuming a shared cause.

### 2026-10-17 — close review round 1 (FIX-THEN-SHIP)
- 2026-10-17: closed — Root cause: ready_port.is_listening treated a completed TCP connect as a listener; freed free_port numbers become parallel probe source ports and crossing probes complete a simultaneous open with nothing listening. Repro 12x20 parallel first fetches: 6/240 curl code 7 before, 0/480 after (0/240 again after round-1 fixes). Round 1 fixed: lsof guard 10 s (the #345 measurement), exit shapes pinned (caught exit 1 reading as nil), seams restored. ready_port_spec 12/12; the connect-only mutation fails 2. Suite on 5d007336 exit 0 in 3m10s (the earlier unrelated session_sync flake is filed as #370). Atlas test_harness Fixture readiness updated.; review verdict: SHIP

- BR-1 (Important, probe-cost-exceeds-wait-budget): fixed. The lsof guard is now 10 s, matching cliproxy's `LSOF_GUARD_MS` (#345 measured lsof past 2 s under the 8-way suite). It doesn't consume wait_listening's budget: vim.wait checks its deadline only between polls, so a confirm that started always finishes with an answer. Class sweep: every caller reaches lsof only through `is_listening`, so the default budget, the four rewritten start_fake helpers and the catalog spec's 300 ms settle wait all inherit it. The settle wait asserts nothing, so a slow lsof there only lengthens it.
- Minor (documented-mode-untested): fixed. New `_run_lsof` and `_lsof_present` seams; cases pin the lsof-absent fallback (the connect stands), present-but-unanswering (unconfirmed, false), and each exit shape (0 with a pid, 0 empty, 1, 124, other, could not run). That table caught a real defect: `res.code == 1 and false or nil` always yields nil in Lua. Now an explicit branch.
- Minor (test-seam-restore): fixed. after_each restores all four seams. The rejects case reports pending on a host without lsof instead of failing.
- After: ready_port_spec 12/12, and the connect-only mutation fails 2 cases. The 12×20 stress gave 0/240 again. The touched cliproxy specs pass.
