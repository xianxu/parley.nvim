---
id: 000361
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
card_mirror: 'a6ec29171edf4a09a6c807922171ebab333400a3' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T02:19:20-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "4ace9bce", done: "e3120362"}
---

# Cliproxy expired-token recovery intermittently retries instead of prompting

## Problem

tests/integration/cliproxy_auth_login_spec.lua intermittently fails “claims the #197 503, prompts the right login, and reports the real reason” at line128: expected settled=give_up for the fake expired OAuth credential and dismissed login, observed settled=retry. The whole spec passed on a focused run of the exact same head. This independently blocks #353's suite; it is not folded into the breadcrumb implementation.

First seen: 2026-10-16 during #353's final-head full suite. Head: f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1. Failed run finished with446 spec files passing, two failing, lint749 clean and no surviving processes.

Retained failed-suite log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/bd9f02e9a941c6a23073857764765ecb.log (SHA256 3c666a396002ea5ad421f2d8042d2bb452182ddea7f675de21a3b2607d7a470a). Same-head focused rerun of both affected specs passed all43 cases: /tmp/parley353-cliproxy-repro.log. Earlier full suite on ed5af56cef2c8b6b917f0bd932eb18c1a36c0591 passed448/448; the only subsequent production change returns a snapshot failure reason in file_history.lua. Cliproxy source and these spec files are unchanged by #353.

## Spec

Determine why an expired-channel fake credential can take the retry branch under full-suite load instead of reaching its login prompt. Capture the real credential-health/request outcome before changing timing; distinguish unavailable HTTP evidence, state leakage and deliberate retry behavior. Do not suppress the assertion or raise a blind timeout.

## Done when

- A controlled adversary reproduces the wrong recovery decision and identifies its boundary evidence.
- Fix the causal fixture or production policy with a deterministic guard; preserve real healthy-credential retry behavior.
- Focused real-fake recovery tests and the declared suite pass with retained evidence.

## Plan

- [x] Reproduce both variants by holding the readiness window open.
- [x] `ready_port.require_listening` fails by name; `wait_listening` is `---@nodiscard`.
- [x] Switch the 38 calls that dropped the answer (lifecycle 26, update 9, recovery_e2e, auth_login, fake_releases).
- [x] `nodiscard_spec` checks spec-side helper members across `tests/`.
- [x] Forced-window regression in `cliproxy_auth_login_spec` (`PARLEY_FAKE_BIND_DELAY_MS` plus a staged connect).
- [x] Full suite, close.

## Log

Filed under the test-economy flake rule after one failed full run and one same-head focused pass; root cause not yet established. No production fix or waiver claimed.

### 2026-10-17 — root cause: the #360 readiness false positive, with the answer dropped
- 2026-10-17: closed — Same root cause as #360 (landed 775246fb). serve() recovered against a fake whose readiness wait was fooled and whose answer it ignored. A forced-window repro reproduced both logged variants: 0 ms gives no prompt, 40-80 ms gives retry. Fix: require_listening fails by name and is now the only readiness door (38 dropped-answer callers plus 12 hand-written asserts converted); wait_listening is nodiscard and nodiscard_spec covers tests/ (mutation: a bare call is flagged). Regression: a staged crossing connect plus a 300 ms late bind still settles give_up with the prompt (mutation: dropping the LISTEN confirm fails it), pending without lsof. Round 1 fixed. Focused specs all pass. Suite on 12105c27: attempt 1 failed only on the #372 owned-move flake (log 05a69d6e); unchanged rerun exit 0 in 2m24s.; review verdict: SHIP

- Same mechanism as #360. `serve()` waited with `ready_port.wait_listening`, but a crossing connect could report ready before the fake bound, and `serve()` ignored the answer anyway. `recover` then read the management API of a fake that was not listening yet.
- Forced-window reproduction: a scratch copy of the two cases, recovering a fixed time after spawn with no readiness wait. At 0 ms there was no prompt (the line-149 variant, give_up with nothing to offer); at 40 and 80 ms it settled `retry` (the line-128 variant); from 120 ms on it passed. Both logged variants are this one window.
- Fix: #360 (landed, 775246fb) removed the false positive. Here every caller asserts readiness. `require_listening` raises "fake never came up on port N (waited Xms)", and the 38 callers that dropped the answer use it. I checked each: every one waits for a fake it just started.
- Guard (ARCH-DRY: the existing `nodiscard_spec`, not a second sweep): `wait_listening` is `---@nodiscard`, and the spec now reads annotations from `tests/helpers/*.lua` and checks calls across `tests/`. In spec files it enforces only helper members: specs' own setup ignores product results like `custom_prompts.set` on purpose (18 such calls), and that is a separate question. Mutation: one bare `wait_listening` put back is flagged by file and line.
- Regression: "waits out a readiness probe that a crossing connect fooled" stages `_connect` as succeeding and has the fake bind 300 ms late (new `PARLEY_FAKE_BIND_DELAY_MS`, capped at 10 s), and must settle give_up with the claude prompt. Mutation: dropping the LISTEN confirm fails it at line 160. Unit cases: `require_listening` raises by name, and returns for a real listener.
- Focused: ready_port 14/14, nodiscard 2/2, lifecycle 66/66, update 40/40, recovery_e2e 6/6, auth_login 23/23, fixture_lifecycle 4/4.

### 2026-10-17 — close review round 1 (FIX-THEN-SHIP)

- BR-1 (Important, lsof-dependent-test-guard): fixed. The forced-window case stubs `_connect`, so without lsof `is_listening` trusts the connect, and the case would fail deterministically. It now reports pending there, like the unit spec's rejects case. Class sweep (grep `_connect = ` under tests/): four cases stub it. The other two also stub `_lsof_present`, so they don't depend on lsof; the two that rely on real lsof both guard.
- Minor (doc-count-claims): fixed. The listed parts add up to 38, not 37, in both the Plan and the Log.
- Minor (ready-wait-assert-restated, ARCH-DRY): fixed, not deferred. The 12 hand-written `assert(ready_port.wait_listening(port), msg)` sites (openai_tool_loop, catalog ×6, fixture_reaping, caller_teardown, dispatch, stream_integrity, provider_scenarios) now call `require_listening`. Outside ready_port and its unit spec, every readiness wait now goes through `require_listening`.
