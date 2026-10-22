---
id: 000409
status: working
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'ef1f6596c3391a405cbd2c035a6eea062ca19731' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T11:20:56-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "aa96a8c4", done: "99af27e8"}
---

# Test orphan reaper kills an active targeted run in the same checkout

## Problem

## Spec

scripts/reap-test-orphans.py --phase before treats every recognized headless harness under the checkout as left by an earlier run, excluding only its own ancestry. A second targeted make run in the same checkout therefore SIGKILLs a healthy first run. This was observed during #407: /tmp/parley407-heading-inline-red.log reports reap pid69525 ppid47960, while /tmp/parley407-rework-targeted2.log reports that exact active open_reference_spec process as Killed:9. There is no assertion failure or spec deadline in the interrupted test.

Reproduce with one deliberately gated targeted spec running, then start another targeted make test-spec in the same checkout. Active runs must have ownership respected: either serialize same-checkout harness runs under a lifetime resource or distinguish live-owned trees from abandoned processes. Preserve cleanup of genuinely orphaned fixtures and harness children.

## Done when

- A deterministic controlled-process regression starts one active targeted harness then the second run's before/after cleanup and proves the first is not signalled (or the second waits under an explicit lease).
- Cleanup still reaps dead-owner leftovers and its own leaked children, with real process identity checks; an unrelated command containing the path remains untouched.
- Existing reaper tests and targeted/full harness checks pass; document the same-checkout run ownership rule.

## Plan

- [x] Add a controlled-process regression: gate the first target after entry, start a second target with a different scratch root, and prove the second cannot reach preparation/census until the first finishes. Red-check against the current harness. Exercise before and after census, nested make, cancellation, and a separate-checkout control.
- [ ] Add one Python checkout-lease wrapper using stdlib `fcntl.flock`, an inherited descriptor, and command argv. Route every harness target and standalone live reaper through that owner; acquire before scratch changes or census, retain through final checks. Preserve exit status and native signal behavior. (Reopened by BR-1: prerequisite/default entry still bypasses admission.)
- [x] Extend existing recorded-table and native reaper tests for dead-owner leftovers, own leaks, unrelated path mentions, and unchanged cleanup identity checks. Add a Makefile coverage guard for every harness entry; map new tests into infra/test_harness.
- ~~Update TOOLING and atlas ownership/recovery guidance; run direct Python regressions, mapped infra/test_harness and architecture guards, then the recorded full suite before close. Let measured added code decide quick/full flow.~~ (Scheduling superseded below; passing verification remains required before landing.)
- [x] Update guidance, run direct/mapped checks and lint, and submit the recorded suite on the pushed final code. Overlap close review with the queued suite under tl-worker's explicit scheduling rule; require its passing record before landing. Let measured added code decide quick/full review.

## Log

Filed unclaimed as an independent harness defect discovered during #407 close rework. The #407 worker serializes its remaining targeted checks; its previous recorded full suite was green and this targeted interruption is infrastructure evidence only.

### 2026-10-22 — claim and investigation

- Claimed by parley.nvim:3 and entered planning on its own branch from main. No implementation yet; dispatch requested claim and plan.
- Signal-free process-table reproduction: first run make=100, shell=101, healthy harness=102; second census=201 under make=200. Current ancestry excludes [1, 200, 201], while select_orphans selects healthy pid 102. The grace period proves persistence, not abandonment.
- TOOLING explicitly prohibits overlapping runs, including distinct TEST_ENV_ROOT values, because the census is checkout-wide. Full runs also delete shared scratch before tests. Protect the whole run, not only the reaper's signal loop.
- start-plan refreshed the ariadne dependency and generated an unrelated tracked merge-check workflow diff (quiet grep pipefail correction). Preserved separately in the named stash `pre-409 weave refresh generated merge-check workflow`; it is not part of this issue and must not be committed with it. Retrying start-plan succeeded.
- Proposed lease design below awaits TL approval: it adds an ownership mechanism, so tl-worker's design-approval rule applies even if the implementation fits quick flow.

### 2026-10-22 — approved implementation and regression evidence

- TL approved the lease design in Couch delivery 437c8ee8-aff9-43b7-916f-216987746bb5; additionally required a holder diagnostic while waiting and help text explaining same-checkout serialization. Entered quick-flow implementation through change-code.
- Red: the new gated real-make regression failed on the original code: second targeted run entered instead of waiting for the active owner. Green: 12 disposable process/lease tests pass, covering two targeted runs plus manual after census, separate checkouts, nested wrappers/status propagation, owner death, inherited-child lifetime, waiter cancellation, invalid/independent descriptors, path aliases, real orphan cleanup in both phases, target coverage and recursive dry runs.
- The first mapped infra/test_harness run exposed Apple's make 3.81 recursive MAKEFLAGS spelling (`--no-print-directory -n`). Checking only its first word missed dry-run mode in recursive make. Interrupted that blocked spec through its own exec session, fixed the flag check, and added a gated recursive dry-run regression. The remaining mapped tests finished without assertion failures, including the Python lease tests, native reaping and isolation checks; that interrupted run is not passing-suite evidence. Fresh mapped run and recorded suite are next.
- Fresh `make test-spec SPEC=infra/test_harness` passed with a clean final census (log /Volumes/TestScratch/tmp/parley.nvim-slot3/parley409-harness.L4c1tR). Before the recorded suite, two additional focused regressions exposed overlapping `make -j` goals within one lease and a missing outer help prerequisite; both failed before the two-line Makefile correction and now pass. Native `.NOTPARALLEL` orders goals within the same owner; the wrapper retains help-parley for mixed goals. Direct Python checks now pass 27 tests, including 14 lease/process cases and 13 existing predicate/sampling tests. Recorded suite on the final commit is next.
- `make lint` passed: 0 warnings/errors in 822 files. PR #332 is pushed at code head 53b4585618179812e132c549dab4b3363e4dfc2c. Recorded suite run lease-3134723290 on that head is retained, queued at position 12 behind machine-wide admission; no suite outcome yet. Close review may overlap this queued run per the current tl-worker contract. No landing before its verified pass.
- Close round 1 returned REWORK: BR-1 Critical, family harness-entry-ownership. The reviewer reproduced a healthy harness killed through an alias because MAKECMDGOALS sees requested goals, not the transitive recipe graph. Code inspection confirms the dispatcher is conditional on a directly requested protected target. No close finalized. Cancelled the obsolete queued suite through `sdlc local-check cancel --run lease-3134723290`; cancellation confirmed, no suite result exists.
- Stopped for re-plan rather than another dispatcher patch. Revised durable plan: [target-execution admission](../plans/000409-test-run-lease-plan.md). It retains the approved resource/lifetime model, moves admission into unconditional protected public targets, guards internal bodies with validated descriptors, and adds alias/default/internal-entry regressions. Await TL approval before implementation.

## Revisions

### 2026-10-22 — BR-1 target-execution admission

Reason: direct-goal inspection cannot cover aliases, prerequisites and default goals. Delta: the original proposed MAKECMDGOALS routing is superseded by unconditional wrappers at every protected target, forwarding to descriptor-guarded internal recipes. The durable [revised plan](../plans/000409-test-run-lease-plan.md) is the current implementation design; the original lifetime lease and Done-when contract remain in force. No additional issue or ownership mechanism is introduced.

### 2026-10-22 — verification scheduling

Reason: the machine-wide suite queue is long. Delta: use tl-worker's explicit permission to overlap close review with a queued recorded suite, while retaining the exact run and requiring its pass before landing. The original Spec and Done-when requirements remain unchanged; this revises scheduling only. No claim of a full-suite pass is made before the run finishes.

### 2026-10-22 — proposed implementation design

Reason: investigation confirms that process persistence and checkout identity cannot distinguish an active sibling run. Delta: choose the existing Spec's serialization alternative; keep the original acceptance criteria.

One kernel-held exclusive lease per physical checkout spans scratch preparation, before census, target execution and after census. A small Python command wrapper runs the command with an inherited locked descriptor; recursive make and reaper calls reuse only a descriptor validated against the same lock inode, never an environment boolean or a PID alone. The lock file is a fixed ignored file in the checkout, outside test-clean-env's removable leaves. Never unlink a live or idle lock pathname: stable inode identity prevents split locks. Its fixed one-file footprint ends with checkout removal (ARCH-FUNERAL).

Makefile entry coverage includes test (before test-clean-env), test-unit, test-integration, test-compat, test-spec, test-changed, perf, perf-finder, goldens, fixtures, check-couch-actors-live, and standalone test-clean-env. Sweep PREP_TEST_ENV/ORPHANS consumers to catch any additional entries. A wrapper dispatches to the protected recipe; nested make must reuse the inherited lease without releasing it between targets. Standalone live reaper calls take the same lease; recorded --ps-from mode remains signal-free. The existing machine-wide full-suite admission remains separate and unchanged. No changes to inherited Makefile.workflow, local gates, or CI configuration (ARCH-DRY, ARCH-PURPOSE).

Alternatives considered: exempt live ancestry from census (more process-identity heuristics and still races scratch deletion); keep the documentation warning (does not enforce the invariant). The shared full-suite helper is unsuitable for this lock: it is machine-wide admission, only wraps full suites, and is unavailable in standalone contributor archives. Use the same standard kernel primitive without copying its fleet queue machinery.

Actions: run, wait, cancel, retry.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|---|---|---|---|
| Another command owns checkout lease | waiting; no scratch or census effects yet | wait or cancel waiting command | none |
| Lease acquired, command running | normal test output | wait or cancel run | interrupted test progress |
| Recursive make / reaper inherits valid lease | normal nested command output | wait | none |
| Invalid inherited descriptor / lock IO failure | explicit failure before destructive work | retry after correcting the reported input | none |
| Owner interrupted while child remains | checkout stays owned until protected command ends | wait for its shutdown, then retry | interrupted run; survivors checked next run |
| All holders exit, leftovers remain | next run acquires lease and performs existing before census | retry run | abandoned test processes are reaped |

Cancellation must not return a free lease while its protected command remains active. Test parent/wrapper death and nested-child exit ordering using disposable subprocesses; do not signal the live fleet. Standalone old commands started before this change are outside the new lease contract and must finish before rollout. Queue fairness and simultaneous tests sharing a physical checkout are not promised; different checkouts remain independent. Existing reaper process-shape validation and bounded resampling remain its signal authority (ARCH-ORDER, ARCH-SECURE).

The wrapper is a thin IO owner over flock and subprocess argv; existing pure process-table parsing/selection stays separate. Tests use gated disposable commands plus the existing recorded-table seam, with real flock/process conformance every suite; no new service or external binary is introduced (ARCH-PURE, ARCH-MOCK). This is batch test infrastructure, not an editor hot path: one lease acquisition per outer run, constant descriptor/file footprint per checkout, no process-table scan added per spec. Waiting lasts until the holder finishes and remains cancellable; test ordering uses ready/release gates, not timing guesses (ARCH-CONSTRAINTS). No persisted record format changes (ARCH-EVOLVE).
