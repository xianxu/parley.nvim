# Boundary Review — parley.nvim#376 (whole-issue close)

| field | value |
|-------|-------|
| issue | 376 — packaging_vm_spec reads an empty vms.json: fake_tart's state write is not atomic (flake) |
| repo | parley.nvim |
| issue file | workshop/issues/000376-packaging-vm-spec-reads-an-empty-vms-json-fake-tart-s-state-write-is-not-atomic-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7d1f54b2c00d84e3324b738e405d4959393274ea..59a4ed85ee00dd1ee9cb85aa2e02c85581a4dd52 |
| command | sdlc close --issue 376 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T07:26:51-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Diff read; now running the specs to confirm they pass at head.

Setting up the test environment to run the spec directly.

Both specs pass at head. Now reverting the `exec` check to confirm the regression goes red.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change fixes the measured cause. `tests/fixtures/fake_tart` now holds one exclusive `flock` across each read-modify-write, records its call log inside that lock, writes through a temp file followed by `os.replace`, and makes `exec` refuse a VM that is not running, so a slow detached `run` can no longer let `boot` report ready too early. I ran the specs in this checkout at the pinned head: `packaging_vm_spec` passed 18/18 and `fixture_lifecycle_spec` passed 4/4. I then deleted the two-line `exec` running check (`fake_tart:48-49`) and reran: only the new case, "boot waits for a slow detached run before it reports ready", failed (17/1). After restoring the file, the checkout was clean again. One gap remains. The second Done-when clause asks for a deterministic regression that fails without the atomic write. No such test exists. The plan instead calls the lock and the atomic replace "correct by construction". Done-when was not revised to match, and the torn read that was actually observed (the empty `vms.json`) has no test: undo the temp-file-plus-`os.replace` and every spec still passes.

1. **Strengths**
   - `fake_tart:19-23`: the `FAKE_TART_RUN_DELAY` sleep runs before the lock is taken. A slow `run` therefore does not hold up the `exec` calls polling for readiness, which is how a real loaded machine behaves.
   - `fake_tart:22-26`: the lock covers the read of `vms.json`, the `calls.jsonl` append and the replace together. That stops lost updates as well as torn reads, and it also stops two processes from interleaving lines in `calls.jsonl`.
   - `fake_tart:67-69`: the temp file sits in the same directory and is named by PID, so `os.replace` is a same-filesystem atomic rename and two writers cannot share a temp file.
   - `packaging_vm_spec.lua:136-142`: the new case drives the real orchestrator (`scripts/test-parley-vm.py:322-336`, `Popen` with `start_new_session` plus the readiness loop). It does not drive a mock, and reverting the fix turns it red.

2. **Critical findings:** none.

3. **Important findings**
   - **The second Done-when clause is not delivered, and Done-when was not revised (ARCH-PURPOSE).** `fake_tart:67-69` (atomic replace) and `fake_tart:22-23` (lock) are not covered by any test. The issue's title symptom, the empty-file read at spec line 127, can come back without any test failing.
     - Two deterministic ways to pin it:
       - Add a test-only pause hook between the staged write and `os.replace` (for example, `FAKE_TART_WRITE_PAUSE` pointing at a FIFO or sentinel file). While the writer is parked there, the spec reads `vms.json` with `state()` and asserts it still decodes to the previous state. With `write_text` this fails deterministically.
       - For the lock: have the spec take `flock` on `vms.lock` through a small `python3 -c` holder. Start a fake call, assert it has not appended to `calls.jsonl`, release the lock, and assert the call completes.
     - If neither is wanted, at minimum add a Done-when revision. The current wording, "fails before the change and passes after", is not true of the regression that shipped.
     - Members of this class in the window:
       - the atomic replace (`fake_tart:67-69`)
       - the exclusive lock (`fake_tart:22-23`)
       - the lock-protected `calls.jsonl` append (`fake_tart:25-26`)

4. **Minor findings**
   - Nothing in the window backs the claim "as real tart does" for `exec` exiting 1 on a non-running VM (`fake_tart:7`, `fake_tart:48-49`, and the Plan line). The stop/delete exit codes do have a live conformance check (`packaging_vm_spec.lua:39-52`); this one could get the same.
   - The PID-named temp file `vms.json.<pid>` is left behind if the fake crashes between write and replace. It does no harm because `after_each` deletes the root.

5. **Test coverage notes:** The `exec` running check is pinned, and I confirmed it goes red when reverted. The lock and the atomic replace are not pinned (see the Important finding). The `FAKE_TART_RUN_DELAY=1.5` case plus about 1 s of readiness polling fits well inside the 10 s `run()` wait.

6. **Architectural notes**
   - ARCH-DRY: pass. No duplicated logic. The temp-file-then-replace write is three lines in a standalone fixture script.
   - ARCH-PURE: pass. The change is confined to a test fixture whose job is IO, and the orchestrator under test is untouched.
   - ARCH-PURPOSE: flagged. The issue's stated purpose includes a deterministic regression for the torn write. The regression that shipped pins a different sub-cause (exec before run) while the observed symptom stays unpinned.
   - Docs gate: pass. `FAKE_TART_RUN_DELAY` is a test-only fixture knob with no user-facing surface, so atlas and README need no update.

7. **Plan revision recommendations:** add a `## Revisions` entry. Either:
   - say that Done-when clause 2 was met by a new pause-hook or lock test (once one is added), or
   - narrow clause 2 to the `exec`/slow-`run` regression and explain why the atomic-write and lock behaviour is left unpinned. The current text promises a test that "fails before the change" that does not exist for the write path.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: done-when-clause-unpinned
    title: |
      Done-when clause 2 (deterministic regression for the atomic vms.json write) not delivered and not revised
    detail: |
      With fake_tart:67-69 reverted to statefile.write_text, every spec still passes, so the observed empty-vms.json flake (issue 376) is unpinned. The only new test pins the exec-on-stopped-VM check (verified: removing fake_tart:48-49 fails it; 17/1). Family members in window: atomic replace (fake_tart:67-69), exclusive flock (fake_tart:22-23), lock-protected calls.jsonl append (fake_tart:25-26). Pin them deterministically (FAKE_TART_WRITE_PAUSE hook between staged write and os.replace while the spec asserts state() still decodes; spec-held flock on vms.lock blocking a fake call) or add a Revisions entry narrowing Done-when, since the current text claims a fails-before/passes-after test that does not exist (ARCH-PURPOSE).
  - id: new
    severity: Minor
    kind: defect
    family: fixture-conformance-claim-unverified
    title: |
      The claim that real tart exits 1 on exec of a non-running VM is untested against real tart
    detail: |
      fake_tart:7 docstring and fake_tart:48-49 (and the Plan line) assert parity with real tart; stop/delete have a live conformance case at packaging_vm_spec.lua:39-52, exec does not. Consider extending that conformance case.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"71da2e02-21d7-4490-a05f-4c06d27ae4de","repository":"github.com/xianxu/parley.nvim","issue_id":"000376","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/132c5289267ef4e1","reviewed_head":"59a4ed85ee00dd1ee9cb85aa2e02c85581a4dd52","slot":"parley.nvim:3","requested_at":"2026-10-17T14:21:39.201718Z"},"phase":"finished","pid":45019,"started_at":"2026-10-17T14:21:39.297486Z","finished_at":"2026-10-17T14:26:50.740983Z","session_id":"f1f03b33-2e60-40d4-818d-aaeba57a37f0","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T07:34:35-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 376 — packaging_vm_spec reads an empty vms.json: fake_tart's state write is not atomic (flake) |
| repo | parley.nvim |
| issue file | workshop/issues/000376-packaging-vm-spec-reads-an-empty-vms-json-fake-tart-s-state-write-is-not-atomic-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7d1f54b2c00d84e3324b738e405d4959393274ea..9a2a54c3aed9aee6d7142fb7a85d951bc5918516 |
| command | sdlc close --issue 376 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T07:34:35-07:00 |
| verdict | SHIP |

## Review

Running the spec at head and under mutations; the grep filter swallowed output, retrying unfiltered.

I'll add a temporary Makefile target in the disposable checkout to run one file.

```verdict
verdict: SHIP
confidence: high
```

All three behaviour changes in this window are now pinned, and I checked each one by mutating the fixture in the disposable checkout. At head, `packaging_vm_spec` passes 20/20. Each of three reverts turns exactly one spec red (19/1):
- **Old non-atomic write restored** (`statefile.write_text`, no `os.replace`): "a reader never sees a torn state file" fails.
- **`flock` removed:** "a call overlapping another loses neither update" fails.
- **`exec` running-check removed:** "boot waits for a slow detached run before it reports ready" fails.

That closes BR-1. BR-2, the claim that real tart exits 1, is still not checked against real tart. It is Minor and does not block. The only new findings are two Minor test-hygiene points. The checkout is back to clean (`git status` empty).

### 1. Strengths
- **Real cause, not the guessed one.** The plan traces the flake to the detached `tart run` overlapping `tart exec`. The fix takes one lock over the whole read-modify-write (`tests/fixtures/fake_tart:22-24`), which prevents lost updates as well as torn reads. Making the write atomic alone would not have done that.
- **Deterministic seam.** `FAKE_TART_HOLD` (`fake_tart:67-76`) pauses a call after its new state is written to a temp file but before it replaces `vms.json`, while it still holds the lock. The `.held` handshake means the spec waits on a real event (with `arrival.MS`) instead of sleeping and hoping.
- **Temp file is safe.** It is named per PID and sits in the same directory, so `os.replace` is atomic on the same filesystem.
- **The `exec` regression drives the real script.** It runs the actual boot path with `FAKE_TART_RUN_DELAY` rather than unit-testing the fixture.
- **Clean environment.** `clear_env` and a minimal env in the overlap specs keep ambient `FAKE_TART_*` variables out.

### 2. Critical findings
None.

### 3. Important findings
None.

### 4. Minor findings
- **A failing torn-read spec leaks a fake that loops forever** (`packaging_vm_spec.lua:162-166`; `fake_tart:73-75`). If an assertion fails before `writefile(hold)`, the held `fake_tart clone image a` never exits. I saw this: the next run's orphan gate reaped `pid=80416 … fake_tart clone image a`. The overlap spec has the same pattern (`:168-178`).
  - Fix: release the hold in an `after_each` (write the hold file unconditionally), or give the fixture's wait loop a deadline.
- **The `-- absence:` wait asserts nothing** (`packaging_vm_spec.lua:173`). `vim.wait(200)` is labelled as an absence check, but nothing checks that the second call is blocked.
  - Fix: after the wait, assert that `calls.jsonl` has no `b` clone yet. The log line is only written after the lock is taken.
  - Lost updates are still caught by the final state assertion, so this only weakens the "second call waits" claim.

### 5. Test coverage notes
- Both Done-when clauses are covered:
  - Atomic write: torn-read spec, red under the non-atomic mutation.
  - Deterministic regression: both seam specs, each red under its own mutation.
- The two cases the issue names are covered on both sides:
  - Reader during a write: the spec reads mid-hold and gets the old state, then gets the new state after release.
  - Concurrent writers: both clones land.
- **Not covered: `exec` on a VM that does not exist.** The fixture exits 1 because `state.get(name) != 'running'`. Real tart may exit 2 here, matching its missing-resource exits for stop and delete. No test decides it either way. This is BR-2's family; see the dispositions.

### 6. Architectural notes
- **ARCH-DRY — pass.**
  - The new `fake()` helper (`:149-154`) is close to the env-building in the conformance case (`:44-49`). The two differ in purpose (private HOME/TART_HOME vs fake-only) and size, so I'm not flagging it.
  - The held-call pattern in `agentic_document_lifetime_spec.lua` uses a different mechanism (argv predicates in Lua), so there is no shared helper to reuse.
- **ARCH-PURE — pass.** The change is a test fixture (pure IO glue) plus specs. No business logic is mixed into IO.
- **ARCH-PURPOSE — pass.**
  - The issue's purpose is "no torn read". The diff delivers that, plus the underlying overlap fix (lock and readiness).
  - Shadow-sweep: `vms.json` has one writer (fake_tart). The `calls.jsonl` append is inside the lock too. No other state file in the fixture is written non-atomically.

### 7. Plan revision recommendations
None. The Plan's BR-1 entry (`issue:50-53`) matches what I measured: 20/20, plus red under both named mutations.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified by mutation: reverting to statefile.write_text (no os.replace) fails "a reader never sees a torn state file"; removing fcntl.flock fails "a call overlapping another loses neither update"; head is 20/20.
  - id: BR-2
    disposition: not-addressed
    note: |
      Still Minor and non-blocking. fake_tart docstring and the exec check (fake_tart:7, :48-49) still claim real-tart parity; the live conformance case (packaging_vm_spec.lua:39-52) covers only stop/delete. A missing VM on exec exits 1 in the fake, and real tart may exit 2.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: held-fixture-released-on-failure
    title: |
      FAKE_TART_HOLD specs leak a forever-looping fake_tart when an assertion fails before release
    detail: |
      packaging_vm_spec.lua:162-166 and :168-178 release the hold only on the happy path; the fixture loop at fake_tart:73-75 has no deadline. Observed: the orphan gate reaped "fake_tart clone image a" after a red run. Release the hold file in after_each, or bound the fixture loop. Both instances in the window are those two specs.
  - id: new
    severity: Minor
    kind: defect
    family: done-when-clause-unpinned
    title: |
      The absence wait in the overlap spec asserts nothing
    detail: |
      This is the 2nd finding in family done-when-clause-unpinned. The rule: every labelled wait or claim in a spec should have an assertion that observes it. Here, packaging_vm_spec.lua:173 waits 200ms under an absence label but never checks that the second call is blocked; assert that calls.jsonl has no clone of b yet. This is the only such site in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"142e537d-c3dc-4246-a675-a05d58ae1f78","repository":"github.com/xianxu/parley.nvim","issue_id":"000376","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/7c23086cbbfb5dc1","reviewed_head":"9a2a54c3aed9aee6d7142fb7a85d951bc5918516","slot":"parley.nvim:3","requested_at":"2026-10-17T14:29:57.1164Z"},"phase":"finished","pid":21950,"started_at":"2026-10-17T14:29:57.395033Z","finished_at":"2026-10-17T14:34:34.793342Z","session_id":"5c144ee8-8f05-45b2-be9e-6542c8046442","outcome":"returned"}] -->
