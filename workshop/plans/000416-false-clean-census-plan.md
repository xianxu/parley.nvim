---
collaboration-mode: discussion
---

# False-clean census implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A surviving recorded embedded child cannot yield a clean terminal census, even after its parent exits and TERM fails.

**Architecture:** Keep #409's checkout-wide flock as admission authority. Extend the existing per-spec birth ledger to survive until observed child death and the final census; use the existing native identity reader for both runner cleanup and census verification. The Python census retains its narrow legacy command classifier and calls one small native Lua verifier for recorded children; no expanded argv/cwd/socket heuristic authorizes cleanup.

**Tech stack:** Python 3, LuaJIT/libuv, Neovim 0.12.5 and 0.11.7, POSIX flock, make.

## Evidence and alternatives

The historical exact command has no checkout/test path and is rejected by `select_orphans` before its embedded/headless options are inspected. A fresh native probe reproduced that classification failure with the same argv, a readiness-gated infinite RPC, launcher exit, PPID 1, and TERM resistance. This proves the census blind spot, not which historical #405 test leaked. Current runner cleanup deletes its job ledger on ordinary completion without proving all recorded jobs died.

1. **Recommended: retained birth evidence plus reconciliation.** Reuse native PID/start identity and the spec-job registry; retain exact ownership through reparenting and both cleanup consumers.
2. Broaden argv/cwd/open-socket matching. Reject: those are diagnostic clues shared by live or foreign editors, not exact run ownership.
3. Strengthen only `Embedded.stop`. Reject as sufficient: abnormal caller death and failed teardown can bypass that method; an independent final census is an acceptance criterion. #405 already adds joined fixture cleanup on its unlanded branch; coordinate that overlap rather than stacking branches or duplicating its fixture implementation.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| Owned-child observation policy | `tests/helpers/test_process_model.lua` | new |

The policy consumes a birth record and explicit observation (same identity, absent, different identity, unavailable), and produces keep/reconcile/refuse and a visible reason. A PID/start pair names one child incarnation. A successful signal is never an exit observation. Unit cases use data, not mocked operating-system calls. Unknown native identity is distinct from a proven absent process; a mismatch never authorizes signaling the replacement.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Native identity observation | `tests/helpers/process_identity.lua` | modified | Darwin proc_pidinfo / Linux proc stat and libuv existence |
| Shared retained process registry | `tests/helpers/test_processes.lua` | new | private files, native observations, exact PID signals and bounded joining |
| Job birth recording | `tests/helpers/spec_jobs.lua` | modified | existing jobstart wrapper and per-spec jobs |
| Spec lifetime reconciliation | `tests/helpers/spec_runner.lua` | modified | native Plenary child, every exit/error/cancellation path |
| Lease-scoped run context | `scripts/test-run-lease.py` | modified | existing descriptor authority and private registry directory |
| Terminal recorded-child verifier | `scripts/test-process-census.lua` | new | shared Lua registry, invoked as a headless script |
| Combined census result | `scripts/reap-test-orphans.py` | modified | existing ps boundary plus verifier exit/result |

The existing native identity implementation is reused, not translated into a second Python PID reader. The IO module feeds observations into the pure policy. A stateful observation fake provides explicit sequences (live→gone, live→reused, unavailable, signal denied, no effect); native conformance exercises the same seam with actual children. Captured ps tables remain signal-free.

## Ownership and lifetime

- Only a validated outer checkout lease allocates a unique run directory under the checkout’s own Git metadata `parley-test-processes/` (archives without Git use ignored `.test-processes/`); recursive make reuses its run context. Different checkouts retain independent directories and locks. Validate inherited context against its physical checkout before reuse, as with the existing FD.
- Pass the registry context through `Makefile.parley`/`scripts/test-env.sh` explicitly. A recorded child does not need to retain the lease FD: doing so could prevent the next census from acquiring the lease and cleaning a survivor.
- The spec runner allocates its private child-ledger directory inside that run. Each successful jobstart records PID plus native start identity before returning to the test. Keep the existing narrow spawn seam; enumerate existing embedded/jobstart consumers and enforce the wrapper rather than adding a parallel embedded-only registry.
- Before **any** child creation, persist a pending-registration ticket in the private spec ledger. Only after successful native birth observation does an atomic replacement publish PID/start. Launcher death between ticket, spawn and completion leaves pending evidence, which always fails unknown and never authorizes a signal. A failed spawn removes its ticket only when the launcher still owns the no-child result. An unconfirmed post-spawn failure retains the ticket. Record creation is checked, never best effort. If native birth observation or durable recording fails, stop/join the just-created child via the still-owned job channel, fail the spec, and retain an unresolved registration marker if death cannot be established. Missing/malformed/truncated records and permission failures mean unknown, not an empty successful registry.
- Reconcile recorded jobs on ordinary success, failed assertions, bootstrap error, deadline, signal interruption and unobserved spec exit. TERM then bounded grace then exact PID KILL is permitted only with a fresh matching identity. Poll until original identity is absent or replaced; replacement proves the old incarnation ended but never permits signaling the new process. Recheck identity immediately before every effect.
- Keep existing deadline process-group behavior separate; do not introduce a new group sweep or infer group ownership from missing identity. New census cleanup signals exact recorded PIDs only. If inspection finds a required change to existing group authority, stop and take that scope change to the TL.
- Terminal census under the same checkout lease reconciles all retained run ledgers, including a prior interrupted run. A found surviving child makes the after phase fail even if cleanup eventually succeeds. Failure to inspect/join returns nonzero with surviving/unknown evidence; no clean line. Before phase may proceed only after its proven old children are gone and there is no unresolved ownership state.
- Keep evidence outside TEST_ENV_ROOT so `test-clean-env` cannot erase it. Retire a child record only after observed original-incarnation death. Remove drained per-spec directories; leave the current empty run directory until its lease owner ends, and collect prior empty run directories at the next outer admission. Unresolved directories survive for retry. Never delete runtime/socket fixtures as part of this census.

## Visible state and recovery

Actions: run a test, retry the same census, inspect the reported evidence.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|---|---|---|---|
| All recorded incarnations observed gone; legacy census clear | clean | run a test | none |
| Matching child survived caller/TERM, then joined after KILL | leaked; run failed; exact child ended | run a test after fixing teardown | child execution ended; output already captured |
| Matching child still alive or signaling denied | surviving; run failed; record retained | retry same census after resolving permission/liveness | none automatically discarded |
| Identity unavailable, malformed ledger, registration failure | unknown; run failed; record retained; no speculative signal | inspect reported evidence, then retry same census | successful completion cannot be asserted |
| PID now names a different native start identity | old child exited; replacement untouched | run a test | none |
| Another active run owns the checkout lease | waiting; existing holder diagnostic | wait for lease admission | none |

Covered: exact recorded children, reparenting, ordinary and exceptional exit, cancellation, PID reuse, refusal and foreign checkout controls. Not covered: arbitrary unrelated machine processes or attribution of the already removed historical PID. They cannot be made owned by a heuristic. The historical test case remains unknown.

## Resource and format contract

Run data is single-owner per spec with atomic manifest/marker publication; no shared multiwriter append file across parallel specs. New records use versioned JSON (PID, opaque start identity, run/spec provenance); parse known fields strictly and reject duplicate keys. Preserve unknown fields on a rewrite; delete only a fully retired original record. Existing `pid start` job records remain readable during transition rather than silently losing ownership evidence.

Start with explicit caps: 4096 child records per spec, 256 retained run directories per checkout, 1 MiB per manifest. Admission/recording at a cap fails unknown and retains existing evidence; it never drops records. No cap authorizes cleanup. Successful runs leave no child records; old empty run directories are collected by the next lease owner. Repeated unresolved failures consume bounded disk and block further admission for diagnosis.

For N birth records and P process-table rows, one census round costs O(N + P): one registry traversal, one ps parse, one native observation per record, and a fixed bounded number of poll rounds. No per-child full ps/lsof or registry rescan. Native verifier startup occurs once per retained base per census phase (normally one; two while a legacy `.test-processes/` container remains); no new per-request subprocess. Counted N/2N tests reject quadratic scans. Use existing grace bounds (default census grace 8s; runner grace 1s), with a separate bounded post-KILL join and no sleeping after proven absence. Tests control time for policy sequences.

## Function-level verification contract

| Functions under test | Adversarial strategy and mechanical guard |
|---|---|
| `test_process_model.classify(record, observation)` | Generate birth/observation combinations including malformed identity; only a matching live identity permits an effect, absent/replaced retire only the old incarnation, unknown/pending never pass. |
| `process_identity.observe(pid)` | Native self/dead-child conformance plus unavailable-result decoding; distinguish verified absence from an unreadable native result. |
| `test_processes.prepare(dir)`, `complete(ticket, pid)`, `abort(ticket)` | Stateful interruption seam after pending publication, after spawn and before completion; each prefix either has joined death or retained unknown evidence. Run one native launcher killed at the seam. |
| `test_processes.read(dir)` | Generate bounded malformed/duplicate/truncated records and future unknown members; refuse malformed known data, preserve original evidence, never decode invalid storage as empty. |
| `test_processes.reconcile(dir, deps)` | Stateful native-observation/effect sequences with controlled time; signals require an immediately matching identity, success requires later absence/replacement, failure retains evidence. Count probes/visits at N and 2N for linear fixed-round work. |
| `spec_jobs.install()` | Actual jobstart with callback counting and clean embedded descendants; preserve each supplied on_exit exactly once and persist tickets before each spawn. |
| `spec_runner.execute(path, options)` | Native subprocess termination through controlled lifecycle boundaries; assert owned incarnations gone or explicit failing unknown result at return. Keep existing deadline suite as the conformance guard. |
| `test-run-lease.run_context(root)` | Extend existing real-make lease fixture with nested/foreign/malformed context generation; admission and bounds precede effects, retained unresolved data survives scratch cleanup. |
| `reap-test-orphans.main(argv)` / `test-process-census` | Real captured historical argv plus native orphan RPC spinner; after verdict cannot be clean while the recorded incarnation lives. A same-argv foreign child is the negative control, and snapshot mode sends no signals. |

The regression owns all its created children and uses exact-handle finally cleanup on both red and green. Native lifecycle checks run on both available runtimes: preferred 0.12.5 and installed `/opt/homebrew/bin/nvim` 0.11.7. No timing-only assertion or signal-send result establishes death.

## Implementation tasks (one atomic close; no milestones)

### Task 1: Reproduce and define observation policy

**Files:** `tests/unit/reap_test_orphans_pure.py`, new `tests/unit/test_process_model_spec.lua`, new `tests/integration/test_process_census_spec.lua`, `tests/helpers/process_identity.lua`.

- [x] Turn the disposable historical-argv probe into the named census regression and observe RED before changing cleanup.
- [x] Implement `classify` and `observe` through their function-level contract above; keep the legacy command classifier narrow.
- [x] Commit the regression and model.

### Task 2: Retain birth evidence and reconcile every exit

**Files:** new `tests/helpers/test_processes.lua`, `tests/helpers/spec_jobs.lua`, `tests/helpers/spec_runner.lua`, `tests/helpers/embedded_nvim.lua`, `scripts/test-run-lease.py`, `scripts/test-env.sh`, `Makefile.parley`, `.gitignore`, corresponding unit/native specs.

- [x] Implement pending→born→retired registration and checked persistence through the interruption seam; no spawn precedes its durable pending ticket.
- [x] Allocate/reuse run context under validated checkout lease; move private ledgers there and pass context through the existing environment allowlist.
- [x] Wire registry recording to the existing jobstart wrapper, install it explicitly in clean embedded children, and reconcile every runner return. Follow the function-level test contracts and commit tested wiring.
- [x] Preserve #405's on_exit callback exactly once and its Child-only fixture cleanup authority. The peer confirmed no intended edits to spec_jobs/spec_runner/process_identity/reaper; whichever lands second integrates main, never the other's unlanded branch.

### Task 3: Independent census and landing

**Files:** new `scripts/test-process-census.lua`, `scripts/reap-test-orphans.py`, `tests/integration/fixture_reaping_spec.lua`, Python/Lua census tests, `atlas/infra/test_harness.md`, `atlas/traceability.yaml`, `TOOLING.md`, `workshop/lessons.md`.

- [x] Combine the legacy census and shared retained-child verifier verdicts; any leak/unknown fails and suppresses clean, including in interrupted-registration recovery.
- [x] Finish native RED→GREEN and refusal/concurrency coverage through the function contracts; verify pruning and explicit writer bounds.
- [x] Run `python3 tests/unit/reap_test_orphans_pure.py`, `python3 tests/unit/test_run_lease.py`, then `make test-spec SPEC=infra/test_harness`; expected all pass. Run the mapped affected regressions under each exact `PARLEY_TEST_NVIM` runtime above.
- [x] Update atlas/traceability, tooling and lessons; log exact evidence and the #405 integration boundary.
- [x] Push PR #336 and queue one recorded full suite via `sdlc local-check run --name suite` on the corrected code head (`lease-3515239873`).

Final acceptance remains gated on that suite result, the binary-owned close review, and `sdlc merge --yes` authoritative integration and landing. The close review may overlap the queued suite under tl-worker rules; none of those future outcomes is claimed here.

## Architecture checklist

- **ARCH-DRY:** One native identity reader, one recorded-child reconciliation module; runner and terminal census share it. Preserve the checkout lease as sole admission owner.
- **ARCH-PURE:** Observation→decision policy is data-only; persistence/native probes/signals are thin integration points.
- **ARCH-PURPOSE:** Independent final census catches a child after caller death; improving only stop is insufficient.
- **ARCH-MOCK:** Stateful observation sequences plus native spinner/foreign-process conformance, no call-count mocks as lifecycle proof.
- **ARCH-CONSTRAINTS:** Fixed deadlines, explicit writer caps, linear counted work, one verifier process per retained base per census phase (at most two during legacy migration).
- **ARCH-SECURE:** Only lease-bound private birth records and freshly matching native identity authorize exact PID effects; command text, cwd and socket names do not. Native regression covers foreign/uncertain ownership and both runtimes.
- **ARCH-ORDER:** Birth recording precedes returning a child to its caller; every return reconciles owned children before deleting evidence. A signal or leader exit cannot imply joined child death.
- **ARCH-FUNERAL:** Records retire on proven death; drained directories collect at explicit phase/admission boundaries, unresolved residue is bounded and visible.
- **ARCH-EVOLVE:** New strict JSON schema preserves unknown members on rewrite; old job record semantics retained during transition.

## Approval

Proposed to the TL. No implementation authorized by this document alone. The retained registry is a new mechanism, so wait for the hub's design approval before `sdlc change-code`.


## Revisions

### 2026-10-22 — TL approval and plan-quality PQ-1/PQ-2

TL approved the retained registry with checkout-local placement, explicit bounds/pruning and #405 coordination. The proposed `.test-processes/` already meets placement. PQ-1 adds a **durable pending ticket before every spawn**, making death before PID publication recover as unknown, never clean. PQ-2 replaces prose case inventories with named functions and adversarial/mechanical strategies. Native spawn interruption is a controlled seam, not a sleep race. Parley.nvim:1 confirmed callback and clean-child bootstrap constraints, now included explicitly.


### 2026-10-22 — implementation bounds and compatibility details

The shared registry publishes immutable per-child JSON records, up to 4096 slots of 256 bytes per outstanding spec scope (1 MiB), with at most 64 outstanding scopes per run and 256 retained runs. Publication can temporarily use one additional bounded file per slot. Root admission/pruning and Lua observation reject symlinks, foreign owners and group/other-writable directories. Existing pid/start jobs ledgers remain readable with a 1 MiB bound. Empty scopes prune after observed reconciliation; prior empty run roots prune at the next lease admission. Retained unknown/corrupt records are never wiped with scratch.

The native RPC architecture guard requires even adversarial census spinners to use the central Embedded helper. Its optional detach and no-reply notify method support these probes; clean children install the existing jobstart wrapper explicitly. The wrapper chains the original callback exactly once, including already-delivered exit callbacks; joined native death may retire a pending ticket for a child that exited too quickly to publish identity. This preserves #405's Child-only fixture authority. Publication preserves unknown nested members including JSON null, and retirement re-reads the original bytes before unlinking so it cannot erase a newer birth.


### 2026-10-22 — preserve native directory walks during registry retirement

A native `find .` probe failed on iteration 3 when a scope under the working-tree `.test-processes/` retired. Move the same bounded registry to `git rev-parse --absolute-git-dir` plus `parley-test-processes/`, validating checkout root and ownership. This is the per-worktree Git directory, never the shared common directory. No-Git archives retain the fallback. The census must read both new and existing legacy bases, preserving unknown evidence across migration; only a drained legacy container retires. Two bases temporarily mean two bounded verifier invocations. The command-substitution safety test searches immutable `lua/parley` instead of all Git/test metadata, preserving its argument-injection assertion in plain clones as well.

Added native Git checkout/worktree placement and retained-legacy unknown tests, both first failing before the fix. Cancelled obsolete recorded suite `lease-2698737677` on the previous head before it ran; a single replacement will run on the corrected pushed head. This remains the approved lease-scoped registry and approved Git placement, without a new state mechanism.


### 2026-10-22 — verification handoff to acceptance gates

Targeted implementation verification is complete on both runtimes and the broader harness passes. Split the final implementation checkbox from the acceptance gates: PR #336 and the one recorded suite are prepared; the still-pending full-suite result, close verdict and integration/landing remain explicit gates, allowing the tl-worker-approved close-review/queued-suite overlap without falsely recording those outcomes as complete.


### 2026-10-22 — close round 1: lossless values and atomic scope capacity

BR-1: publication must retain raw top-level unknown member slices from the validated JSON, including nested numeric tokens, rather than round-tripping them through Lua's number representation. Rewrite only known birth fields. Regression oracles compare original numeric text directly, covering large signed integers, precise decimals, exponents and negative zero; decoding both sides would hide the defect.

BR-2: reserve one of 64 canonical scope directories with native atomic mkdir, so simultaneous runners cannot both consume the final slot. New outer contexts are fresh; noncanonical leftovers are a visible refusal at allocation, while census still reads old random scopes. A controlled two-caller barrier at 63 slots must admit exactly one caller and keep the retained tree within the census bound. Scope retirement remains observed-death cleanup, with no extra lock that can strand after owner death.


### 2026-10-22 — BR-3: admission and retirement as one slot protocol

The second review disposes BR-1 and BR-2 but demonstrates a normal sibling retirement between enumeration and lstat. Re-plan the full `atomic-capacity-admission` family rather than treating a nil probe as absence. The finite slot directory is the single occupancy resource; mkdir is acquisition and successful empty rmdir is release. An extra count or independent lock is unnecessary: count cannot reserve, and a separate lock adds an owner-death cleanup obligation.

| Ordering / observation | Admission behavior | Evidence / recovery |
| --- | --- | --- |
| Two allocators see the final slot free | Exactly one mkdir succeeds; the other reports full | Native EEXIST is contention, not ownership |
| A sibling retires a listed empty slot before lstat | Explicit ENOENT permits continued reservation | No stale snapshot veto; mkdir owns the decision |
| A retired slot is reused before another caller reserves it | Existing canonical private directory remains occupied | EEXIST skips it; never returns another caller's scope |
| lstat cannot inspect an existing entry | Refuse visibly and retain evidence | EACCES/other errors never mean absent |
| Entry is malformed, foreign, writable, a symlink, or legacy random | Refuse allocation and retain it | Census still consumes legacy records under its existing rules |
| All canonical slots are occupied | Bounded visible full refusal | Retry after a runner reconciles and retires its scope |

Enumerate every scope creator/collector: `M.scope` alone acquires current-run slots; each spec runner calls `M.prune` only after shared reconciliation establishes death; terminal census collects drained scopes after runners complete; lease admission prunes prior empty runs before allocating a fresh context. Recursive lease reuse allocates no run and prunes nothing. Add controlled retirement-after-snapshot, retirement/reuse/contention and unreadable-existing-entry tests alongside the two-allocator regression. Preserve census and exact process-identity semantics.
