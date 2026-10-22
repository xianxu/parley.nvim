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

- Only a validated outer checkout lease allocates a unique run directory under an ignored checkout-local `.test-processes/`; recursive make reuses its run context. Different checkouts retain independent directories and locks. Validate inherited context against its physical checkout before reuse, as with the existing FD.
- Pass the registry context through `Makefile.parley`/`scripts/test-env.sh` explicitly. A recorded child does not need to retain the lease FD: doing so could prevent the next census from acquiring the lease and cleaning a survivor.
- The spec runner allocates its private child-ledger directory inside that run. Each successful jobstart records PID plus native start identity before returning to the test. Keep the existing narrow spawn seam; enumerate existing embedded/jobstart consumers and enforce the wrapper rather than adding a parallel embedded-only registry.
- Record creation is checked, never best effort. If native birth observation or durable recording fails, stop/join the just-created child via the still-owned job channel, fail the spec, and retain an unresolved registration marker if death cannot be established. Missing/malformed/truncated records and permission failures mean unknown, not an empty successful registry.
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

For N birth records and P process-table rows, one census round costs O(N + P): one registry traversal, one ps parse, one native observation per record, and a fixed bounded number of poll rounds. No per-child full ps/lsof or registry rescan. Native verifier startup occurs once per census phase; no new per-request subprocess. Counted N/2N tests reject quadratic scans. Use existing grace bounds (default census grace 8s; runner grace 1s), with a separate bounded post-KILL join and no sleeping after proven absence. Tests control time for policy sequences.

## Implementation tasks (one atomic close; no milestones)

### Task 1: Capture the blind spot and observation policy

**Files:** `tests/unit/reap_test_orphans_pure.py`, new `tests/unit/test_process_model_spec.lua`, new native census regression fixture/spec, `tests/helpers/process_identity.lua`.

- [ ] Preserve a sanitized recorded historical command row and the current selector's intentional refusal; a bare embedded argv must not become ownership evidence.
- [ ] Add the native launcher/RPC spinner regression from the disposable probe. Register the birth through the actual seam, let its caller exit normally, assert PPID/liveness and TERM resistance before census. Own every fixture handle and exact cleanup in finally/after_each, including red assertions.
- [ ] Run the native case through the public make harness and capture RED: current census exits 0/prints clean while the exact created process is alive.
- [ ] Add table tests distinguishing same/absent/reused/unknown observations, including malformed identities. Extend the native observer result so absence and unreadability cannot both be nil authority. Test Darwin and Linux result decoding at the boundary.
- [ ] Commit the regression and model before wiring cleanup.

### Task 2: Retain ownership and reconcile every exit

**Files:** new `tests/helpers/test_processes.lua`, `tests/helpers/spec_jobs.lua`, `tests/helpers/spec_runner.lua`, `scripts/test-run-lease.py`, `scripts/test-env.sh`, `Makefile.parley`, `.gitignore`, relevant existing unit/native tests.

- [ ] Add one shared registry behind the pure policy; test stateful observation/effect sequences, strict persistence and unknown-field preservation.
- [ ] Allocate/reuse run context only under validated checkout lease; pass it through the existing allowlist. Add recursive/different-checkout/invalid-context cases to `tests/unit/test_run_lease.py`.
- [ ] Move spec ledgers to retained run storage and check birth recording. Add failure cases for inaccessible storage and unavailable birth identity; ensure an unrecorded surviving spawn leaves a failing unresolved marker.
- [ ] Run reconciliation before every runner return and preserve nonzero assertion/deadline/signal results. Mark `reaped` only from observed required exits, not a sent signal or only the spec leader's callback.
- [ ] Add ordinary-pass/failed-assertion/parent-exit/native TERM-resistant child cases, plus permission denial, reused PID and unknown identity controls. Keep the existing deadline and cancellation regressions green.
- [ ] Reconcile #405's Child stop/join overlap with its owner before changing `tests/helpers/embedded_nvim.lua`; reuse its joined-death proof if it has landed, otherwise keep #416 centered on runner/census ownership.
- [ ] Commit tested ownership wiring.

### Task 3: Independent terminal verdict and complete verification

**Files:** new `scripts/test-process-census.lua`, `scripts/reap-test-orphans.py`, `tests/integration/fixture_reaping_spec.lua`, Python/Lua census tests, `atlas/infra/test_harness.md`, `atlas/traceability.yaml`, `TOOLING.md`, `workshop/lessons.md`.

- [ ] Invoke the shared native verifier once from the census and combine both verdicts: any leak or unknown fails and suppresses clean; preserve --ps-from's signal-free contract and existing legacy candidate exclusions.
- [ ] Native RED→GREEN: the registered orphan is found despite generic argv, exact KILL is followed by observed original-child death, after exits nonzero with leak evidence; a second census is clean. Negative controls leave a same-argv foreign child and another checkout's active run alive.
- [ ] Exercise runner death followed by next lease owner's before census, nested make context, cancelled waiter, corrupt records, missing identity, PID reuse, and failed cleanup without erasing evidence. Run the entire existing #409 lease suite.
- [ ] Run `python3 tests/unit/reap_test_orphans_pure.py` and `python3 tests/unit/test_run_lease.py`; both must pass. Run `make test-spec SPEC=infra/test_harness` with the new mapped specs, then the same affected native cases with `PARLEY_TEST_NVIM` set to each exact supported runtime (0.12.5 and 0.11.7); report missing runtime to hub rather than installing silently.
- [ ] Count registry visits/native probes for N and 2N (e.g. 16 and 32) through a stateful fake; assert no more than doubled operations per fixed poll round. Verify retained records are bounded and drained records/directories retire on the documented boundary.
- [ ] Update harness atlas and lessons with the root cause and ownership/death contract. Log exact evidence and the #405 integration boundary.
- [ ] Push, run one recorded full suite via `sdlc local-check run --name suite`, then `sdlc close --issue 416 --verified '<measured evidence>'`. The binary owns the fresh-context review. Fix its blockers, publish PR, and enter `sdlc merge --yes` for authoritative integration and landing.

## Architecture checklist

- **ARCH-DRY:** One native identity reader, one recorded-child reconciliation module; runner and terminal census share it. Preserve the checkout lease as sole admission owner.
- **ARCH-PURE:** Observation→decision policy is data-only; persistence/native probes/signals are thin integration points.
- **ARCH-PURPOSE:** Independent final census catches a child after caller death; improving only stop is insufficient.
- **ARCH-MOCK:** Stateful observation sequences plus native spinner/foreign-process conformance, no call-count mocks as lifecycle proof.
- **ARCH-CONSTRAINTS:** Fixed deadlines, explicit writer caps, linear counted work, one verifier process per census phase.
- **ARCH-TEST:** Native regression proves readiness, TERM resistance, before/after liveness and safe cleanup on red; both supported runtimes.
- **ARCH-LIFETIME:** Every return reconciles owned children; cannot turn a signal or leader exit into joined child death.
- **ARCH-FUNERAL:** Records retire on proven death; drained directories collect at explicit phase/admission boundaries, unresolved residue is bounded and visible.
- **ARCH-EVOLVE:** New strict JSON schema preserves unknown members on rewrite; old job record semantics retained during transition.

## Approval

Proposed to the TL. No implementation authorized by this document alone. The retained registry is a new mechanism, so wait for the hub's design approval before `sdlc change-code`.
