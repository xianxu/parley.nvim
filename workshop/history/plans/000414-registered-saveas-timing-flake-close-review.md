# Boundary Review — parley.nvim#414 (whole-issue close)

| field | value |
|-------|-------|
| issue | 414 — Investigate registered-saveas timing flake under load |
| repo | parley.nvim |
| issue file | workshop/issues/000414-registered-saveas-timing-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 20f3513ba4febf46479a9081fa5e00761531aeea..1fe9891317280631e212d378ebc0ac1b9a6c9bc4 |
| command | sdlc close --issue 414 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-23T11:43:53-07:00 |
| verdict | REWORK |

## Review

I've finished reading the diff and the changed tests; now running the affected spec to confirm it passes at the pinned head.

Still working: getting the spec to run through the repo's isolated test harness so I can check the pinned head.

Running a negative control: a synchronous Couch wait cut off by the timeout, after which the move continues normally. This checks whether row 1's new causal assertions catch it.

Every test still passes with the regression injected. Next I'm confirming the injected wait really runs and blocks during row 1.

Confirmed: with the injected wait, row 1's `:saveas` blocked 5169 ms on Couch and the test still passed. Restoring the checkout now.

```verdict
verdict: REWORK
confidence: high
```

The gate idea is sound, but the main row no longer catches the regression this issue is about. I added a Couch wait to the registered `:saveas` path. The wait blocks until the move timeout cuts it off, then lets the move go on as usual. Row 1 passed with it in place: in the harness, `:saveas` blocked for 5169 ms and the spec finished 48/0/0. Row 1 used to catch that, because its timeout equalled its time bound. This change raised the timeout to 5000 and dropped the time bound. The two new assertions (the operation is still pending, the identity has not moved) still hold after a wait the timeout cuts off. The plan's negative controls only made the move fail outright, so they never tried this case. That leaves the second "Done when" clause unmet ("reject the intended regression"). The fix is cheap. At the pinned head the spec passes 48/0/0 on nvim 0.11.7, and I restored the checkout afterwards.

1. **Strengths**
   - `tests/fixtures/fake_couch_registry.py:150-164`: the gate has a fallback time limit and also opens when the spec's temp directory is deleted. The per-test `root` is removed in `after_each`, so a spec that fails before opening the gate leaves no fake process running. The harness reported "no surviving test processes".
   - The trace records the full argv. That is how the row 2 flake (the renamed buffer's own background lookup) was found and correctly classified.
   - The root-cause measurements in the Plan clearly separate a whole-process stall from a wait in the code. The #410 Alt+Return bound (line 123) is left alone, as the Spec requires.
   - The `gate_couch` helper is shared by all four rows instead of being copied into each one (ARCH-DRY pass).

2. **Critical**
   - `tests/integration/agentic_document_spec.lua:263-269`: row 1 accepts a synchronous Couch wait that the timeout cuts off. A Couch wait cut off by `agentic_move_timeout_ms`, after which the move continues as usual, keeps the operation pending and the identity unmoved, so lines 268-269 pass.
     - **Fix sketch:** make the fake's own fallback answer arrive *before* the move timeout. For example, `FAKE_COUCH_REGISTRY_DELAY=2` with a 5000 ms move timeout. Any synchronous wait then receives the answer, so the operation completes or the identity moves inside the call, and lines 268-269 fail. The non-blocking path is unaffected: line 268 runs right after `:saveas` returns, before the event loop gets a chance to deliver a background reply.
     - **Same family, same window:**
       - Rows 1 and 5 (`move_path`, timeout 500 against a 60 s gate, lines 195-199).
       - Row 3 (line 217+).
       - Row 4 (line 302+). For rows 3 and 4, a wait that is cut off and then returns the same background refusal passes `assert.equals(err, why)`. In the implementer's own control, row 3 was caught only by the older message assertion at :230.
     - Each row needs the "fallback answer before the timeout" setup, plus a negative control of the "wait, get cut off, carry on" kind.

3. **Important**
   - Row 2 (lines 277-291) has no negative control, although "Done when" asks for one for each changed assertion. The check also passes when no request was traced at all: an asynchronous non-lookup request that hasn't written its trace line yet passes the loop. Recommend running a control that adds a background `rename` on the plain path, and noting the race in the comment.

4. **Minor**
   - `fake_couch_registry.py:161`: a gate path with no directory part makes `isdir("")` false, so the gate opens at once. It is harmless with the current callers, but the behaviour is silent.
   - `workshop/lessons.md`: the first lesson says the causal assertion alone is enough. That only holds when the fallback answer arrives before the timeout. Revise it alongside the fix.

5. **Test coverage notes**
   - The plan's controls (`wait_destination` forced, `move_membership` waiting on Couch) only cover a "wait, then fail" regression. The "wait, get cut off, carry on" regression is untested, and I confirmed it passes. Verification on nvim 0.12.5 is borrowed from a suite run at 88fedfd8 that had two unrelated flakes; I did not run it again.

6. **Architectural notes**
   - ARCH-DRY: pass.
   - ARCH-PURE: pass. The change is test-only and the fake stays a thin IO stand-in.
   - ARCH-PURPOSE: flag. This is the finding above. The purpose was an assertion that *rejects* the regression, and the swept rows got the weaker form.
   - ARCH-EVOLVE: pass. No persisted format changes; the trace file is a scratch file that lives only for one test.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry: "The causal gate only rejects a synchronous wait when the fake's fallback answer arrives before the move timeout. Set the gate delay below `agentic_move_timeout_ms` in rows 1, 1/5, 3 and 4, and add a 'wait, get cut off, carry on' negative control." Correct the Plan's claim that "the pending-operation assertion fails on any load".

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: causal-gate-outlasts-timeout
    title: |
      Row 1 passes with a synchronous Couch wait that the move timeout cuts off; the wall-clock bound was dropped
    detail: |
      I injected a bounded_request("lookup") whose result is ignored before the move begins in lua/parley/agentic_document.lua (~line 1030). Registered :saveas blocked for 5169 ms and agentic_document_spec still passed 48/0/0. With a 60 s gate and a 5000 ms move timeout, the cut-off wait leaves the operation pending and the identity unmoved, so lines 268-269 pass. Fix: set FAKE_COUCH_REGISTRY_DELAY below agentic_move_timeout_ms (for example 2 s against 5000 ms) so any synchronous wait receives the answer and the causal asserts fail. Same family in this window: rows 1/5 move_path (timeout 500, 60 s gate), row 3 and row 4 (err == why also holds after a cut-off wait). Add this regression as a negative control for each row.
  - id: new
    severity: Important
    kind: defect
    family: negative-control-per-changed-assertion
    title: |
      Row 2's new trace assertion has no negative control and passes when the trace is empty
    detail: |
      Done-when asks for a negative control, but the plan ran controls only for rows 1, 3 and 4. The loop at agentic_document_spec.lua:286-290 passes on an empty trace, so an asynchronous non-lookup request whose fake process has not yet written its trace line is not caught. Run a control (for example a background rename on the plain path) and record it, or document the race in the comment.
  - id: new
    severity: Minor
    kind: defect
    family: gate-path-edge
    title: |
      A gate path with no directory part opens at once (isdir("") is false)
    detail: |
      tests/fixtures/fake_couch_registry.py:161. Harmless with the current callers, but the behaviour is silent; treat an empty dirname as "."
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d4d1468b-5b29-4d70-aabb-0f3543125669","repository":"github.com/xianxu/parley.nvim","issue_id":"000414","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/048660e0440cc80f","reviewed_head":"1fe9891317280631e212d378ebc0ac1b9a6c9bc4","slot":"parley.nvim:1","requested_at":"2026-10-23T18:39:08.740518Z"},"phase":"finished","pid":60523,"started_at":"2026-10-23T18:39:08.875981Z","finished_at":"2026-10-23T18:43:51.818694Z","session_id":"f2c13075-678d-44ba-a84e-734dd3a900c9","outcome":"returned"}] -->

---

## Re-review — 2026-10-23T12:23:26-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 414 — Investigate registered-saveas timing flake under load |
| repo | parley.nvim |
| issue file | workshop/issues/000414-registered-saveas-timing-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 28526aa8eefe4da49b28bac04456f56e564ecaf2..b11e2e9ce3838fdba088932557e6425ad68b930c |
| command | sdlc close --issue 414 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-23T12:23:26-07:00 |
| verdict | SHIP |

## Review

Checking BR-1's fix now: I'll inject the reviewer's ignored synchronous lookup and run the spec.

Running the spec at head (no `timeout` binary on this host; retrying without it).

Head passes 48/0/0. Now injecting BR-1's exact regression (ignored synchronous lookup before the move begins).

BR-1 regression now goes red at row 1. Next, probing rows 1/5 (`move_path`, submit timeout 1000) with a synchronous wait on a default-deadline request.

Running BR-2's control: a plain :saveas that synchronously waits on (and ignores) a lookup of the target.

Row 2 control goes red too. One more check, on rows 3/4: an ignored synchronous wait in `move_membership`.

Row 3 goes red but row 4 does not. Checking why.

My register call lacked the owner argument; retrying with the real argument shape.

```verdict
verdict: SHIP
confidence: high
```

All three earlier findings are fixed, and I checked each by breaking the code on purpose and watching the right test fail. The spec passes 48/0/0 at head on nvim 0.11.7 using the isolated test environment. The fake registry now holds its answer for at most GATE_MS (3 s), which is below the move timeout (2 × GATE_MS). It also writes a line to `gate.answered` for every answer it gives. So "did not wait on Couch" becomes a recorded fact rather than a time measurement. That catches waits that use the answer, waits that ignore it, and waits that the timeout would otherwise cut off.

I re-ran four broken versions of the code, one at a time, reverting after each:
- **BR-1's own regression** (an ignored `bounded_request("lookup")` before the move begins): row 1 fails at `unanswered`.
- **A plain `:saveas` that waits on its own lookup of the target:** row 2 fails at `unanswered`.
- **An ignored synchronous lookup or register in `move_membership` before `ask_in_background`:** rows 3 and 4 both fail.

The one remaining gap is a single comment that claims more than the code guarantees (Minor), plus a small cleanup issue.

1. **Strengths**
   - `tests/fixtures/fake_couch_registry.py:150-168`: the gate has an upper bound and also opens when the spec's directory is deleted. So a spec that never opens it cannot leave a registry process running. The answer record is written before the reply, so any wait that got an answer always leaves a record.
   - `agentic_document_spec.lua:109-119`: `gate_couch` and `unanswered` are one shared helper for all the gated rows. Each row is not copy-pasted (ARCH-DRY pass).
   - Rows 3 and 4 add a second check: calling `move_membership` again while the gate is held must return the same refusal. That catches waits the answer record alone would miss.
   - Row 2's argv trace now accepts the renamed buffer's own background lookup, and the comment says what the trace cannot see.
   - The new lessons in `workshop/lessons.md` give a general rule ("every shape of the regression must change what the check sees"), not a description of this one bug.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **The spec comment's "any synchronous wait" is not true for rows 1/5** (`agentic_document_spec.lua:103-104`). This is the 2nd finding in family `causal-gate-outlasts-timeout`.
     - Rows 1/5 run with a 1000 ms submit timeout. That gives the rename request a deadline of 3 × 1000 = 3000 ms, exactly equal to GATE_MS, and every other request a 1000 ms deadline (`document_registry.lua:26,34`).
     - So in rows 1/5 a wait that one of those deadlines cuts off gets no answer from the gate. Those rows are guarded by the operation-pending check instead, as the implementer's control E notes.
     - Every instance in the window: rows 1/5 (both deadlines). Row 1, row 2, row 3 and row 4 use a 15000 ms submit timeout, so they meet the rule.
     - The rule to apply: GATE_MS must be below every deadline in force in a gated row, meaning the move timeout, the submit timeout and three times the submit timeout. Either `gate_couch` asserts that, or a row that breaks it says in a comment which check guards it instead.
   - **`gate_couch` changes `config.agentic_move_timeout_ms` without saving the old value** (`:111`). Today the old value is only restored because every caller runs `with_timeouts` first. A future row that skips `with_timeouts` would leak the 6 s timeout into later tests.

5. **Test coverage notes**
   - Row 2's trace loop still passes when the trace is empty, so a background request whose trace line hasn't been written yet goes unseen. The comment at `:298-302` documents this race, and the answer record now catches the synchronous case that matters.
   - I did not re-run the load reps or nvim 0.12.5. The issue log records 20/20 reps under load and the 0.12.5 suite run.

6. **Architectural notes**
   - ARCH-DRY: pass. The gating is one helper and the fixture logic is not repeated.
   - ARCH-PURE: pass. The change is test-only and the fake is the IO boundary.
   - ARCH-PURPOSE: pass. The same zero-margin pattern was fixed in every affected row (1, 1/5, 2, 3, 4), not just the row the issue named. The #410 500 ms press bound was deliberately kept.
   - ARCH-EVOLVE: pass. No stored format changes; `gate.answered` and the trace are temporary files that only exist during a test.
   - Docs: the new environment variables are internal to the test fixture, and atlas/README do not document any of the existing `FAKE_COUCH_REGISTRY_*` variables, so no doc update is needed.

7. **Plan revision recommendations:** none. The Log already records how the plan changed (the answer record, rows 3 and 5, and the controls table).

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Re-injected the ignored bounded_request("lookup") before begin; row 1 now fails at unanswered (47/1/0); reverted 48/0/0. Rows 3/4 fail under an ignored sync wait in move_membership.
  - id: BR-2
    disposition: addressed
    note: |
      Negative control run: plain BufFilePost waiting on bounded_request lookup of the target fails row 2 at unanswered (47/1/0); empty-trace race documented at spec:298-302.
  - id: BR-3
    disposition: addressed
    note: |
      fake_couch_registry.py:161,164 now use os.path.dirname(gate) or ".".
findings:
  - id: new
    severity: Minor
    kind: defect
    family: causal-gate-outlasts-timeout
    title: |
      Spec comment says any sync wait outlasts GATE_MS, but row 1/5 deadlines are at or below it
    detail: |
      2nd in family. agentic_document_spec.lua:103-104 claims every synchronous wait gets an answer before giving up. In rows 1/5 (submit timeout 1000) the rename deadline is 3x1000 = 3000 ms = GATE_MS and other requests get 1000 ms (document_registry.lua:26,34), so a wait cut off there leaves no answer record; those rows rely on the operation-pending check (control E). Every instance in the window: rows 1/5 only; rows 1, 2, 3 and 4 use 15000 ms. Rule: GATE_MS must be below every deadline in force in a gated row (move timeout, submit timeout, 3x submit). Either gate_couch asserts it, or the comment names the rows that are guarded by the pending check instead.
  - id: new
    severity: Minor
    kind: defect
    family: fixture-config-restore
    title: |
      gate_couch changes agentic_move_timeout_ms without saving the old value
    detail: |
      agentic_document_spec.lua:111. The value is restored only because every caller runs with_timeouts first, which saves the old value. A gated row without with_timeouts would leak the 6 s move timeout into later cases. Fix: call with_timeouts inside gate_couch, or save the old value there.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f53b5f40-4265-4ba6-ab43-5055a0f6ad5b","repository":"github.com/xianxu/parley.nvim","issue_id":"000414","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/1ee0f0c771f24c0e","reviewed_head":"b11e2e9ce3838fdba088932557e6425ad68b930c","slot":"parley.nvim:1","requested_at":"2026-10-23T19:13:06.257819Z"},"phase":"finished","pid":69284,"started_at":"2026-10-23T19:13:06.449147Z","finished_at":"2026-10-23T19:23:25.120319Z","session_id":"41235509-8a97-44f6-9ebc-c4f21e6186e3","outcome":"returned"}] -->
