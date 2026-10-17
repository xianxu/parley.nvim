---
id: 000360
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '2e17d8bce7029614169fb6d3a0c97a76a1504810' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T22:33:58-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
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
- [x] `ready_port.is_listening` confirms a completed connect with a LISTEN socket (lsof, bounded at 2 s, only after a connect succeeds).
- [x] Route the four hand-copied connect polls through `ready_port.wait_listening` (ARCH-DRY).
- [x] Deterministic unit regressions in `tests/unit/ready_port_spec.lua`; stress before/after.
- [ ] Full suite, close.

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
