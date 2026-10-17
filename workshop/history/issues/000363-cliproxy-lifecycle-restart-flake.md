---
id: 000363
status: done
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '8de0c97e0b472f66fa6a37fa42a601d5cfc2d286' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T16:08:41-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "8184a722", done: "5e84df71"}
actual_hours: 1.31
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

- [x] Consolidate #364's matching signatures and retained logs under #363.
- [x] Instrument the stop/exit/listener/probe boundaries and reproduce the
  ordering with controlled delay, without load or a wider deadline.
- [x] Correct the demonstrated root cause and add a regression that fails
  without it; cover both credential-restart outcomes and teardown isolation.
- [x] Run focused and mapped cases plus a recorded full suite, update the
  relevant atlas, close-review and land on SHIP; then resume #362.

## Log

- First seen:2026-10-16. Head:`aa8a3408fd3338402eb949a7c275335bd9c9966f`. Required command: `sdlc local-check run --name suite --rev aa8a3408fd3338402eb949a7c275335bd9c9966f`. Failed file duration85s. Full suite finished3m46s after1306s queue wait.
- Retained failed log:`/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/1faa0580088008736845350a044e2a30.log`; SHA256:`433c84052df7d9a2abef784e9e0ba7b353e338ec0172f8112c66ea7dec0c42a5`. All remaining specs ran through make -k.
- Earlier passing integrated suite:`/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/5ac7cd3548c3cdc11ec5d0812e6c042e2352c9e6/suite.log` (454pass,760lint).
- Same-head focused replay: `/tmp/parley353-lifecycle-repro.log`, all63 cases pass, no surviving processes. No lifecycle source, fixture, assertions or timeouts were edited. This confirms intermittence; the root-cause investigation remains open.

### 2026-10-16 — priority and investigation
- 2026-10-16: closed — Deterministic models-only 2200ms delay failed the old fixture at its unchanged 8s await; fixed fixture passes all66 lifecycle cases. A deliberate closed-port reuse probe still fails both ORIGINAL assertions. Recorded full suite on 09f235c1b9e98e6234518f14e7dfb9ce82c0d894: first attempt452pass, only existing #360 warm-fetch flake, retained failed log967cf6ec616ace4cd27d8c2c85d07fcd (sha a78f45c6dd70); code-identical catalog22pass; one unchanged full rerun453/453pass, exit0 3m18s, logsha ad7a192f6912, lint757 and census clean. Temporary verification ref removed. Atlas and lessons updated; #364 deduplicated. Fixture-only repair: no production restart behavior, old assertion or timeout changes; no operator environment live check required. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

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

### 2026-10-16 — deterministic experiments

Unchanged production: a disposable lifecycle spec delays the main loop 2200ms
after the real stop returns, preserving real PID results. All 63 cases pass;
no post-stop synthetic stall fires. Log /tmp/parley-363-delay-probe.log.

A disposable process fake instead delays only /v1/models by 2200ms (management
404 stays prompt). Real stop-time curl times out and stop returns n=0,pids={}
(no process signalled); the fixture nevertheless opens its killed window.
wait_port_released legitimately probes an unidentified listener, but the wrapper
fabricates down after 5s, then stalls ensure_running another 5s. The 8s await
expires, with continuations still running. Trace names cliproxy.lua:512 and
:905; log /tmp/parley-363-identity-delay.log. This demonstrates a fixture
false positive, not proof that production probed a port it killed. Tighten
the model to an actually exited signalled process; preserve legitimate
unidentified/still-alive probes. Final regression will delay only the first
identity response so the fallback can answer within the unchanged budget.

## Revisions

### 2026-10-16 — repair the fixture's false closed-port observation

The two reports are not evidence of a production restart race: deterministic
identity delay proves stop can signal nobody, after which the fixture itself
fabricates two delayed down readings. Restrict its stall to confirmed exited
signalled PIDs, leaving unidentified and still-live fallback probes real. Own
synthetic timers in a per-case scope; retire and guard late callbacks. No
production restart code, request deadlines, assertions or await budgets change.
The process fake gains a one-shot first-models delay, bounded at 10s and passed
only to the original fixture process. New regressions cover no-PID identity
timeout, still-live SIGTERM refusal, and positive closed-port/callback lifetime.
The no-PID regression failed with the original 8s timeout; the live listener
regression failed because artificial down hid its true still-answering state.
Logs: /tmp/parley-363-regression-red.log and /tmp/parley-363-both-red.log.

### 2026-10-16 — focused verification green

All eight credential-health cases passed, including the two red regressions
and the positive closed-port/retired-callback control. The complete lifecycle
file passed all 66 cases with clean process census; log
/tmp/parley-363-lifecycle-green.log. Changed Lua test lint and diff whitespace
checks pass. No production restart code or existing timeout/assertion changed.
Atlas documents the fixture distinction; lessons capture effect-based windows
and owned delayed callbacks. Next: pushed-head recorded full suite, then close.

### 2026-10-16 — original regression sensitivity retained

A disposable mutant replaces restart_managed with stop -> confirmed PID exit
-> ensure_running's reuse probe. Both ORIGINAL assertions still fail with
window_probes=1 (keyless repair and persistent 404), proving the fixture repair
did not weaken the closed-port regression. The new still-live refusal also
fails under that mutant; five other cases pass, census clean.
Log /tmp/parley-363-mutant.log. Tracked production code never changed.
Recorded suite is queued on pushed code head 09f235c1b9e98e6234518f14e7dfb9ce82c0d894.

### 2026-10-16 — first recorded suite, unrelated catalog flake

Recorded suite on 09f235c1b9e98e6234518f14e7dfb9ce82c0d894 finished all
files (make -k behavior), exit 2 in 3m21s after 2221s queue wait, lint 757
clean and final process census clean. The lifecycle file PASSED (73s).
Only cliproxy_catalog_spec.lua failed: its 401 case at line136 could not
seed a nonempty warm catalog. This is the empty initial fetch after fake
readiness tracked by #360, in another case's shared warm-up; not a rejected
401 write or changed catalog policy. The code-identical focused catalog run
passed all 22 cases, census clean (/tmp/parley-363-catalog-focused.log).

Retained failed log: .git/sdlc/test-stats/failed/967cf6ec616ace4cd27d8c2c85d07fcd.log
(SHA256 prefix a78f45c6dd70). Applying the issue-backed flake rule: exactly
one unchanged full rerun on the same 09f235c1 commit, not the prose-only
current HEAD. A second unrelated flake blocks for hub guidance.

The rerun's first preflight refused (no test executed): 09f235c1 was no longer
a remote branch tip after the documentation push. Published temporary
verification-only ref verify-363-suite-09f235c1 at the exact original commit
to satisfy that precondition without rewriting the issue branch. It holds no
new development; delete it after the check finishes, including a failed check.
The unchanged suite rerun is then invoked against 09f235c1 explicitly.

### 2026-10-16 — unchanged recorded rerun passed; ready for close

The one unchanged full rerun on 09f235c1b9e98e6234518f14e7dfb9ce82c0d894
PASSED: 453/453 files, lint757 clean, final census clean, exit0 in 3m18s
after1356s queue wait. Catalog passed (4s), lifecycle passed (45s).
Log .git/sdlc/local-checks/09f235c1b9e98e6234518f14e7dfb9ce82c0d894/suite.log,
SHA256 prefix ad7a192f6912. The first failed attempt remains retained above;
#360 remains open, not claimed fixed here. Temporary verification-only ref
verify-363-suite-09f235c1 was deleted with an exact-tip lease after completion.
All implementation/verification checklist work is complete. Close review and
landing remain the next gate-owned actions; no live operator environment was
changed by this fixture-only repair.
