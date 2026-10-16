---
id: 000337
status: codecomplete
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '7e331f729397d94f1f5288b46505aa0bd3818e96' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T16:04:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "a662a669", done: "6525e798"}
actual_hours: 0.90
---

# Flake: integration files exceed a load-dependent whole-file deadline

## Problem

First seen 2026-10-15 during #332 verification: three integration files passed in one full run and were killed by the harness deadline in the next full run with identical code/tests. The variable deadline reports50s x1.0 on12CPUs (loads8–10) in the failed run. This is recorded as an intermittent timing/deadline failure; cause is not established.

## Spec

Investigate the shared deadline/whole-file workload interaction for entity_delete_parity_spec.lua, file_history_spec.lua and issue_tracker_spec.lua. Preserve their behavioral assertions and the machine-wide suite budget. Fix the root cause rather than adding retries, sleeps or blindly increasing timeouts; split bounded workloads if evidence supports it.

### Root cause and proposed design

The runner takes one startup load sample and applies Plenary's50s default to a whole file, not a single stalled case. The sampled minimum says nothing about the amount of legitimate work: parity intentionally sweeps roughly500 buffers, file-history now has28 cases with full setup, and tracker has18 cases with216 Git setup commands before their bodies. Successful file durations56–83s therefore exceed the50s minimum without proving a hang. The last run also killed branch_child, packaging_release and starter_bootstrap after continuing successful assertions. Preserving one arbitrary whole-file deadline as these files grow is the wrong hang model.

Proposed: keep the existing50s base and bounded1–4x load factor as a no-completed-case watchdog (including bootstrap, before/body/after and teardown), plus an independent absolute ceiling of base×4, the existing maximum envelope (ordinary files200s; existing large-corpus base180s retains720s maximum). Only structured completed-case frames from a thin child wrapper around actual Plenary execution refresh progress; arbitrary stdout never does. The pure deadline state decides running/stalled/absolute-expired from monotonic time and validated progress. The thin parent owns the child process, streams original output, retains exit codes, kills/reaps on either expiry, and closes its timer/handles. No retries, sleeps, skipped assertions, new longer-timeout path exceptions or workload-derived unbounded budgets.

Alternative: reduce repeated fixture cost separately. That can improve throughput, but cannot correct the whole-file/one-case mismatch across the deadline failure class; avoid changing unrelated behavioral fixtures to hide the harness defect. A blanket timeout increase is rejected. Test-runner changes remain headless harness surface, not product editor behavior.

ARCH-PURE/ARCH-ORDER: one deterministic state transition with clock/progress/exit inputs, no wall-clock sleeps in policy tests. ARCH-DRY: keep Plenary as the assertion/fixture executor; share one policy across ordinary and existing corpus budgets. ARCH-CONSTRAINTS/ARCH-FUNERAL: absolute runtime ceiling and one owned child/timer, terminated and reaped on failure; no durable state. ARCH-SECURE: harness-owned framed progress, not arbitrary log activity; tests stay in existing temporary profiles. The IO dependency is the same installed Neovim/Plenary exercised by isolated real-child conformance.

## Done when

A controlled schedule or deterministic regression identifies why these passing files can overrun the selected deadline, a root-cause fix preserves their assertions, and focused plus full-suite evidence verifies bounded completion.

- Deterministic policy tests allow completed-case progress beyond the old whole-file minimum, reject bootstrap/case/teardown stalls and stale/invalid frames, and enforce load bounds plus the independent absolute ceiling.
- Real Plenary child conformance preserves successful/failed assertions, ignores arbitrary output as progress, and proves timeout termination and reaping with no live child PID.
- Focused checks and the complete required suite pass with the affected behavioral assertions and existing corpus base budgets unchanged.

## Plan

- [x] Freeze the diagnosed timeout model and obtain TL review of the progress/absolute-ceiling design.
- [x] Observe deterministic RED for useful work past50s, stalled bootstrap/case/teardown, cap, load bounds and ignored arbitrary output; verify thin-runner wiring with controlled process events.
- [x] Implement the smallest shared pure policy and owned child adapter, preserving Plenary assertions/output/exit codes; verify actual success, assertion failure and forced timeout children with cleanup.
- [x] Run focused harness and affected suites, update atlas/lessons, and pass the required full suite.

After verification, close through the mandatory fresh review, fix any finding class, land on SHIP and report the merge to the hub.

## Log


- 2026-10-15: closed — Final required suite PASS onff50e5646b36b0eaa7ec6e8b98007ca3e877f7a1 after BR-1 + landed#336:436 files, lint738files clean,2m21s, log .git/sdlc/local-checks/ff50e5646b36b0eaa7ec6e8b98007ca3e877f7a1/suite.log sha256:016ac36fcc31. Focused23 pass; all7 real-child cases also pass with uv.loadavg forced100000. Ordinary/capped inputs controlled; absolute precedence unchanged; stalled/absolute children reaped with ESRCH. No skips, retries inside tests, new path timeout exceptions or gate waivers. Earlier peer-SIGINT partial run is preserved separately, not counted as a test failure or pass.; review verdict: SHIP
- 2026-10-15 — final required suite PASS onff50e5646b36b0eaa7ec6e8b98007ca3e877f7a1 after BR-1 and #336 integration:436files, lint738files clean,2m21s, no surviving processes. Saved log .git/sdlc/local-checks/ff50e5646b36b0eaa7ec6e8b98007ca3e877f7a1/suite.log sha256:016ac36fcc31. Native7 conformance passed in the full run; focused23 and forced-cap7 already green. Cancelled partial run remains separate. Re-close/SHIP and landing pending.

- 2026-10-15 — external interruption of final candidate ff50e564: pair:5 reported mistaken SIGINT to this slot’s runner PID13969 (submitted receiptb9785032-7aeb-4ef4-bdd5-a840cb4d8279). Verified suite exit130 with no prior assertion failure, no checkout changes and no remaining processes naming exact worktree sdlc-local-2956896787. Partial log retained at .git/sdlc/test-stats/inflight/e4b8d175ccfee40cc4e8eb6215562b1d/run.log. This is cancellation, neither a test flake nor landing evidence. Same pushed ff50e564 candidate restarted; final suite/re-close pending.

- 2026-10-15 — required full suite PASS on53b675f42f03d6d6bddd38d43891e03b4a8467ed in2m25s, /Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/53b675f42f03d6d6bddd38d43891e03b4a8467ed/suite.log (sha256:b9ce2acbd238). All recipes completed, no failed files, no surviving test processes. In particular issue_tracker passed58s while making case progress, exceeding the old minimum without masking a stall; all six affected deadline files and packaging_vm passed. Focused22 cases and full lint pass. Close review/landing remain pending.

First seen:2026-10-15. Failing head1eaefd96df59afcb8d0880ec621864b137a596a7, command sdlc local-check run --name suite. Log:/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/572dbf1a77bfb77320a173d6409874e8.log. All three were killed at50s; no failed behavioral assertion preceded the kill. Previous full suite on e9a1622d2102e71e66dc44d3a0dacb70e9921f92 passed entity_delete_parity in83s, file_history in63s, issue_tracker in67s; log:/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/894c995da011381b869a9bd450c9545b.log. The only diff between these heads is #332 issue documentation. That preceding run failed only the separate packaging VM flake #336, which passed on this run. No suite waiver or quarantine.


## Revisions

- 2026-10-15 — TL assigns #337 to this slot from main; #332 remains parked atce50b56d165838c309067433d220078b9a1f9b03. Expand the enumerated deadline class to branch_child, packaging_release and starter_bootstrap from the complete exact1eaefd96 run, failed/6f81bbfaed0b35a39900598fdc471e11.log. Read-only source/history establishes startup-sample and whole-file granularity as the shared model defect; fixture-cost improvements are a separate alternative, not presumed root cause. Design above awaits TL approval; no code/tests changed and no change-code yet.

- 2026-10-15 — TL approved7482a903 in submitted receiptd63d1e4f-e434-4116-a323-25acab8627a5; change-code admitted quick flow. Pure deadline policy RED0/11/0 then GREEN11/0/0; adapter/framing RED0/8/0 at /tmp/parley337-runner-red.log. Implementing only the headless test harness; Plenary assertion/fixture behavior is retained.

- Deferred steering for parked #332, received582dad22-e6ad-4a0c-a8e1-1779601af020: on resume append a Revision and tests for content-hash equality since last successful submit: unchanged Alt+Return skips send and shows last-submit time; changed content sends; a second Alt+Return within about2s explicitly resends with a resent receipt. This belongs only on #332, not this harness branch.

- 2026-10-15 — focused harness GREEN22/0/0 (policy11, framing3, existing options2, real-child6), /tmp/parley337-all-harness-green.log. Actual child checks prove pass/fail propagation, completed-case count, arbitrary-output rejection, teardown coverage, progressing absolute cap and ESRCH after reap. No behavioral fixtures or timeout exceptions changed. Lint7files zero warnings/errors before docs update; final checks pending.

- 2026-10-15 — final focused22 cases pass at /tmp/parley337-final-harness.log, full lint738files zero warnings/errors at /tmp/parley337-lint.log and diff check clean. Preserve the absolute/no-progress distinction in atlas and keep close/landing as post-check actions instead of claiming them in verification checkboxes. No suite rerun started yet on this implementation.

- 2026-10-15 — close preflight requested bullet-form Done-when oracles for the quick flow. Added explicit checks for the already-approved policy, real-child boundary and full suite; no scope change, reviewer not dispatched yet.

- 2026-10-15 — close round1 REWORK BR-1 (Important, control-environment-dependent-test-inputs): the real-child reason assertions sampled uncontrolled load; at4x idle equals absolute, so absolute correctly wins. Sweep all three stalled-reason tests by injecting ordinary load/CPU inputs through execute, and add a controlled capped-load real child. New regression RED6/1/0, expected absolute-expired but got stalled because injected load was ignored, /tmp/parley337-br1-red.log. This refines test determinism without changing default live budgets or policy precedence.

- 2026-10-15 — BR-1 full class fixed: execute accepts injected load/CPU samples, native helper pins ordinary inputs for every reason-specific assertion, and a seventh native case pins capped-load absolute precedence. Focused23 cases GREEN at /tmp/parley337-br1-green.log; additionally all7 native cases pass with the process uv.loadavg forced100000, /tmp/parley337-br1-forced-cap.log (the reviewer previously reproduced3failures there). Default run still samples live load/CPUs. New code requires a fresh full-suite pass before re-close; #336 has landed and will be integrated first.
