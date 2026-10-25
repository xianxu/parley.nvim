# Boundary Review — parley.nvim#427 (whole-issue close)

| field | value |
|-------|-------|
| issue | 427 — Native undo/redo autosave case sees Remote view unavailable |
| repo | parley.nvim |
| issue file | workshop/issues/000427-native-undo-redo-autosave-case-sees-remote-view-unavailable.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3f473ba25d41804fc1cdcf1b7ced8d514947c092..cc2a2619f97fbf3769e1bbc0bf1e75e7aa0cca3b |
| command | sdlc close --issue 427 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-24T13:41:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

The fake's reply shape matches what the real classifier treats as absent. Next I'm running the native spec to confirm the control and the undo/redo cases.

Still working out how to run the single spec file under the test harness.

The whole session_sync group passes, including the new control and all six undo/redo cases. Next I'm reverting the fake fix to see whether any committed test goes red without it.

Without the fix, every test still passes, so nothing committed pins it. I'm checking the undo/redo case to sketch a deterministic test.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix is correct. Opening an unregistered session file triggers a `couch --session-sync lookup`. The registry-less fake Couch answered that lookup like a Couch from before pair#437, so it exited 2 and a late "Remote view unavailable" notice raced the undo/redo cases' empty-notice check. Now the fake's default lookup returns `{"Code":"ok","Error":"","Registration":null}`. `document_session.classify_reply` (`lua/parley/document_session.lua:35`) reads that as `absent`, and `remote_session.observe` (`lua/parley/remote_session.lua:375-388`) posts no notice for `absent`. So the race can no longer happen. At the pinned head, `make test-spec SPEC=modes/session_sync` passed in full: 34 files, 0 failures. The new control and all six undo/redo cases are green. What keeps this from SHIP: I put the old `tests/helpers/fake_couch.lua` back and re-ran the same group, and it **still passed in full**. No committed test fails without the fix. The red evidence in the Log (a temporary 200 ms wait) was never committed, so a later edit to the fake could bring the race back without any test noticing.

### 1. Strengths
- The root cause is traced with timestamps on both sides: about 14 ms to the assertion versus about 37 ms to the lookup callback, and the late notice was dropped by `current()` while the buffer was unloaded during teardown. That meets the first Done-when clause, which asks for evidence.
- The fake's reply shape matches the real one. It agrees with `tests/fixtures/fake_couch_registry.py:253` (`Code/Error/Registration`) and with the `Registration == vim.NIL → absent` branch in the classifier.
- The fix is in the right place. Changing the fake's default (`tests/helpers/fake_couch.lua:47-50`) is better than adding a knob to each spec. A setup that has `FAKE_COUCH_STATUS` set or uses the `legacy` opt-in keeps its old behavior.
- The control (`tests/integration/session_sync_native_spec.lua:1744-1751`) shows the capture path still sees a real lookup failure, as the second Done-when clause asks. `FAKE_COUCH_LOOKUP` cannot leak into other tests because each test gets a fresh embedded child (`before_each` at :91).
- The header comment in `fake_couch.lua` matches the new branch. The lesson in `workshop/lessons.md` is accurate and general.

### 2. Critical findings
None.

### 3. Important findings
- **No committed test fails without the fix** (`tests/integration/session_sync_native_spec.lua:1744`, `tests/helpers/fake_couch.lua:47`)
  - **Evidence:** with the base version of `fake_couch.lua` restored, `make test-spec SPEC=modes/session_sync` exited 0 with 0 failures.
  - **Why the existing tests miss it:** the control passes on either fake because it opts into `legacy`. The undo/redo cases check for notices about 14 ms after the open, well before the lookup reply arrives.
  - **Fix sketch:** add a sibling test that opens with the default fake and waits until the lookup has actually finished. Poll a condition, for example the remote-session lifetime's `request` becoming nil or a lookup marker logged by the fake, rather than sleeping. Then assert `notifications == {}`. That test fails on the old fake every time.
  - **Other instances in this window:** none. This is the only behavior change in the window.

### 4. Minor findings
- The Log says "154 pass each" for the native spec. The run at this head shows 153 successes, 0 failed, 0 errors. Correct the count or say where the 154th test comes from.
- The third plan item says "with the knob set, the lookup reports absent". The default (knob unset) is what reports absent. The second item has the same inversion: it says an unavailable lookup happens "with the knob unset", when it actually takes `FAKE_COUCH_LOOKUP=legacy`.

### 5. Test coverage notes
- Both Done-when clauses are delivered in substance. The second clause covers two states:
  - **Remote view really fails:** pinned by the control.
  - **Lookup is absent, no notice:** only exercised by timing. This is the Important finding above.
- The #432 case rename only changes a label; there is no behavior change.
- Removing the two registered flakes from `flake_tests` is a close-time step and is not part of this window.

### 6. Architectural notes
- **ARCH-DRY: pass.** The shell fake hard-codes one absent reply. It agrees with the Python registry fixture, and a single literal is not worth a shared helper.
- **ARCH-PURE: pass.** The change is test-only and lives in the fake (the IO side). No production code changed.
- **ARCH-PURPOSE: pass, with one caveat.** The default now models the current Couch for every one of the 25 consumers, not just this spec. The caveat is the missing guard against regression above.
- **ARCH-EVOLVE: pass.** No persisted format changed.

### 7. Plan revision recommendations
- Add a "## Revisions" entry that corrects the "knob set/unset" wording in plan items 2 and 3, and the 154 count in the Log.
- Once the default-path regression test is added, list it in the plan as the red/green evidence in place of the uncommitted 200 ms wait.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: fix-without-failing-regression-test
    title: |
      No committed test fails without the fake-lookup fix; only an uncommitted 200 ms wait showed red
    detail: |
      Restoring tests/helpers/fake_couch.lua from base 3f473ba2 and running make test-spec SPEC=modes/session_sync exits 0 with zero failures. The control at session_sync_native_spec.lua:1744 opts into legacy, so it passes on either fake. The undo/redo cases check for notices before the lookup reply arrives. Add a default-fake test that waits until the unregistered open's lookup has finished (poll, do not sleep) and then asserts notifications == {}. That test fails on the old fake every time. This is the only behavior change in the window, so there are no other instances.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-unverified
    title: |
      Plan and Log claims disagree with the code and the run (knob set/unset inverted, 154 vs 153 passes)
    detail: |
      Plan item 3 says that with the knob set the lookup reports absent; it is the default (unset) that does. Item 2 says the lookup is unavailable with the knob unset; it takes FAKE_COUCH_LOOKUP=legacy. The Log says 154 native passes; the run at head shows 153/0/0.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8d24ac63-3407-422e-96a8-dec990572447","repository":"github.com/xianxu/parley.nvim","issue_id":"000427","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/813109e351977a07","reviewed_head":"cc2a2619f97fbf3769e1bbc0bf1e75e7aa0cca3b","slot":"parley.nvim:1","requested_at":"2026-10-24T20:25:56.95457Z"},"phase":"finished","pid":29049,"started_at":"2026-10-24T20:25:57.105481Z","finished_at":"2026-10-24T20:41:37.312667Z","session_id":"ec676a6a-a555-4d90-8853-257e1d51d7bf","outcome":"returned"}] -->

---

## Re-review — 2026-10-24T14:06:25-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 427 — Native undo/redo autosave case sees Remote view unavailable |
| repo | parley.nvim |
| issue file | workshop/issues/000427-native-undo-redo-autosave-case-sees-remote-view-unavailable.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3f473ba25d41804fc1cdcf1b7ced8d514947c092..05be4ebadddea40cf7885e4cf4fadc780516ff0d |
| command | sdlc close --issue 427 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-24T14:06:25-07:00 |
| verdict | SHIP |

## Review

Checking the remote-view lookup path. Next I'll restore the base fake and run the spec to see whether the new regression goes red.

Run at head first.

Head is green (154/0/0). Now restoring the base fake to confirm the regression goes red.

```verdict
verdict: SHIP
confidence: high
```

Both prior findings are fixed, and I checked each one by running the tests here rather than taking the Log's word. Root cause: the registry-less fake Couch answered `--session-sync lookup` the way Couch did before pair#437, by exiting 2. That fired a late "Remote view unavailable" notice, which raced the undo/redo cases' check that no notice arrived. The fake now answers as a current Couch does, and `FAKE_COUCH_LOOKUP=legacy` brings the old behaviour back on request. At head, `make test-spec SPEC=modes/session_sync` exits 0, and the native spec runs 154 pass, 0 fail, 0 error on nvim 0.11.7. I then put the base fake (3f473ba2) back in this checkout and ran the same command. It exited 2: the new BR-1 regression test failed, and so did `undo … checktime autosave=true`, which is the flake itself showing up. I restored the fake and the checkout is clean. Both `## Done when` clauses are met: the cause is traced with timestamps, and there is a control for the case where the view really fails. The one new finding is a Minor wording issue in the Log.

**1. Strengths**
- The fix is at the root. The fake's default now matches today's Couch, and the old behaviour is an explicit opt-in (`tests/helpers/fake_couch.lua:47-50`). That beats a knob in each spec, and none of the 25 specs that use the fake needed the opt-in. I confirmed the count of 25.
- `open_after_lookup` (`tests/integration/session_sync_native_spec.lua:1746-1759`) waits for a flag set after the lookup's callback returns, instead of sleeping. So the test is deterministic, and it goes red on the base fake.
- One helper serves both the regression test and the legacy control (`:1762-1773`). That covers the empty-notice assertion in both directions: no notice on the default fake, and the notice on legacy.
- The lessons entry's figures match the trace in the Log: notice at 37 ms minus assertion at 14 ms gives the ~23 ms margin.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- The round-1 Log entry says that on the base fake "the new case fails, and only it". My base-fake run also failed `undo … checktime autosave=true`. That failure is the race the issue describes, so whether it appears depends on timing, and "only it" can't be claimed as a fixed property. This is the 2nd finding in family `doc-claim-unverified`. The rule that covers both: a Log claim about a test run must state the outcome of that run (its counts and which cases failed), not that a set of failures is exclusive. Apply the rule to the whole Log. I found no other instance in this window: the counts 25 and 154 and the 37/14/23 ms figures all check out.

**5. Test coverage notes**
- BR-1 is confirmed. With the fix reverted, the regression test is red; with the fix in place, it is green.
- The wrapper sets its flag on any `registry.request("lookup")`, so a different lookup finishing first could set it early. The base-fake run shows it doesn't do that in practice. If it ever does, narrowing the wrapper to `remote_session`'s lookup would harden it.

**6. Architectural notes**
- ARCH-DRY: **pass.** One shared helper; the fake's change sits in one branch.
- ARCH-PURE: **pass.** Only test helpers and specs changed; no runtime logic.
- ARCH-PURPOSE: **pass.** It fixes the fake every spec uses, rather than the one case that flaked. That covers both registered flakes and the checktime sibling, plus a control.
- ARCH-EVOLVE: **pass.** No persisted format changed. `FAKE_COUCH_LOOKUP` is a test-only environment variable.

**7. Plan revision recommendations:** none. Plan items 2 and 3 now say which knob state does what, and both match the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Base fake restored at head: the new case and checktime autosave=true fail (exit 2); head fake gives 154 pass, 0 fail.
  - id: BR-2
    disposition: addressed
    note: |
      Plan items 2 and 3 now match the fake's knob semantics; the Log's 154 matches the head run on nvim 0.11.7.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-unverified
    title: |
      The Log says only the new case fails on the base fake, but the base-fake run also failed checktime autosave=true
    detail: |
      This is the 2nd finding in family doc-claim-unverified. The rule: a Log claim about a test run states that run's outcome (its counts and which cases failed), not that a set of failures is exclusive. Running the base fake here also failed the racy checktime autosave=true case. No other instance in this window: the counts 25 and 154 and the 37/14/23 ms figures were checked.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"5346ba91-2bbf-4324-941a-e7e0ace61b3b","repository":"github.com/xianxu/parley.nvim","issue_id":"000427","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/fad919e42e1ef628","reviewed_head":"05be4ebadddea40cf7885e4cf4fadc780516ff0d","slot":"parley.nvim:1","requested_at":"2026-10-24T20:49:44.033252Z"},"phase":"finished","pid":36015,"started_at":"2026-10-24T20:49:44.179015Z","finished_at":"2026-10-24T21:06:23.314926Z","session_id":"8ab7b333-f214-46ff-aa41-b777c599643a","outcome":"returned"}] -->
