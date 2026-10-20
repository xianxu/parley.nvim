# Boundary Review — parley.nvim#402 (whole-issue close)

| field | value |
|-------|-------|
| issue | 402 — spec_runner's idle kill orphans a spec's embedded nvim children |
| repo | parley.nvim |
| issue file | workshop/issues/000402-spec-runner-s-idle-kill-orphans-a-spec-s-embedded-nvim-children.md |
| boundary | whole-issue close |
| milestone | — |
| window | 45ec2ab101bd9644318e25145d6638773391b96e..d07a3ac51f57971f3bb17587629aeeab85806978 |
| command | sdlc close --issue 402 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T22:02:43-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking how jobs are started across the tree, then running the new tests.

Figuring out the make target to run single specs.

I'll write a small wrapper that sets the same env and runs individual files.

All green. Now the red check: does removing `detach = true` still pass?

Notable: without `detach`, five older tests fail but all four #402 tests pass, so nothing covers the grandchild path `detach` is there for. Checking the registry red next.

Registry red confirmed. Last checks: any job starts that skip the `vim.fn.jobstart` wrapper, and no spinners left behind.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix works and its main claims hold up. The jobstart registry (Revision delta 1) is what makes the #402 tests pass: I removed `spec_jobs.install()` from `tests/minimal_init.vim` and all three #402 process-group tests failed, then put it back and they passed. The arch, unit and integration specs all pass at head (14/3/11). One item should be fixed before shipping. The Plan says "without `detach`, the idle case fails". That is no longer true. I removed `detach = true` and all four #402 tests still passed. Five older deadline tests failed instead, but only because `signal_group` now signals just `-child.pid`, which doesn't exist without detach. So `detach` is kept for a stated reason: catching `vim.system` and `uv.spawn` grandchildren. No test has such a grandchild, so that reason is never checked.

**1. Strengths**
- `spec_jobs.targets` (`tests/helpers/spec_jobs.lua:57`) is a pure function that takes the identity lookup as an argument. The unit test covers all three cases (same process, reused pid, exited) with no IO.
- Signals are guarded by pid plus start time, with a live check on a real process (`spec_runner_native_spec.lua:175`). This answers the hub's guard requirement directly.
- I checked the Darwin `proc_bsdinfo` layout field by field: it comes to 136 bytes and the start time sits at offset 120. The Linux `/proc/<pid>/stat` index (`fields[20]` = field 22) is also right.
- Every #402 case SIGKILLs any surviving child itself (`gone()`), so a red run leaves no spinner. I confirmed this across my own red runs.
- The normal-exit path is untouched: the `exit` event sets status to `completed`, so `expiring` is false and nothing gets signalled. That meets Done-when clause 2.

**2. Critical:** none.

**3. Important**
- **The `detach` grandchild path has no regression test** (`tests/helpers/spec_runner.lua:70`, `tests/integration/spec_runner_native_spec.lua:126-188`). The embedded nvim is a `jobstart` child in its own group, so the registry reaches it whether or not `detach` is set. The whole family in this window:
  - (a) idle-deadline case
  - (b) runner SIGTERM case
  - (c) runner SIGINT case

  All three only use `jobstart` descendants. Fix: add a fixture whose spec starts a `vim.system{"sleep","600"}` (or a `uv.spawn`) grandchild and records its pid. Assert it is gone after the idle kill, and confirm it goes red without `detach`. Also correct the Plan's red-check line.

**4. Minor**
- **Inconsistent fallback for the leader group** (`spec_runner.lua:60`). `Jobs.signal` falls back to the bare pid when the group signal fails, but the leader gets only `uv.kill(-child.pid)`. Without detach the leader is never signalled, which is what broke the five older tests. The leader is also signalled again after it has been reaped (the timer path plus TERM/KILL), with no identity guard. The pid-reuse window is about 1 s, so the risk is small, but it is the same hazard the registry guards against.
- **ARCH-DRY:** TERM → grace → KILL is written twice: `end_group` blocks with `uv.sleep` (signal-callback context) and the main path uses `vim.wait`. The split is justified by the fast-event context, but a one-line comment saying so would stop someone merging them.
- **Registry coverage limits aren't written down.** The wrapper only catches `vim.fn.jobstart`. `termopen`, `vim.api.nvim_call_function("jobstart")` and Vimscript `jobstart()` skip it. None of these appear in `lua/` or `tests/` today, but the atlas section could say the guarantee is limited to `vim.fn.jobstart`.

**5. Test coverage notes**
- Red/green checks I ran myself:
  - Removing the registry install: 3 #402 tests fail.
  - Removing `detach`: 0 #402 tests fail, 5 older tests fail.
- I did not run the watcher-removal red; the Log claims it, and the SIGTERM/SIGINT cases exist and pass.
- The Linux branch of `process_identity.start_time` can't run on this macOS host. I checked it by reading the code only.
- Done-when clause 1 is covered at both deadline and runner-signal triggers. Clause 2 is covered by the existing completed-spec tests plus the `expiring` gate.

**6. Architectural notes**
- **ARCH-DRY:** pass, apart from the Minor above.
- **ARCH-PURE:** pass. `targets` is pure and its lookup is injected; IO stays in `read`, `signal` and `process_identity`.
- **ARCH-PURPOSE:** flagged under Important. The registry delivers the issue's purpose, but the kept `detach` half has no test showing it does its job.
- **ARCH-EVOLVE:** pass. The ledger is a temporary file for one run, not a persisted format. Its reader is strict and drops malformed lines.

**7. Plan revision recommendations**
- Add to `## Revisions`: "Red check for `detach`: the #402 jobstart fixtures pass without `detach`, since the registry reaches them. Without `detach`, the leader is unreachable and the existing deadline tests fail. A `vim.system` grandchild fixture now pins detach's group coverage." Also correct the Plan step "without `detach`, the idle case fails".

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: kept-mechanism-untested
    title: |
      detach=true's grandchild-group purpose has no regression test; the #402 tests pass without it
    detail: |
      Reverting `detach = true` (spec_runner.lua:70) leaves all four #402 tests green, because the embedded nvim is a jobstart child the registry kills. Only five older deadline tests fail, because signal_group signals just -child.pid. Every instance in the window uses only jobstart descendants: idle-deadline case, runner SIGTERM case, runner SIGINT case (spec_runner_native_spec.lua:152-173). Add a fixture with a vim.system or uv.spawn grandchild whose pid must be gone after the idle kill, check it goes red without detach, and correct the Plan's red-check line.
  - id: new
    severity: Minor
    kind: defect
    family: signal-target-guard-asymmetry
    title: |
      Leader group is signalled without the bare-pid fallback or identity guard that recorded jobs get
    detail: |
      spec_runner.lua:60 sends only uv.kill(-child.pid). Jobs.signal falls back to the bare pid and checks start time first. The leader is also re-signalled after it is reaped (timer path plus TERM/KILL pass), with no guard against pid reuse in that short window.
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-escalation-sequence
    title: |
      TERM, grace, KILL escalation written twice (end_group with uv.sleep vs the main path with vim.wait)
    detail: |
      spec_runner.lua:63-67 and :108-112. The split is justified by the signal-callback context; add a comment, or share one helper that takes the wait function.
  - id: new
    severity: Minor
    kind: defect
    family: doc-scope-claim
    title: |
      Atlas and the spec_jobs comment don't say the registry only covers vim.fn.jobstart
    detail: |
      termopen, nvim_call_function("jobstart") and Vimscript jobstart() skip the wrapper. None are used today; say so in atlas/infra/test_harness.md under the #402 section.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"184c0dcb-071c-414a-abe5-a32867a3e902","repository":"github.com/xianxu/parley.nvim","issue_id":"000402","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/421fa4b390a3fb20","reviewed_head":"d07a3ac51f57971f3bb17587629aeeab85806978","slot":"parley.nvim:3","requested_at":"2026-10-20T04:57:59.823456Z"},"phase":"finished","pid":33968,"started_at":"2026-10-20T04:57:59.950006Z","finished_at":"2026-10-20T05:02:42.800631Z","session_id":"efe05a62-49c8-4c82-b849-d42ddfc81f33","outcome":"returned"}] -->
