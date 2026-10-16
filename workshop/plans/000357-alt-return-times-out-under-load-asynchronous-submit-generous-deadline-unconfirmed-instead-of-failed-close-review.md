# Boundary Review — parley.nvim#357 (whole-issue close)

| field | value |
|-------|-------|
| issue | 357 — Alt+Return times out under load: asynchronous submit, generous deadline, unconfirmed instead of failed |
| repo | parley.nvim |
| issue file | workshop/issues/000357-alt-return-times-out-under-load-asynchronous-submit-generous-deadline-unconfirmed-instead-of-failed.md |
| boundary | whole-issue close |
| milestone | — |
| window | a936c96ce50bc9034e175915f691b0eebc690b33..0654d0bf54f697534fb29782b55f47117ef708d0 |
| command | sdlc close --issue 357 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T12:24:56-07:00 |
| verdict | REWORK |

## Review

Still reviewing: I'm checking how the send stage and the lock interact. Next I'll look at session_sync's send path and the model's retry branch.

Next I'm running the changed integration spec to confirm the new tests pass at head.

The plain runner refuses to run outside the test harness, so I'm running the session_sync spec through `make test-spec`.

```verdict
verdict: REWORK
confidence: medium
```

The main submit path works. Alt+Return no longer blocks the editor, a single deadline covers the registry stage and the send, and a send is never killed. A press while a send is out joins it rather than sending again, and a late success records #332's receipt, so an identical resubmit sends nothing. The four new slow-Couch integration cases cover this. I ran every spec mapped to `modes/session_sync` with `make test-spec`, and all of them pass (14 files, 0 failures).

One thing blocks SHIP: the new `queued_submit` flag set by a pending-phase press is only cleared in the lookup/register callback. When the pending operation is a rename or move, or when the retry returns a context-mismatch reconcile, the flag stays set. A later unrelated lookup can then send a submit nobody pressed for, and moves stay refused until it does. I found this by reading the code; I did not reproduce it at runtime. Beyond that, several Important gaps remain:
- the rename stage of a move still has the old 2.5 s deadline;
- the BufFilePost preflight drops the new "run the move again" message, which makes the atlas claim false there;
- the operator's lock is not returned at the send deadline, although the Revisions require it;
- the Done-when's "move wait" is not tested;
- the README is not updated.

Done-when: current — the Revisions replaced the ledger check with receipt-based idempotency ("resolves from the receipt, no double submit") and cut Spec point 4 down to option (a), the configurable waits. The three Done-when clauses (slow submit with the editor not blocked, unconfirmed then receipt with no double submit, move wait under the slow fake) still describe what this diff is meant to build.

**1. Strengths**
- `lua/parley/agentic_document.lua:280-289`: a send is never killed. The send callback ends the submit only if it is still the same submit (`s.submitting == submitting`), so a late completion cannot clear a newer submit.
- `agentic_document.lua:446-449`: the join rule ("still waiting for Couch") is a small, clear guard that prevents a second `couch --send-to`.
- `agentic_document.lua:241-245`: the replay is skipped while the phase is still `pending`, so a registry that keeps timing out cannot loop.
- The existing "edited in-flight registration" test was deliberately rewritten (`tests/integration/agentic_document_spec.lua:343-366`), with a mutation check recorded in the Log. The test now pins the operator-visible bug.
- `bounded_request` sets the registry child's own timer past its wait (`ms + 1000`), so exactly one deadline decides.

**2. Critical**
- `agentic_document.lua:440` sets `s.queued_submit = true` (and calls `begin_submit`) for any `pending` phase. The flag is only cleared in the lookup/register callback (`:241`).
  - **Instances in this window:**
    - (a) The pending operation is `rename` (a rename reply timing out goes `pending`, `document_session.lua:300`). The retry issues `rename`, whose callback (`:264`) never checks `queued_submit`, and `finish_move` never calls `end_submit`.
    - (b) The pending operation is `move`. The retry issues `move`, which only stores a witness.
    - (c) `retry` returns `pending(...)` on a context mismatch (`document_session.lua:189`). That returns `reconcile` with no registry request.
  - **Effects:**
    - 15 s after a rename actually succeeds, the band reads "not confirmed: submit again · Couch did not answer within 15 s".
    - `migration_busy` (`:498`) stays true, so moves are refused.
    - The stale flag fires `M.submit` on the next lookup completion where no operation is in flight (e.g. `M.recheck`, the 5-second retry of an unknown document). If the operator has edited, that sends to the agent without a press.
  - **Fix sketch:** queue the replay only when the pending operation is lookup/register. Clear `queued_submit` together with `end_submit` on every outcome (finish_move, reconcile, notify, feedback). It would be better to move the "confirm then submit" intent into the pure model as a `retry { submit = true }` event (see ARCH-PURE) and test it in `document_session_spec`.

**3. Important**
- The rename registry request (`agentic_document.lua:263`) still uses the default 2500 ms. Only lookup/register got the new deadline. Under load the move's rename stage still times out at 2.5 s and goes `pending` ("document move pending; preserve its journal"), even inside the now-5 s move wait. **Family:** registry calls left at the old default: just this rename site.
- The BufFilePost destination lookup (`:753-754`) discards `bounded_request`'s "move not confirmed … Run the move again" error. It reports "destination membership is occupied or unknown" instead, and its real recovery is "return to OLD before retrying". The atlas line "Every one runs before anything moved, so their recovery is … Run the move again" is false here, because Neovim has already renamed the buffer at BufFilePost.
  - **Family members:** move_path `:562` handles the new error correctly. BufFilePost `:753` does not. The atlas claim needs a carve-out for BufFilePost.
- Losing the lock at the send deadline contradicts the Revisions.
  - Revisions and Plan item 2 say that on the deadline Parley returns the lock to the operator, re-acquiring the session-sync turn if the send had released it. `release_and_send` releases the lock before sending, and the overdue timer (`:213-216`) never re-acquires it.
  - Nothing tests it, and the atlas says nothing about the lock at the send stage.
  - Either implement and test the re-acquire, or add a Revision that drops it (re-acquiring while a send may still land arguably races the agent).
- The Done-when clause "the move wait under the same slow fake" is only covered for the `move_path` preflight lookup (`bounded_request`). The former 3000 ms post-rename wait (`:597`, now `agentic_move_timeout_ms`) and the BufFilePre/BufFilePost preflights are not exercised under a slow registry.
- The README is not updated (`README.md:50-63`). It documents the neighbouring `session_sync_*` config keys and the Alt+Return winbar states. The new user-facing surface is missing:
  - the `agentic_submit_timeout_ms` and `agentic_move_timeout_ms` keys;
  - the `submitting…` and `not confirmed: submit again` states;
  - the fact that a pending-phase press now submits.

**4. Minor**
- ARCH-DRY: the default values 15000 and 5000 are restated in `config.lua`, at both `config_ms("agentic_submit_timeout_ms", 15000)` call sites (`:82` and `:212`), and at both `agentic_move_timeout_ms` sites (`:484` and `:596`). Use named constants or read the config defaults.
- `begin_submit` formats seconds with `math.floor(ms/1000)` (a sub-second setting shows "0 s"), while `bounded_request` uses `math.ceil`.
- Lookup/register now use a 15 s timeout for all of them, including the background open/recheck probes, not only submits. The "Couch unavailable" band now takes up to 15 s to appear, and this is undocumented.
- The Plan's pure `document_session_spec` tests were not delivered (see Revisions below).

**5. Test coverage notes**
- Covered and passing:
  - a slow registry, with the press returning in under 500 ms;
  - an overdue send, followed by a joined press and a receipt-deduped resubmit;
  - a registry timeout that keeps the lock and then submits once on the next press;
  - a timed-out move preflight.
- Missing:
  - Alt+Return on a pending rename or move (it would catch the Critical finding);
  - lock state after an overdue send;
  - rename-stage and BufFilePost behaviour under a slow registry;
  - a send that fails after the deadline. The plan says it records no receipt so a resubmit really sends, but no test checks this.

**6. Architecture**
- **ARCH-DRY: flag (Minor).** The timeout defaults are duplicated, as listed above. No duplicated logic blocks beyond that.
- **ARCH-PURE: flag.** The rule "a press confirms a pending registration, then submits" lives in shell flags (`queued_submit`, plus the phase check in the callback). It is not a pure model transition, and that is exactly where the Critical bug sits. Move it into `document_session` and test it there without IO, as the Plan's Tests section intended.
- **ARCH-PURPOSE: flag.** "The other blocking waits get the same treatment" (Spec point 4a) is only partly delivered: the rename stage keeps 2.5 s, and the BufFilePost message is not the unconfirmed one. The lock return from the Revisions is also undelivered.

**7. Plan revision recommendations**
- "## Revisions: the pure `document_session_spec` cases listed under Tests were not written. The behaviour lives in the shell and is covered by integration tests in `agentic_document_spec` 'under a slow Couch (#357)'." Alternatively, move the logic into the model and write those cases.
- "## Revisions: lock at the send-stage deadline". Either it is re-acquired (and tested), or it is deliberately left released because the send may still land.
- "## Revisions: BufFilePost runs after Neovim renamed the buffer. Its timed-out lookup recovers through 'return to OLD', not 'run the move again'." Correct the atlas paragraph to match.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: submit-intent-cleared-on-every-outcome
    title: |
      queued_submit set on any pending-phase press is never cleared when the pending op is rename/move or retry reconciles
    detail: |
      agentic_document.lua:440 sets queued_submit and begin_submit for every pending phase, but only the lookup/register callback (:241) clears it. A pending rename (rename reply timeout -> pending), a pending move, or retry returning pending() on a context mismatch (document_session.lua:189) leave it set. The effects are a false "not confirmed ... did not answer within 15 s" after a successful rename, migration_busy (:498) refusing moves, and a later unrelated lookup completion (recheck/retry_loaded) firing M.submit with no press, which can send edited content to the agent. Fix: queue the replay only for lookup/register pending ops, and clear queued_submit on every outcome. Better, move the "confirm then submit" intent into document_session as a pure retry{submit=true} transition with unit tests (ARCH-PURE).
  - id: new
    severity: Important
    kind: defect
    family: generous-deadline-every-couch-wait
    title: |
      Move rename registry request still uses the old 2500 ms default deadline
    detail: |
      agentic_document.lua:263 calls registry.request("rename", ...) without timeout_ms, so under load the rename stage still times out at 2.5 s and goes pending, even though Spec point 4 asks for the same generous treatment and the surrounding move wait is now 5 s. This is the only registry call site in the window left at the default (lookup/register :248 and bounded_request :486 were updated).
  - id: new
    severity: Important
    kind: defect
    family: move-unconfirmed-recovery-message
    title: |
      BufFilePost lookup discards the "move not confirmed ... Run the move again" error; the atlas claim is false there
    detail: |
      At :753-754 a timed-out destination lookup reports "destination membership is occupied or unknown", and recovery requires returning to OLD, because Neovim already renamed the buffer at BufFilePost. move_path (:562) propagates target.unconfirmed correctly; BufFilePost does not. atlas/modes/session_sync.md says "Every one runs before anything moved, so their recovery is ... Run the move again", which is untrue for BufFilePost. Fix the site, the atlas sentence, or both.
  - id: new
    severity: Important
    kind: defect
    family: revision-contract-delivered
    title: |
      Send-stage deadline does not return the lock to the operator as the Revisions require
    detail: |
      Revisions (operator amendment) and Plan item 2 say that on the deadline parley returns the lock to the operator, re-acquiring the session-sync turn if the send had released it. release_and_send releases the lock before sending, and the overdue timer (agentic_document.lua:213-216) only changes the band. No test asserts the lock after an overdue send. Implement and test the re-acquire, or record a Revision that deliberately drops it.
  - id: new
    severity: Important
    kind: defect
    family: done-when-clause-tested
    title: |
      Done-when "move wait under the same slow fake" is only tested for move_path's preflight lookup
    detail: |
      The new move test exercises bounded_request's timeout in move_path. The former 3000 ms post-rename wait (agentic_document.lua:597, now agentic_move_timeout_ms) and the BufFilePre/BufFilePost preflights are never run under FAKE_COUCH_REGISTRY_DELAY, so the rename-stage and BufFilePost defects above go uncaught.
  - id: new
    severity: Important
    kind: defect
    family: readme-user-surface
    title: |
      README not updated for the new config keys and Alt+Return states
    detail: |
      README.md:50-63 documents the neighbouring session_sync_* keys and Alt+Return winbar feedback. It lacks agentic_submit_timeout_ms, agentic_move_timeout_ms, the "submitting…" and "not confirmed: submit again" states, and the fact that a press on a pending registration now submits.
  - id: new
    severity: Minor
    kind: defect
    family: single-source-defaults
    title: |
      Timeout defaults 15000/5000 restated in config.lua and at four config_ms call sites (ARCH-DRY)
    detail: |
      agentic_document.lua:82 and :212 repeat 15000; :484 and :596 repeat 5000, alongside config.lua. Use one named constant or read the config default.
  - id: new
    severity: Minor
    kind: defect
    family: plan-tests-delivered
    title: |
      Plan's pure document_session_spec tests were not written; the behaviour lives in the shell
    detail: |
      The Plan's Tests section lists pure document_session_spec cases (deadline, join, late receipt, registry timeout then a single send). None were added. Either add a Revision or move the logic into the model and test it there. Also: begin_submit uses math.floor seconds (shows "0 s" for sub-second settings) while bounded_request uses math.ceil, and lookup/register now take 15 s for background probes too, which is undocumented.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e246a391-1e00-4f78-b99d-45a0198180c0","repository":"github.com/xianxu/parley.nvim","issue_id":"000357","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/27c54d2b2c0b7e6c","reviewed_head":"0654d0bf54f697534fb29782b55f47117ef708d0","slot":"parley.nvim:4","requested_at":"2026-10-16T19:18:03.140912Z"},"phase":"finished","pid":26671,"started_at":"2026-10-16T19:18:03.375885Z","finished_at":"2026-10-16T19:24:52.984734Z","session_id":"1b603c97-e2b9-44cd-8a73-76054c77f4ce","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T12:36:30-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 357 — Alt+Return times out under load: asynchronous submit, generous deadline, unconfirmed instead of failed |
| repo | parley.nvim |
| issue file | workshop/issues/000357-alt-return-times-out-under-load-asynchronous-submit-generous-deadline-unconfirmed-instead-of-failed.md |
| boundary | whole-issue close |
| milestone | — |
| window | a936c96ce50bc9034e175915f691b0eebc690b33..a49f6b55d28f81945ba9d9200f2b1b2a49a40ccd |
| command | sdlc close --issue 357 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T12:36:30-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Disposing round-1 findings: verifying the pure `resubmit` transition and its re-entrancy in the shell, then running the tests.

I'll run the three touched spec files directly with the project's runner environment.

Tests pass. Now reverting individual fixes to check the regression tests actually catch them.

Rename-deadline revert stays green (the test's 2 s delay is below the old 2.5 s default). Next: revert the BufFilePost fix.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 1 fixed seven of its eight findings, and a revert-and-rerun proves it for the ones that change behaviour. The press on a pending registration now goes through the pure model, and BufFilePost gives the right recovery. With either fix reverted, its test fails. The one finding still open is BR-2. The rename stage's `timeout_ms` fix is in the code, but no test catches its removal. I reverted it and `agentic_document_spec` still passed. The cause is that the new rename-delay test sleeps 2 s, which is below the old 2500 ms default. Changing that delay to about 3 s closes the gap, so the code itself is right and the remaining work is one test change. The three touched spec files (`document_session_spec`, `agentic_document_spec`, `document_band_spec`) all pass at head.

Done-when: current. The Revisions changed only who holds the lock at a send-stage deadline (TL option A). Every Done-when clause still matches what was built and is tested: a submit slower than 2.6 s that still succeeds without blocking, an unconfirmed result that then resolves from the receipt with exactly one delivery, and the move waits under the slow fake.

**1. Strengths**
- **Press on a pending registration (fixes BR-1):** "Confirm then submit" is now a pure transition. `retry{submit}` sets `args.resubmit` only for `register` (`lua/parley/document_session.lua:200`), and the `resubmit` effect is emitted only on a valid confirmation (`:341-343`). Three unit cases pin it, including a pending rename that must not resubmit. Reverting the effect fails both the unit spec and the integration spec.
- **Submit timer always cleaned up:** the shell ends the submit and its timer on every outcome. A `reconcile` or `notify` calls `end_submit` (`lua/parley/agentic_document.lua:301-305`), and so does `detach` (`:~808`). The context-mismatch path in `pending()` emits `reconcile`, so it is covered too.
- **BufFilePost recovery (fixes BR-3):** `agentic_document.lua:759-765` handles a timed-out destination lookup. The `:saveas` test checks the exact "rename back to OLD" message, then the `:file OLD` cancel path, then a successful rerun. Reverting the block fails that test.
- **Defaults in one place (fixes BR-7):** `config_ms` (`:192-196`) falls back to the defaults in `config.lua`, and no 15000/5000 literals are left at call sites.

**2. Critical findings**
None.

**3. Important findings**
- **BR-2, still open (rename deadline has no regression test):** the fix is at `agentic_document.lua:272`. The test "a move whose rename stage outlasts the wait…" (`tests/integration/agentic_document_spec.lua:~393`) uses `FAKE_COUCH_REGISTRY_DELAY="2"`, which finishes inside the old 2500 ms default. Fix: raise the delay to "3" so that reverting the `timeout_ms` makes the rename go pending and the test fail.

**4. Minor findings**
- **BufFilePre preflight never runs under the slow fake:** this is the `bounded_request` call at `agentic_document.lua:705-708`, which only runs when the buffer has no cached identity. Every slow-fake test calls `registered()` first, so this branch is never reached. Its message ("move not confirmed … Run the move again") is correct, because nothing has been renamed yet; only the test is missing.

**5. Test coverage notes**
I reverted each fix in the disposable checkout and re-ran the specs:

| Reverted fix | Result |
|---|---|
| `resubmit` effect | unit and integration specs fail |
| BufFilePost `unconfirmed` block | integration spec fails (the `:saveas` case) |
| rename `timeout_ms` | integration spec still passes (BR-2) |

The integration specs run the real `vim.system` path against the stateful fake Couch registry.

**6. Architectural notes**
- **ARCH-DRY: pass.** Defaults come from one source.
- **ARCH-PURE: pass.** The resubmit decision moved into the model. The deadline timer and the band stay shell state, as the Revision explains.
- **ARCH-PURPOSE: pass**, apart from BR-2's missing test.
- **ARCH-MOCK: pass.** The fake registry gains `FAKE_COUCH_REGISTRY_DELAY_OPS`, behind the same seam production uses.
- **ARCH-CONSTRAINTS: pass.** Blocking waits are limited to the BufFilePre/BufFilePost preflights, and making those asynchronous is filed as #359.
- **ARCH-SECURE: N/A.** No new untrusted input and no credentials.
- **ARCH-ORDER: pass, with a note for #359.** The submit lifecycle is still several shell flags (`submitting`, `overdue`, `queued_submit`, `resolving`). An enum such as `idle|resolving|submitting|overdue` would make the legal combinations readable when #359 reworks this code.
- **ARCH-FUNERAL: pass.** The submit timer is closed by `end_submit` and by `detach`, and nothing durable is created.

**7. Plan revision recommendations**
None. The Revisions already record the send-stage lock decision and the choice to test the deadline, join and late receipt in integration rather than in the model.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Pure retry{submit} to resubmit only for register (document_session.lua:200,343); reconcile and notify end_submit; reverting the effect fails the unit and integration specs.
  - id: BR-2
    disposition: not-addressed
    note: |
      The timeout_ms fix is at agentic_document.lua:272, but reverting it keeps agentic_document_spec green. The rename-delay test sleeps 2 s, under the old 2.5 s default. Raise FAKE_COUCH_REGISTRY_DELAY to 3 so the revert fails.
  - id: BR-3
    disposition: addressed
    note: |
      BufFilePost unconfirmed branch (agentic_document.lua:759-765), atlas sentence corrected, and the saveas test fails when the branch is reverted.
  - id: BR-4
    disposition: addressed
    note: |
      The Revision (TL option A) deliberately keeps the send-stage lock released, giving the stuck-answer rationale; the registry stage keeps the operator lock.
  - id: BR-5
    disposition: addressed
    note: |
      Added tests for the post-begin rename wait (DELAY_OPS=rename) and the BufFilePost timeout; the BufFilePre unidentified path is noted as a Minor follow-up.
  - id: BR-6
    disposition: addressed
    note: |
      README.md:54-60 documents both keys, the submitting and not-confirmed states, the join rule and the move recovery.
  - id: BR-7
    disposition: addressed
    note: |
      config_ms falls back to require("parley.config")[key]; no literal defaults remain at call sites.
  - id: BR-8
    disposition: addressed
    note: |
      A Revision records that the deadline, join and late-receipt cases are shell-state integration tests; seconds now use ceil, and config.lua documents that background requests share the deadline.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: done-when-clause-tested
    title: |
      BufFilePre membership preflight (unidentified buffer) is never exercised under the slow fake
    detail: |
      This is the 2nd finding in family done-when-clause-tested. Rule: every bounded_request and registry.request call site needs a slow-fake test whose delay exceeds the old default. Remaining instances are agentic_document.lua:705-708 (BufFilePre, reached only without a cached identity) and the rename stage (BR-2).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"0b31a673-7f16-43a1-b335-f91fa2510392","repository":"github.com/xianxu/parley.nvim","issue_id":"000357","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/68f731146be313fb","reviewed_head":"a49f6b55d28f81945ba9d9200f2b1b2a49a40ccd","slot":"parley.nvim:4","requested_at":"2026-10-16T19:31:11.5456Z"},"phase":"finished","pid":52162,"started_at":"2026-10-16T19:31:11.775884Z","finished_at":"2026-10-16T19:36:25.031455Z","session_id":"f4a3763f-257f-47e5-8c45-a8b911ba7df2","outcome":"returned"}] -->
