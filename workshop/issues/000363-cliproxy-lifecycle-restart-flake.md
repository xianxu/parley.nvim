---
id: 000363
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '2c2e82f733dedb210399fd6a5412b4b5c4974261' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T16:08:41-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "8184a722", done: "5e84df71"}
---

# Cliproxy credential-restart lifecycle cases intermittently time out and probe the killed port

## Problem

First seen 2026-10-16 during #353's required suite on `aa8a3408fd3338402eb949a7c275335bd9c9966f`. `tests/integration/cliproxy_lifecycle_spec.lua` failed two credential-restart cases under parallel load; the other453 spec files passed, lint760 clean, no surviving test processes. The same lifecycle spec passed earlier full runs on the preceding #353 source/integrated heads. This module, test and await helper have no branch diff against main.

## Spec

Investigate lifecycle fixture/restart completion ordering without a blind deadline increase. The suite reported:

- line967, `credential_health restarts a keyless proxy once, then reads health from the new one`: await.lua:30 async call timed out.
- line986, `credential_health does not restart twice — a persistent 404 is reported, not looped`: repair probed the just-killed proxy's port; actual1, expected0.

Root cause is not yet established. Determine whether the first timed-out callback leaks into the next case and make the fixture signal actual restart/probe completion deterministically.

## Done when

- A deterministic regression reproduces the failing ordering and proves its root cause.
- The completion/teardown boundary is corrected, both cases pass, and the required suite passes without loosening assertions or blind timeout increases.

## Plan

- [ ] Consolidate #364's matching signatures and retained logs under #363.
- [ ] Instrument the stop/exit/listener/probe boundaries and reproduce the
  ordering with controlled delay, without load or a wider deadline.
- [ ] Correct the demonstrated root cause and add a regression that fails
  without it; cover both credential-restart outcomes and teardown isolation.
- [ ] Run focused and mapped cases plus a recorded full suite, update the
  relevant atlas, close-review and land on SHIP; then resume #362.

## Log

- First seen:2026-10-16. Head:`aa8a3408fd3338402eb949a7c275335bd9c9966f`. Required command: `sdlc local-check run --name suite --rev aa8a3408fd3338402eb949a7c275335bd9c9966f`. Failed file duration85s. Full suite finished3m46s after1306s queue wait.
- Retained failed log:`/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/1faa0580088008736845350a044e2a30.log`; SHA256:`433c84052df7d9a2abef784e9e0ba7b353e338ec0172f8112c66ea7dec0c42a5`. All remaining specs ran through make -k.
- Earlier passing integrated suite:`/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/5ac7cd3548c3cdc11ec5d0812e6c042e2352c9e6/suite.log` (454pass,760lint).
- Same-head focused replay: `/tmp/parley353-lifecycle-repro.log`, all63 cases pass, no surviving processes. No lifecycle source, fixture, assertions or timeouts were edited. This confirms intermittence; the root-cause investigation remains open.

### 2026-10-16 — priority and investigation

Hub delivery c322a428-5e9c-4da8-981f-e6cbccada6c2 prioritizes these failures
before #362. #364 reports the same pair of lifecycle failures and preserves
a second log: .git/sdlc/test-stats/failed/1cd9910d389b48ba5efa70185c8f2c1e.log.
Treat #363 as canonical; #364 is duplicate evidence, not a second code task.
#362 remains committed on its independent branch, not stacked here.

ARCH-DRY/PURPOSE: trace the shared restart_managed path, not just the two
assertions. The current wait uses exit observation plus a listener recheck,
then falls back to port probes on unknown/no PID or deadline. The fixture
opens its stalled-probe window even if stop signalled no PID. Its delayed
probe callback survives an await timeout; root cause versus secondary
contamination must be distinguished, not assumed. A read-only subagent
confirmed those fixture boundaries. Use actual fake processes and existing
process-tool seams (ARCH-MOCK), with deterministic delay rather than load.
No production fix selected before reproducing the cause.
