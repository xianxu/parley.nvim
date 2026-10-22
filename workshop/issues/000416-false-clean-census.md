---
id: 000416
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours: 2.68
collaboration-mode: collaboration
card_mirror: '90cb5024273127be3c7f9b1da5b25fd50e4d21fa' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T16:14:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
---

# Test census reports clean while an orphaned embedded Neovim survives

## Problem

A completed targeted #405 native test run reported `clean: no surviving test processes` while an embedded Neovim from that exact run remained alive for about six hours, orphaned under PID 1. A clean census is currently capable of giving false assurance.

Related: #409, the test-lease and orphan-reaper work that protects active targeted runs. This is the complementary false-negative case: a completed run's survivor must be detected without touching a live or foreign run.

## Spec

Investigate why the census missed the surviving embedded editor from the 2026-10-22 08:55 #405 red run. Make the run's cleanup and terminal census agree about owned process lifetime: a surviving owned child cannot produce a clean result. Preserve #409's exact run/lease ownership and active-run protections; do not broaden cleanup into an unproven PID or process-group sweep.

Evidence observed on 2026-10-22 around 14:57–14:58 America/Los_Angeles:

- PID 69636, native start time `Thu Oct 22 08:55:00 2026`, PPID 1; exact executable `/opt/homebrew/Cellar/neovim/0.12.5_1/bin/nvim`, argv `--clean --embed --headless -i NONE`.
- Working directory `/Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim`; stdin/stdout/stderr all `/dev/null`.
- `lsof` showed an open temporary directory and Unix socket under `/Volumes/TestScratch/parley-405-runtime-fixture-red/tmp/nvim.xianxu/LFa2op/`, socket `nvim.69636.0`. This identifies the completed historical run, not the individual test case.
- Run log `/Volumes/TestScratch/parley-405-runtime-fixture-red.log` exercised `tests/arch/embedded_rpc_spec.lua`, `tests/integration/embedded_nvim_spec.lua`, `tests/integration/remote_runtime_fixture_spec.lua` and `tests/integration/remote_runtime_spec.lua`. The fixture/default-getter red assertions failed, and the run exited nonzero, but its final census still printed `clean: no surviving test processes`.
- After rechecking the exact PID/start/PPID/argv/cwd, SIGTERM failed to end it within five seconds. The same identity was checked again, SIGKILL sent to that PID only, and native `ps` then confirmed absence. No process group, other PID or runtime directory was removed.

The leaked run predates the later #405 fixture and parent/child cleanup changes. Establish whether those changes address the escape and whether the independent terminal census still has the blind spot; do not claim the historical leak is reproduced by current code without evidence. The individual leaking case is presently unknown.

## Done when

- A deterministic native regression creates a run-owned embedded child that survives its caller and ignores TERM, and proves the terminal census cannot report clean while that exact process remains alive.
- The root cause of the historical false clean result is documented; cleanup observes joined death or reports an explicit surviving/unknown outcome and fails the run.
- Active targeted-run, foreign-process, PID-reuse and uncertain-ownership controls preserve #409's protection contract; no cleanup claims success from a signal alone.
- The affected regression and ownership controls pass on Neovim 0.12.5 and the supported 0.11.7 compatibility runtime.

## Plan

- [ ] Implement the approved design in [the durable plan](../plans/000416-false-clean-census-plan.md), with native red/green coverage before changing cleanup.
- [ ] Verify exact ownership, observed death, refusal paths, both supported runtimes, and #409 serialization; record the pushed-head full suite and close review.

## Revisions

### 2026-10-22 — proposed design after native false-clean reproduction

Extend the existing spec-job birth ledger through the terminal census, scoped to the existing checkout lease. Retain PID plus native start identity; join exact children on every runner return and let the independent census verify retained records. Unknown observations fail visibly and preserve evidence. See the durable plan for the state table, alternatives and bounds. This is proposed to the TL; implementation has not started.

## Log

### 2026-10-22 — filed unclaimed at the TL's request

Historical survivor reported by ops:0, attributed through native process identity and its open run-specific socket by parley.nvim:1, and removed after exact revalidation. #405 records this incident at commit 36027746. This issue tracks the false clean census separately; no fix or new reproduction is claimed here.


### 2026-10-22 — investigation and proposed plan

Claimed and started on main-based branch `000416-false-clean-census`. The selector requires the checkout's `tests/` substring before considering any process, so the historical bare embedded command is categorically invisible. Current `spec_runner.execute` deletes the per-spec jobs directory after an ordinary exit without reconciling recorded jobs; `embedded_nvim.stop` ignores its wait result. #405's unlanded branch adds on-exit/join proof for fixture deletion but leaves the independent census classifier blind. Its exact historical leaking test remains unknown; no claim is made that the same test still leaks.

A disposable native probe on Neovim 0.12.5 spawned the historical exact argv, sent an RPC that published readiness then spun, and let its launcher exit. Native ps observed PID 48080 with PPID 1; TERM left it alive. The current signal-free census on that real captured snapshot returned 0 and `clean: no surviving test processes`. The probe's finally block sent KILL only to its own created child. Evidence: `/Volumes/TestScratch/parley416-census-d93c83gn/{owner.py,ps.txt,ready}`. Regression must record the new PID/start at birth rather than treating these historical numbers as authority.

`start-plan` refreshed the base and encountered ariadne#557's generated workflow change. Saved its exact diff to `/Volumes/TestScratch/parley416-seeded-jnnx_p97/merge-check.patch`, restored only that seeded file, then reran start-plan successfully. The separate pre-#409 named stash remains untouched. ARCH-DRY motivates reusing the existing native identity reader and spec-job ledger; ARCH-PURPOSE requires an independent terminal check, not only a nicer stop helper.


### 2026-10-22 — approval, coordination and plan-quality refinement

TL approval delivery 68e17798-f625-46d7-bd8c-956b912807d2 permits the retained registry under this checkout with explicit bounds/pruning. Parley.nvim:1 confirmed #405 owns Child on_exit/joined fixture cleanup, not spec_jobs/spec_runner/identity/census; preserve callbacks exactly once and install recording explicitly in clean embedded children. Neither branch stacks; whichever lands second integrates main. Full-flow plan-quality was explicitly requested because the scripts/native bridge exceed the quick shell. Round 1 raised PQ-1 (spawn-before-publication crash window) and PQ-2 (function-level test strategy); the plan now specifies durable pending tickets before spawn and names each risky function with an adversarial strategy. Both exact Neovim 0.12.5 and installed 0.11.7 runtimes are available. No implementation has started.


## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. Calibration is tagged stale by sdlc, so provisional. Two focused Lua components cover retained registry/native observation and runner/census integration; the shell context is a cross-cutting refactor, with docs and one close review. Existing LuaJIT native reader, libuv, JSON, make and flock provide the substrate; no novel external library is required. Thorough approved plan discounts the midpoint Lua design (2h) to 0.4h per component; impl uses the upper 1.5h x 40% = 0.6h per component. Familiarity is 1.0 and thorough-plan design buffer 15%.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.6
item: cross-cutting-refactor design=0.1 impl=0.2
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0.02 impl=0.16
design-buffer: 0.15
total: 2.68
```


### 2026-10-22 — retained ownership implemented; focused verification

Full change-code passed: plan-quality has no open findings (PQ-1/PQ-2 addressed); estimate-quality INFO accepted the model but noted optimistic integration/verification coverage. Those checks are included in the two Lua integration components and the existing close-review allocation; measured actual will resolve the calibration.

Implemented checkout-local `.test-processes/run-*` context reuse under the validated descriptor; strict context checks and owned empty-directory pruning are covered by 25 direct lease tests (all pass, 14.659s). The delegated policy's seven tests pass. Shared native reconciliation now consumes durable pre-spawn pending tickets, atomically published PID/start records, and old jobs ledgers. Unknown/corrupt evidence stays; exact PID effects require an immediately matching native identity and records retire only after observed original-incarnation death plus unchanged evidence bytes. The terminal Python census requires positive completion from the same native Lua verifier before printing clean.

Five native regressions pass: ordinary-success detached leak, independent terminal orphan/TERM resistance with a same-argv foreign control and signal-free snapshot, launcher death inside birth publication, clean embedded grandchild recording, and callback/fast-child ownership. The callback test first failed because an already-reaped native job was treated as an unconfirmed birth; the wrapper now chains on_exit once, recognizes joined death, and installs once. Storage regressions first caught dropped future JSON nulls, retirement of replaced birth bytes, and writable-directory admission; all fifteen registry tests now pass after correcting those classes. Native/policy/registry run log `/tmp/parley416-storage-green.log`; original native RED `/tmp/parley416-native-red.log`; callback RED/GREEN `/tmp/parley416-callback-{red,green}.log`. Python predicate/observation tests: 14 pass, including a silent exit-zero observer that must remain unknown. Focused Lua lint and diff checks pass.

The first broad mapped harness run correctly failed the new JSON-null check and the existing embedded-RPC architecture guard. Native probes now use the central Embedded helper's optional detach and notification support, keeping the guard intact; no guard exception was added. Parley.nvim:1 was informed of these small helper additions so its #405 native on_exit/joined fixture cleanup remains authoritative when either branch integrates main.

Next: finish broad mapped tests on preferred 0.12.5 and affected regressions on installed 0.11.7, check retained-tree allocation/pruning bounds and late-publication controls, then push and queue one recorded suite before close. No full-suite result for #416 exists yet; no close/PR/landing claimed.
