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

For N birth records and P process-table rows, one census round costs O(N + P): one registry traversal, one ps parse, one native observation per record, and a fixed bounded number of poll rounds. No per-child full ps/lsof or registry rescan. Native verifier startup occurs once per census phase; no new per-request subprocess. Counted N/2N tests reject quadratic scans. Use existing grace bounds (default census grace 8s; runner grace 1s), with a separate bounded post-KILL join and no sleeping after proven absence. Tests control time for policy sequences.

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

- [ ] Turn the disposable historical-argv probe into the named census regression and observe RED before changing cleanup.
- [ ] Implement `classify` and `observe` through their function-level contract above; keep the legacy command classifier narrow.
- [ ] Commit the regression and model.

### Task 2: Retain birth evidence and reconcile every exit

**Files:** new `tests/helpers/test_processes.lua`, `tests/helpers/spec_jobs.lua`, `tests/helpers/spec_runner.lua`, `tests/helpers/embedded_nvim.lua`, `scripts/test-run-lease.py`, `scripts/test-env.sh`, `Makefile.parley`, `.gitignore`, corresponding unit/native specs.

- [ ] Implement pending→born→retired registration and checked persistence through the interruption seam; no spawn precedes its durable pending ticket.
- [ ] Allocate/reuse run context under validated checkout lease; move private ledgers there and pass context through the existing environment allowlist.
- [ ] Wire registry recording to the existing jobstart wrapper, install it explicitly in clean embedded children, and reconcile every runner return. Follow the function-level test contracts and commit tested wiring.
- [ ] Preserve #405's on_exit callback exactly once and its Child-only fixture cleanup authority. The peer confirmed no intended edits to spec_jobs/spec_runner/process_identity/reaper; whichever lands second integrates main, never the other's unlanded branch.

### Task 3: Independent census and landing

**Files:** new `scripts/test-process-census.lua`, `scripts/reap-test-orphans.py`, `tests/integration/fixture_reaping_spec.lua`, Python/Lua census tests, `atlas/infra/test_harness.md`, `atlas/traceability.yaml`, `TOOLING.md`, `workshop/lessons.md`.

- [ ] Combine the legacy census and shared retained-child verifier verdicts; any leak/unknown fails and suppresses clean, including in interrupted-registration recovery.
- [ ] Finish native RED→GREEN and refusal/concurrency coverage through the function contracts; verify pruning and explicit writer bounds.
- [ ] Run `python3 tests/unit/reap_test_orphans_pure.py`, `python3 tests/unit/test_run_lease.py`, then `make test-spec SPEC=infra/test_harness`; expected all pass. Run the mapped affected regressions under each exact `PARLEY_TEST_NVIM` runtime above.
- [ ] Update atlas/traceability, tooling and lessons; log exact evidence and the #405 integration boundary.
- [ ] Push and run one recorded full suite via `sdlc local-check run --name suite`, close with measured verification, resolve the binary-owned fresh review, publish PR and enter `sdlc merge --yes` for authoritative integrated verification and landing.

## Architecture checklist

- **ARCH-DRY:** One native identity reader, one recorded-child reconciliation module; runner and terminal census share it. Preserve the checkout lease as sole admission owner.
- **ARCH-PURE:** Observation→decision policy is data-only; persistence/native probes/signals are thin integration points.
- **ARCH-PURPOSE:** Independent final census catches a child after caller death; improving only stop is insufficient.
- **ARCH-MOCK:** Stateful observation sequences plus native spinner/foreign-process conformance, no call-count mocks as lifecycle proof.
- **ARCH-CONSTRAINTS:** Fixed deadlines, explicit writer caps, linear counted work, one verifier process per census phase.
- **ARCH-SECURE:** Only lease-bound private birth records and freshly matching native identity authorize exact PID effects; command text, cwd and socket names do not. Native regression covers foreign/uncertain ownership and both runtimes.
- **ARCH-ORDER:** Birth recording precedes returning a child to its caller; every return reconciles owned children before deleting evidence. A signal or leader exit cannot imply joined child death.
- **ARCH-FUNERAL:** Records retire on proven death; drained directories collect at explicit phase/admission boundaries, unresolved residue is bounded and visible.
- **ARCH-EVOLVE:** New strict JSON schema preserves unknown members on rewrite; old job record semantics retained during transition.

## Approval

Proposed to the TL. No implementation authorized by this document alone. The retained registry is a new mechanism, so wait for the hub's design approval before `sdlc change-code`.


## Revisions

### 2026-10-22 — TL approval and plan-quality PQ-1/PQ-2

TL approved the retained registry with checkout-local placement, explicit bounds/pruning and #405 coordination. The proposed `.test-processes/` already meets placement. PQ-1 adds a **durable pending ticket before every spawn**, making death before PID publication recover as unknown, never clean. PQ-2 replaces prose case inventories with named functions and adversarial/mechanical strategies. Native spawn interruption is a controlled seam, not a sleep race. Parley.nvim:1 confirmed callback and clean-child bootstrap constraints, now included explicitly.
