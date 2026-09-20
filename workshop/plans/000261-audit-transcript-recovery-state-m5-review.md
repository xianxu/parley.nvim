# Boundary Review — parley.nvim#261 (milestone M5)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M5 |
| milestone | M5 |
| window | a5715ec870e7f54f2dbf815b3ea647894bacd52c..3748df3bfeb9e80652b126cde5d8ceeae8ffe067 |
| command | sdlc milestone-close --issue 261 --milestone M5 |
| reviewer | claude |
| timestamp | 2026-09-19T13:32:03-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M5 delivers what it claims: `lua/parley/refusal.lua` is a genuinely pure, data-driven phrasebook; `chat_respond`'s single `refuse()` seam is the only channel; the new `chat_refusal_spec` counts messages through the *combined* flow (leg inside batch, Stop, `:e!`) rather than per-producer, which is exactly the oracle that found the triple-warn and the double-speak. I re-ran the boundary's own evidence independently: `refusal_spec` 8/8, `refusal_vocabulary_spec` 4/4, `chat_refusal_spec` 16/16, `chat_respond_spec` 42/42, `batch_lifecycle_spec` 8/8, `dispatcher_query_spec` 71/71, `chat_progress_process_spec` 7/7, all 19 arch specs green, luacheck clean, and the fresh-clone index guard verified at 1438/1438 on HEAD. Nothing here is blocking. Two Important findings keep it from a clean SHIP: one line (`chat_respond.lua:1763`) encodes a suppression that Lua's `and … nil or …` makes dead, so the provider's diagnosis is printed twice and the internal token `staging overflow` reaches the user verbatim on the overflow ending; and the Task 5.2 census — the guard that is supposed to make "no raw token" true — enumerates *call shapes* rather than the values that reach `describe`, so the producer form that writes `s.failure` directly (`issue(s, <lit>)`) is invisible to it. Both are cheap.

## 1. Strengths

- **The pure/IO split is right.** `describe` takes `held` as *data* (`refusal.lua:222`), and `refuse()` is the only thing that calls `tasker.held()` or reads `config.log_file` (`chat_respond.lua:1350-1359`). The unit spec runs with no stubs at all — a real ARCH-PURE pass, better than the plan's own "stub `tasker.held()`" design.
- **The "once" oracle is tested where things combine, not per-producer.** `chat_refusal_spec.lua:88-101` (leg + batch), `:118-128` (user Stop), `:152-166` (paused once across three later edits) are the cases that found the defects; the lesson written in `workshop/lessons.md` generalises it correctly.
- **`:e!` was measured, not assumed.** The plan said epoch change; the code records `detach` (`generation_runner.lua:123`) and the host disambiguates by buffer loadedness after the command returns (`chat_respond.lua:1767-1769`), pinned in both directions (`chat_refusal_spec.lua:103-117`). The plan revision states the correction rather than overwriting the design.
- **A real permanent blocker is gone.** A paused, settled batch now gives way (`chat_respond.lua:2005-2015`), pinned end-to-end by `chat_refusal_spec.lua:169-193`. This is Done-when "does not leave an unexplained permanent blocker", not a cosmetic change.
- **The docs gate is genuinely met.** Every spec named in `atlas/chat/transcript_truth.md`'s inventory exists; `scripts/spec_test_map.sh list-tests chat/transcript_truth` resolves; the legacy `answer-recovery/` directory's one remaining mention is backed by `chat_respond_spec.lua:172`. README needs nothing (it delegates batch behaviour to `atlas/chat/batch.md`, which was updated).

## 2. Critical findings

None.

## 3. Important findings

**I1 — `chat_respond.lua:1763`: the provider-detail suppression is dead code, and the same line leaks internal tokens.**
`local failure = result.outcome == 'provider_failed' and failure_notice and nil or result.failure` parses as `((A and B) and nil) or result.failure`, so it is *always* `result.failure`. Observed output (computed against the shipped module):
`Response stopped: the model's request failed (provider request failed (HTTP 503)); submit again — parley: provider request failed (HTTP 503): upstream down`
— the comment on the line above ("its reason is not repeated") describes behaviour that never happens. The same line also hands `result.failure` to `describe` for `overflow`, producing
`Response stopped: the response was stopped to keep its output from being dropped (staging overflow); submit again — its output passed the staging budget…`
i.e. the internal token `staging overflow` in front of the user, against M5's "no raw token". Fix: compute it with a statement, and pass `nil` whenever `notice` already carries the diagnosis (`provider_failed`, `overflow`). The existing test stays green either way — see the family note in the findings block.

**I2 — `tests/arch/refusal_vocabulary_spec.lua:9-13`: the census enumerates call shapes, not the values `describe` keys on.**
`describe`'s first lookup key is the `failure` string, and in the runner that string is written by `issue(s, <lit>)` (`generation_runner.lua:152-153`), a form `FORMS` does not scan — `'staging overflow'` (`:163`), `'adapter failed'` (`:301`) and `'cancel adapter missing; operation unresolved'` (`:542`) therefore have no words and reach the user as `unexpected (…)` or as raw parentheticals. Two more sites of the same shape: tokens that appear *only* as an argument to `refuse(kind, outcome, <lit>)` (e.g. `'not a chat'` at `chat_respond.lua:1806`, `'no stale continuation ready'` at `:1421`) are unchecked; and the new shared-cache guard (`single_source_sweeps_spec.lua:391-404`) keys on the literal `stdpath('cache')` while the actual hazard is a spec that simply *inherits* `dispatcher.query_dir`'s default (`dispatcher.lua:17`) — the next offender writes nothing the guard can see.

## 4. Minor findings

- `refusal.lua:132` — `unknown effect`'s action names `:ParleyToolOperations`, but `batch.lua:93,99` never clears `s.unknown`, and `tool_operations.lua` touches only producer records: following the action cannot resume the batch. The action that now works is `:ParleyChatRespondAll`.
- `refusal.lua:230` — `describe` only consults `REVOKED` when `failure == nil`, and `revoked` has no `TOKENS` row, so a revocation that happens to carry any failure string prints `Response stopped: unexpected (…)` instead of the edit/reload words.
- `init.lua:4174` — `M.chat_respond = function(p, cb, ofc, f)` still forwards a 4th argument that `chat_respond.respond` (3 params) has never read; the force flag it served was deleted this round.
- `chat_context.lua:4-9` — the header comment still says "chat_respond.respond names the file, and chat_respond.respond_all returns `nil, reason` to its caller for the header case"; both are now false.
- `row_of`/`internal` iterate `pairs(M.TOKENS)` for the `": "` prefix match — fine today (no key is a prefix of another), but the match order is undefined if one ever is.

## 5. Test coverage notes

- Task 5.3 Step 1 promised "each of the five silent returns → exactly one WARN". Two are covered (`no question selected`, `no questions selected`); `chat header unavailable`, `document structure unavailable` and `question identity unavailable` have no case — and, per I2, their tokens are only checked by the guard because a `return nil, <lit>` happens to sit on the next statement.
- The spec's assertions are mostly `find(needle)`; only the two batch cases use full equality. Substring assertions cannot see duplication or a failed suppression, which is precisely why I1 shipped green. The endings that compose `what + extra + action + notice` (`provider_failed`, `overflow`) deserve equality assertions.
- No case drives `overflow`, `finalize_failed`, `fault`, `round_capacity` or `insert_failed`; those rows exist only under the `TOKENS`-iteration unit test, which checks shape, not the assembled message.
- The kernel-hold case stubs `tasker.held` while the stateful fake lives in `tasker_supervision_spec` — an acceptable ARCH-MOCK split, and the plan states it.

## 6. Architectural notes for upcoming work

- **ARCH-ORDER (flag).** What a batch *says* is decided by three host-side booleans — `user_stopped` (`chat_respond.lua:1363`), `leg_spoke` (`:2034`), `retired` (`:2077`) — crossed with the reducer's `phase`. Eight representable combinations, roughly four legal, none written down; `changed` fires per state change, so the guard against repeats is the flags, not the model. The reducer already owns `s.reason`; giving it a tagged *pause cause* (`user | leg | validation | context`) would let the host read one value instead of reconstructing it. Worth doing before #265 consumes this vocabulary.
- **ARCH-DRY (pass, with a note).** Overflow wording is deliberately split: detail in `chat_presentation.overflow_message`, what/action in `TOKENS.overflow`. That split is now only discoverable from a comment in `chat_presentation.lua:81-82`; state it in `refusal.lua`'s header too, since that is the file the next editor opens.
- **ARCH-PURE / ARCH-MOCK / ARCH-FUNERAL / ARCH-SECURE: pass.** `user_stopped` is weak-keyed, the vocabulary tables are static, nothing durable is created, and non-string tokens are `tostring`ed before display. Provider bodies (≤500 bytes) and pids in notifications are pre-existing #197/#261-M3 surface.
- **ARCH-CONSTRAINTS (pass, nit).** `refuse()` calls `tasker.held()` on *every* refusal even though only three tokens can use it; make it lazy if `held()` ever walks more than the record table.
- **ARCH-PURPOSE (pass).** Shadow-sweep: every submit/generation refusal site now derives from `refusal.lua`; the only hand-maintained restatements left are the guard's `NOT_REFUSAL`/`COMPOSED` tables (by design) and prose in `atlas/chat/batch.md`. #265 is recorded as a future consumer with a concrete instruction, not left as an aspiration.

## 7. Plan revision recommendations

- **Task 5.2 is now stale in its own body.** It still says "three assertions" and lists a `FORMS` set without `reject(owner, lit)`, `cancel(opts, lit)` or the composition rules. The Revisions entry records the delta, but the task table is what a future reader greps. Add a pointer line in Task 5.2 to the 2026-09-19 revision, and add a new revision recording the I2 rule (the census must cover every writer of the value `describe` keys on, not a list of syntactic forms).
- **Case count.** The issue Log and the plan revision both say `chat_refusal_spec` has 15 cases; it has 16.
- Task 5.3 Step 1's "in `tests/integration/chat_respond_spec.lua`" is already corrected in Revisions — no further change needed.

```findings
findings:
  - id: new
    severity: Important
    family: behavior-change-without-regression-test
    title: |
      The provider-detail suppression at chat_respond.lua:1763 is dead, so the diagnosis prints twice and `staging overflow` leaks
    detail: |
      `result.outcome == 'provider_failed' and failure_notice and nil or result.failure`
      parses as `((A and B) and nil) or result.failure`, so `failure` is always
      `result.failure`; the comment above it ("its reason is not repeated") describes
      behaviour that never happens. Verified against the shipped module: the user gets
      "the model's request failed (provider request failed (HTTP 503)); submit again —
      parley: provider request failed (HTTP 503): upstream down". The same line also
      passes `result.failure` for `overflow`, so the internal token "staging overflow"
      is shown, against M5's "no raw token". **This is the 5th finding in family
      `behavior-change-without-regression-test`.** Earlier rounds fixed instances. Do
      NOT just fix this site — the rule is: a change to a user-visible message needs an
      assertion on the WHOLE message (equality), not a substring probe. The existing
      case asserts `find("HTTP 503")`, which is true before and after the intended
      suppression, so it reports nothing; the two batch cases in the same file already
      use equality and are the model. Apply the rule to every ending that composes
      what + extra + action + notice (`provider_failed`, `overflow`, `prepare_failed`).
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      The refusal census scans call shapes, not the values describe() keys on, so `issue(s,<lit>)` tokens have no words
    detail: |
      `describe`'s first lookup key is the `failure` string, written directly by
      `issue(s,<lit>)` in generation_runner.lua:152 — a form absent from the spec's
      FORMS list although generation_runner.lua is in FILES. Unkeyed as a result:
      'staging overflow' (:163, user-visible today, see the other Important finding),
      'adapter failed' (:301), 'cancel adapter missing; operation unresolved' (:542).
      Two further blind spots of the same shape: a token that appears only as an
      argument to `refuse(kind, outcome, <lit>)` (chat_respond.lua:1806 'not a chat',
      :1421 'no stale continuation ready') is never scanned; and the new shared-cache
      guard (single_source_sweeps_spec.lua:391) keys on the literal `stdpath('cache')`
      while the hazard is a spec that inherits dispatcher.lua:17's default query_dir
      and writes there without naming it. **This is the 10th finding in family
      `enumeration-claims-completeness`.** Earlier rounds fixed instances (composed
      reasons, `reject(owner,lit)`) — this round adds a third hole in the same guard.
      Do NOT add another regex. The rule: a guard must key on the VALUE that reaches
      the behaviour, not on the syntax that produces it. For the vocabulary, invert it
      — have `describe` record every token that resolves to "unexpected" (or to an
      outcome-row fallback) into a process-global set, and fail a spec that finds the
      set non-empty after the suite; that covers every present and future producer
      form. For the cache guard, assert at runtime that `dispatcher.query_dir` does not
      resolve under `stdpath('cache')` during a spec run.
  - id: new
    severity: Minor
    family: action-does-not-unblock
    title: |
      `unknown effect` tells the user to run :ParleyToolOperations, which cannot let the batch resume
    detail: |
      batch.lua:93 sets `s.unknown` and :99 rejects every later resume; nothing ever
      clears it, and tool_operations.lua reconciles producer records only. The action
      that actually works after this round's give-way change is ":ParleyChatRespondAll
      to start a new batch". The unit spec only checks that an action matches
      `:Parley%u` — it cannot see that the named command does not clear the condition.
  - id: new
    severity: Minor
    family: fallback-order-hides-known-cause
    title: |
      describe() consults REVOKED only when failure is nil, so a revocation carrying any failure reads "unexpected"
    detail: |
      refusal.lua:230 gates the cause-specific wording on `failure == nil`, and
      'revoked' has no TOKENS row, so `describe('ended','revoked',<any string>,
      {cause='edit'})` returns "Response stopped: unexpected (...)". Reachable whenever
      a cancel/insert path calls `issue()` before the terminal (generation_runner.lua:542,
      :572, :598). Prefer the cause when one is recorded, and fall back to the failure.
  - id: new
    severity: Minor
    family: returned-handle-has-no-consumer
    title: |
      init.lua:4174 still forwards a 4th argument that chat_respond.respond does not accept
    detail: |
      The force flag it carried was deleted this round (cmd_respond), but
      `M.chat_respond = function(p, cb, ofc, f) return chat_respond.respond(p, cb, ofc, f) end`
      still passes it to a three-parameter function. **This is the 5th finding in
      family `returned-handle-has-no-consumer`.** The rule, rather than this instance:
      when a parameter or field loses its last reader, delete it at every hop of the
      call chain in the same commit, and grep the symbol before closing the task —
      the same grep Task 5.3 Step 3 already ran for `resubmit_questions_recursively`.
  - id: new
    severity: Minor
    family: comment-outlives-its-behavior
    title: |
      chat_context.lua's header comment still describes the pre-M5 reporting it no longer owns
    detail: |
      Lines 4-9 say "chat_respond.respond names the file, and chat_respond.respond_all
      returns `nil, reason` to its caller for the header case". After this round
      respond routes through `refuse('start', nil, 'not a chat', {notice=reason})` and
      no longer names the file, and respond_all warns as well as returning. Not the
      `docs-reflow-after-deletion` family: nothing was deleted from this doc — a
      behaviour moved out from under a comment that describes a collaborator.
```

---

## Re-review — 2026-09-19T13:53:45-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M5 |
| milestone | M5 |
| window | a5715ec870e7f54f2dbf815b3ea647894bacd52c..37d326ea8d78cec90c0df1611c4bd80b4311d79a |
| command | sdlc milestone-close --issue 261 --milestone M5 |
| reviewer | claude |
| timestamp | 2026-09-19T13:53:45-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The round-1 bug (BR-65) is genuinely fixed and now pinned by whole-message equality — I ran `tests/integration/chat_refusal_spec.lua` (17/17), `tests/arch/refusal_vocabulary_spec.lua` (4/4), the `chat/lifecycle` and `chat/transcript_truth` mapped sets (all green) and `make lint` (0 warnings). BR-67/68/69 are real fixes with tests behind them. What does not hold is BR-66's remedy: I verified against the shipped module that a producer token arriving under a *known* outcome — the `issue(s,<lit>)` case BR-66 named — is shown to the user verbatim as the ending's detail and is recorded in `_detail_only`, which nothing asserts, so `unkeyed()` stays empty and nothing fails (`R.describe('ended','provider_failed','brand new runner token')` → `Response stopped: the model's request failed (brand new runner token); submit again`). And where the census *can* fire, its `error()` is thrown inside the terminal callback, which `generation_runner.lua:476` and `response_session.lua:14` each wrap in a discarding `pcall` — so the guard reports nothing on the very path it was built for. That, plus the placement of two harness-only checks inside production code, is what to fix before the close; neither is a crash or a user-facing regression, so the gate is not blocked.

## 1. Strengths

- `chat_respond.lua:1760-1774` now composes one detail per ending, and the three composed endings are asserted whole (`chat_refusal_spec.lua:210`, `:220`, `:244`) — the counterfactual table in the plan shows the restored `A and B and nil or C` turning the first red.
- `tests/unit/refusal_spec.lua:64` ("names only commands that exist") converts the plan's advisory rule — *grep `M.cmd.<Name>` when you write a row* — into an executable one over `TOKENS`, `REVOKED` and both batch actions. That is the right shape for a vocabulary that will keep growing.
- The BR-67 fix is behaviourally real, not just a reworded row: `respond_all` (`chat_respond.lua:2008-2015`) disposes a paused, settled batch, and `batch.lua:93` leaves exactly that state (`phase='paused'`, `active=nil`) when a leg ends `unknown` — so `:ParleyChatRespondAll` does clear the condition it now names, and `chat_refusal_spec.lua:166` pins the give-way end to end.
- `atlas/chat/transcript_truth.md` is a map, not prose: every inventory row names what releases the state *and* the spec that pins it.
- `scripts/check-fresh-clone.sh:88-95` turns a silent `.gitignore` filter into a counted failure (`indexed N of M archived`) instead of leaving the nested snapshot to misread it as a deletion.

## 2. Critical findings

None.

## 3. Important findings

**BR-66 remains open** (disposed `not-addressed`, see block) — the census records the value but (a) never fails for the outcome-row fallback, which is where `issue(s,<lit>)` tokens land, and (b) throws into two swallowing `pcall`s on the ending path. Concretely reachable today: the five `issue(s, err)` sites in `generation_runner.lua` (`:207`, `:525`, `:557`, `:572`, `:598`) put a raw Lua error — file path and all — into the user's ending as the detail, against M5's "no raw token", with no guard firing. `atlas/chat/transcript_truth.md:86` and `workshop/targets/transcript-is-the-whole-truth.md` both still credit `refusal_vocabulary_spec` with catching "any producer reason that has none"; that claim needs the same correction.

**New — harness-only checks placed in production code** (`test-hook-in-production-path`). Two guards landed this round inside production paths, gated by `vim.env.PARLEY_TEST_MODE`: the census throw at `refusal.lua:230-235` and the query-dir check at `dispatcher.lua:677`. Consequences: `refusal.lua` is declared pure at its own line 3 and listed under **Pure entities** in the plan, yet `describe` now mutates two module globals and takes an env-dependent branch (ARCH-PURE); `M._detail_only` is written **unconditionally**, including in production, one entry per distinct provider diagnosis (up to ~500 chars of provider body via `_failure_notice`), with `forget_unkeyed()` called only from specs — a growing structure with no removal path and no bound (ARCH-FUNERAL, and a mild ARCH-SECURE note: provider body text retained for the session); and the dispatcher's throw is caught by `generation_runner.lua:365` / `response_provider.lua:100`, so an integration spec sees "provider startup failed" rather than the guard's advice. The rule: *a harness-only check belongs in the harness* — record at the boundary (the `refuse` wrapper), assert it from a spec hook, and give the suite a default `query_dir` under `$TMPDIR` in `tests/minimal_init.vim` so no spec can inherit the shared cache in the first place.

## 4. Minor findings

- `chat_refusal_spec.lua:159` still probes the same `provider_failed` ending with `find(...)`, and the `one(needle)` helper (`:75`) is substring-based for all 17 cases — 6th in `behavior-change-without-regression-test`; the class fix is to make `one()` compare whole messages rather than to patch this line.
- `revoked` has no `TOKENS` row: an ending whose cause is not `edit`/`reload`/`detach` reads `unexpected (revoked)` — 11th in `enumeration-claims-completeness`; the rule is to derive the outcome rows from the machine's outcome set rather than hand-list them.
- `refusal_spec.lua:44`/`:50` set and restore the process-global `_allow_unkeyed` on the success path only — 3rd in `stub-restored-outside-finally`.
- `refusal_spec.lua:64` reads `lua/parley/init.lua` from disk: a source scan inside the PURE entity's unit spec; it belongs beside the other scans in `tests/arch/refusal_vocabulary_spec.lua`.
- `TOKENS["staging overflow"]` (`refusal.lua:146`) is unreachable now that the overflow path always supplies a notice and drops the failure.
- `row_of` and `internal` (`refusal.lua:192-207`) are the same `": "`-prefix scan written twice (ARCH-DRY, cosmetic).

## 5. Test coverage notes

Green as run: `chat_refusal_spec` 17, `refusal_vocabulary_spec` 4, `refusal_spec`, plus the `chat/lifecycle` and `chat/transcript_truth` mapped sets; lint clean. The gaps that matter: no case drives an unkeyed producer token through the real session (the census's entire purpose — and such a case would currently *hang* rather than fail, because the throw aborts `terminal` before `frame.terminal(result)`, so a batch leg never finishes); no case for a `revoked` ending without a cause; no case asserts `refusal.unkeyed()`/`detail_tokens()` after a flow.

## 6. Architectural notes for upcoming work

ARCH-DRY pass (one vocabulary; only the duplicated prefix scan above). ARCH-PURE **flag** (census in the pure core — see the Important finding). ARCH-PURPOSE **flag**: the shadow-sweep finds one more hand-maintained restatement of the model — the pause notices at `chat_respond.lua:1701-1704` still carry their own words and actions (`:ParleyChatResumeResponse`, `:ParleyStop`) outside `refusal.lua`, while the atlas says the words live there; either bring them in or scope the claim. ARCH-MOCK pass (`respond_fixture` is a stateful double at the transport seam and the specs drive the real session). ARCH-CONSTRAINTS pass (per-query env check is trivial; detail length is capped upstream at 4096/500). ARCH-SECURE note (internal paths and provider bodies reach user-facing text through the detail branch). ARCH-ORDER: the terminal composition is a four-input ad-hoc decision — the exact site of BR-65 — and would read better as a small per-outcome table saying which input supplies the detail. ARCH-FUNERAL **flag** (`_unkeyed`/`_detail_only`).

## 7. Plan revision recommendations

1. A `## Revisions` entry recording that BR-66's remedy as built covers only the "unexpected" branch and is swallowed at the ending seam, and naming where the census will live (boundary, not `refusal.lua`).
2. Correct `atlas/chat/transcript_truth.md:86` and the target's 2026-09-19 delta, which both claim the arch scan makes a bare-token refusal impossible.
3. Task 5.3 Step 1 says the integration cases land in `tests/integration/chat_respond_spec.lua`; they landed in a new `chat_refusal_spec.lua` — one line so the plan matches the tree.

```findings
dispose:
  - id: BR-65
    disposition: addressed
    note: |
      Verified on the shipped module and by running the spec: the provider, prepare and
      overflow endings now assert whole messages and the internal token no longer leaks.
  - id: BR-66
    disposition: not-addressed
    note: |
      The census never fails for the outcome-row fallback, which is exactly where
      `issue(s,<lit>)` tokens land: R.describe('ended','provider_failed','brand new runner
      token') returns "...the model's request failed (brand new runner token)..." with
      unkeyed() empty. Where it can fire, the error is thrown inside the terminal callback
      that generation_runner.lua:476 and response_session.lua:14 each pcall and discard.
      Remaining: fail (or assert after each spec) on _detail_only too, report through a
      channel the seam cannot swallow, and correct the atlas/target sentence crediting
      refusal_vocabulary_spec with catching any wordless producer reason.
  - id: BR-67
    disposition: addressed
    note: |
      The named command genuinely unblocks: respond_all disposes a paused, settled batch
      (chat_respond.lua:2008-2015) and batch.lua:93 leaves exactly that state.
  - id: BR-68
    disposition: addressed
    note: |
      Cause now outranks a stray failure (refusal.lua:252), asserted by equality in
      refusal_spec.lua:80.
  - id: BR-69
    disposition: addressed
    note: |
      init.lua:4174 forwards three arguments; every call site in lua/ and tests/ passes one.
  - id: BR-70
    disposition: not-addressed
    note: |
      The stale sentence was replaced by another inaccurate one: "respond and respond_all
      both warn, and both still return `nil, reason`" — respond returns a bare `return` on
      both ctx failures (chat_respond.lua:1813) and respond_all does on its not-a-chat path
      (:2005); init's wrapper logs an ERROR, not a warning, for a broken header
      (init.lua:4300). Rule: a comment about a collaborator cites it (file:line) or states
      only what this module guarantees.
findings:
  - id: new
    severity: Important
    family: test-hook-in-production-path
    title: |
      Both new guards live in production code behind PARLEY_TEST_MODE; one makes the pure vocabulary stateful and grows unbounded in production, the other is swallowed by the calling seam
    detail: |
      refusal.lua:230-235 and dispatcher.lua:677 put harness-only checks on production
      paths. `describe` is declared pure (refusal.lua:3) and listed under the plan's Pure
      entities, but now mutates M._unkeyed/M._detail_only and branches on vim.env
      (ARCH-PURE). M._detail_only is written unconditionally, in production too — one entry
      per distinct provider diagnosis, carrying up to ~500 chars of provider body, with
      forget_unkeyed() called only from specs: a growing structure with no removal path and
      no bound (ARCH-FUNERAL; ARCH-SECURE for the retained body text). The dispatcher's
      error is caught by generation_runner.lua:365 / response_provider.lua:100, so an
      integration spec sees "provider startup failed" instead of the guard's advice. The
      rule: a harness-only check belongs in the harness — record at the boundary (the
      `refuse` wrapper), assert from a spec hook, and default query_dir to $TMPDIR in
      tests/minimal_init.vim so no spec can inherit the shared cache.
  - id: new
    severity: Minor
    family: behavior-change-without-regression-test
    title: |
      The refusal spec's `one()` helper is a substring probe, so the batch-pause case still cannot see a second detail on the same provider_failed ending
    detail: |
      chat_refusal_spec.lua:159 asserts find("Response stopped: the model's request failed")
      on the ending BR-65 broke, and one() (:75) matches by substring for all 17 cases, so
      appended text is invisible. This is the 6th finding in family
      behavior-change-without-regression-test. Earlier rounds fixed instances. Do NOT fix
      this line — the rule is that a case asserting a composed message compares the WHOLE
      string; apply it by making one() take the full expected message and use assert.equals,
      so every present and future case inherits it.
  - id: new
    severity: Minor
    family: enumeration-claims-completeness
    title: |
      `revoked` has no TOKENS row, so an ending whose cause is not edit/reload/detach reads "unexpected (revoked)"
    detail: |
      refusal.lua:252 words a revocation only for a mapped cause; generation.lua:361 stops
      with outcome 'revoked' on any grant_revoked, while generation_runner.lua:132 records a
      cause only for EDIT_REASONS and epoch/detach — 'explicit revoke' and 'generation
      finished' leave it nil. No spec covers a cause-less revocation, so reachability is
      unverified either way. This is the 11th finding in family
      enumeration-claims-completeness. Do NOT add one row — the rule is that the terminal
      outcomes' rows are derived from the machine's outcome set, so an outcome without
      words fails at load rather than at a user's screen.
  - id: new
    severity: Minor
    family: stub-restored-outside-finally
    title: |
      refusal_spec sets the process-global _allow_unkeyed and restores it only on the success path
    detail: |
      tests/unit/refusal_spec.lua:44 sets R._allow_unkeyed = true and :50 restores it after
      the assertions; a failing assertion leaves the guard disabled for every later case in
      the process (and :35's assignment is already a no-op). This is the 3rd finding in
      family stub-restored-outside-finally. The rule: a spec that mutates a process-global
      restores it from after_each or through the repo's Stub.with_stub, never on the happy
      path.
```

---

## Re-review — 2026-09-19T14:24:16-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M5 |
| milestone | M5 |
| window | a5715ec870e7f54f2dbf815b3ea647894bacd52c..a9b20b22e8b256c2c7be10b26930a5e4734221f4 |
| command | sdlc milestone-close --issue 261 --milestone M5 |
| reviewer | claude |
| timestamp | 2026-09-19T14:24:16-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M5 delivers the vocabulary well: `refusal.lua` is pure again, the harness watch in `tests/minimal_init.vim` genuinely fails a spec file (I reproduced it — exit 1 via `cquit`), every child now loads the init, and `chat_refusal_spec`'s 17 cases drive real sessions and compare whole messages. All seven changed/added spec files pass in an isolated env, and luacheck is clean. What blocks a clean SHIP is that the carried census finding is still open in the exact place it was raised: on the *ending* path `unkeyed` is unreachable (every outcome now has a row, so an unworded failure falls through to the outcome row and is printed raw as a parenthetical), and that path is where the runner's `issue(s,<lit>)` tokens live. I measured a live instance — `Response not started: the response could not start (detach); submit again`, produced 8 times across the integration suite today — so the "no raw token" contract is not yet met and neither guard can see it.

## 1. Strengths

- **The watch is real, not a claim.** I ran a scratch spec that calls `describe("start", nil, "zzz brand new token")` under `tests/minimal_init.vim`: the file exits 1 with `refusal: these reached a user with no words: zzz brand new token`. `cquit` from `VimLeavePre` does survive plenary's `0cq`/`1cq` exit path.
- **`describe` is pure again and reports instead of recording** (`lua/parley/refusal.lua:226-273`): the message plus a resolution class, with the state moved to the harness (`tests/minimal_init.vim:50-68`). That is the right shape for BR-71, and it removed the unbounded `_detail_only` retention in one move.
- **The outcome enumeration now derives from the machine** (`lua/parley/generation.lua:72-76` + `lua/parley/refusal.lua:278-281`): `stop()` asserts membership, and `refusal.lua` fails at *load* if an outcome has no words. I checked all nine `stop(s,effects,…)` call sites — the set is complete.
- **`tests/helpers/spec_runner.lua:19-22`** giving every child the init is a genuine harness repair; it immediately exposed `file_tracker`'s short-circuit branch that had been dead under the suite.
- **`scripts/check-fresh-clone.sh:82-90`** counts archived vs indexed files rather than trusting `git add`; that is a guard with an oracle, not a comment.

## 2. Critical findings

None.

## 3. Important findings

**BR-66 (carried, `not-addressed`) — the value census cannot fire on the path it was raised about.** `lua/parley/refusal.lua:245-254`: when `failure` has no row but `outcome` does, the resolution is `detail`, not `unkeyed`, and the raw token is printed in parentheses. Since the load-time check now guarantees *every* outcome has a row, `unkeyed` is unreachable for every `kind='ended'`/`'start refused'` refusal — i.e. for every runner `issue(s,<lit>)` and adapter `cb.failed(<lit>)` token, the exact form BR-66 named. Measured: a probe wrapper over `batch_lifecycle`, `chat_respond`, `chat_stop_generation`, `generation_settles`, `chat_refusal`, `drill_in_transaction`, `response_session`, `chat_scoped_response` logged `start refused | detach` 8×. `atlas/chat/transcript_truth.md:92-94` and the target's Revisions still say the harness "fails the spec file that produces a token with no words" — it does not, on that path. The rule to fix: a token and a free-text diagnosis must not share the `failure` field — type them at the producer (token vs. notice), so that a failure which is neither keyed nor internal resolves `unkeyed` on *every* kind, and free text only ever arrives through the caller-declared `notice`/detail channel.

**New (Important, `canonical-form-not-shared`) — the document-lifecycle cause has no single home.** `lua/parley/response_target.lua:116` retires with `event.kind` (`'detach'`/`'reload'`), which reaches `refuse('start','start refused',why)` and prints `Response not started: the response could not start (detach); submit again` — a raw internal token, plus a "submit again" the user cannot act on because they just closed the chat. Meanwhile the detach⇒silence / detach-while-loaded⇒reload rule is hand-written twice, at `lua/parley/chat_respond.lua:1773` and `:2088-2091` (ARCH-DRY). **This is the 3rd finding in family `canonical-form-not-shared`.** Do not patch the one site: state the rule — *refusal.lua owns the mapping from a document-lifecycle token to words or silence for every `kind`, not only for `outcome=='revoked'`, and every path hands it the raw token* — and let `terminal`, `rejected`, the batch `retired` and the target retire all inherit it.

**New (Important, `comment-outlives-its-behavior`) — the harness's own docs now state the opposite of what it does.** `tests/minimal_init.vim:25-27` ("PlenaryBustedFile runs each spec in a child nvim started WITHOUT this init, so g: variables set here never reach a spec") and `atlas/infra/test_harness.md:42-46` ("Signals to spec code travel through the environment, not `g:`… never reaches a spec") are both false after `spec_runner.lua:19-22`. **This is the 2nd finding in family `comment-outlives-its-behavior`** (BR-70 was the first, this round). The rule: when a seam's behaviour changes, sweep every prose claim naming that seam in the same commit — here `grep -rn "minimal_init\|PlenaryBustedFile\|parley_test_mode" atlas tests TOOLING.md` — rather than fixing the comment the reviewer happened to read.

## 4. Minor findings

- **BR-72 (`not-addressed`).** `one()` is equality now, but `tests/integration/chat_refusal_spec.lua:165` — the batch-pause case BR-72 named — still uses `find("Response stopped: the model's request failed")`, because a two-message case cannot use `one()`. Give it a `refusals_are({…})` helper (`assert.same` over the whole list) and make `one()` delegate to it, so multi-message cases inherit the rule too.
- **`allowlist-without-dead-entry-check` (3rd).** `tests/arch/refusal_vocabulary_spec.lua:19-26` still claims `busy`, `refused`, `revoked`, `stale` are "not a refusal", while `TOKENS` now words all four as refusals a user meets (measured with a probe over the spec's own tables). Rule: assert the allowlist is *disjoint* from `TOKENS`/`INTERNAL` and that every entry is still produced by the scan.
- **`canonical-form-not-shared` (4th).** `lua/parley/chat_respond.lua:1702` (the response-pause warning with its own `:ParleyChatResumeResponse`/`:ParleyStop` advice) and `:1166` (topic abort) are the last hand-written user-facing notices on this path; neither guard can see them, because the arch spec keys on the `PREFIX` literals and "Response paused" is not one. Rule: key the guard on the *channel* — a `logger.warning`/`vim.notify` literal inside the submit/generation modules that is not `refuse()`'s return is a finding.
- **`state-change-bypasses-model` (2nd).** The batch pause's wording depends on four flags whose legal combinations are unwritten: `phase`, `active`, host-side `user_stopped[batch]` and the `leg_spoke` upvalue (`chat_respond.lua:2037-2044`, `:2071-2080`). Rule: the *cause* of a pause belongs in the batch machine's transition (`cancel(batch, {cause='user'})`, surfaced on the snapshot), so it can be read off the model and driven by a sequence test.
- **`plan-tracking-not-updated` (4th).** The round-2 dispositions in the issue Log and plan Revisions are labelled one id off the ledger (logged "BR-73" is ledger BR-72, "BR-74" is BR-73, "BR-70/72" is BR-70/74), which makes the next round's audit trail unverifiable. Rule: a disposition quotes the ledger id verbatim.

## 5. Test coverage notes

- Verified at HEAD in an isolated `HOME`/`XDG`/`TMPDIR`: `refusal_spec` 15, `refusal_vocabulary_spec` 4, `chat_refusal_spec` 17, `file_tracker_spec` 15, `dispatcher_query_spec` 71, `single_source_sweeps_spec` 24, `chat_progress_process_spec` 7 — all pass, rc=0.
- The bug class this diff can ship is uncovered: no case drives a refusal whose failure is a *lifecycle* token on the start path (close or `:e!` a chat while a response is still starting). That case would go red on the raw `(detach)` today.
- `refusal_spec:68-72` duplicates the load-time assertion in `refusal.lua:278-281` — it can never fail independently (the `require` errors first). Harmless, but it is not the regression evidence it looks like; the counterfactual is the load failure.
- `refusal_spec:52-57` reads `document/editor.lua` and `user_edits.lua` from disk inside a spec for an entity the plan lists as PURE; that derivation belongs in `refusal_vocabulary_spec` with the other source scans.

## 6. Architectural notes

- **ARCH-DRY** — flag (lifecycle mapping duplicated, `chat_respond.lua:1773` / `:2088-2091`).
- **ARCH-PURE** — pass. `describe` holds no state, has no environment branch, and returns its resolution; the state is in the harness. This is the correct resolution of BR-71.
- **ARCH-PURPOSE** — flag. The shadow sweep over the single source finds two consumers that do not derive: the lifecycle tokens (raw) and the pause/abort notices (hand-maintained). The guard was rebuilt to key on values, but the value path that motivated it is precisely the one it cannot reach.
- **ARCH-MOCK** — pass. The refusal specs run the real session against the fixture transport; `tasker.held` is stubbed at its seam, and `tasker_supervision_spec` pins it against a KILL-ignoring fake.
- **ARCH-CONSTRAINTS** — pass. `row_of`'s linear scan runs only on a miss over ~100 rows, off any keystroke path; the watch adds one comparison per refusal.
- **ARCH-SECURE** — pass. Provider text is truncated to the first line by `describe` and to 500 chars by `_failure_notice`; no credential reaches a message; round 1's retention of provider bodies is gone.
- **ARCH-ORDER** — flag (Minor, above). Also worth noting for later: `retired`'s `vim.schedule` decides "reload vs closed" by reading buffer state on a later turn — correct today, but it is an ordering assumption with exactly one interleaving pinned.
- **ARCH-FUNERAL** — pass. `$PARLEY_QUERY_DIR` dirs are per-process under the harness scratch root that `make test` clears first. One residue note: when `$TMPDIR` is unset the init falls back to `/tmp/parley-query-<pid>`, which nothing sweeps.

## 7. Plan revision recommendations

- A `## Revisions` entry correcting the round-2 disposition ids (BR-72/73/74 as above), so the ledger and the plan agree.
- Update the Core-concepts `refusal` row to list `BATCH_CONTINUE`/`BATCH_RESTART`, and add the two seams this milestone actually introduced: `generation.OUTCOMES` (modified) and `tests/minimal_init.vim`'s watch as the enforcing harness component.
- Correct the sentence in `atlas/chat/transcript_truth.md:92-94` and in the target's 2026-09-19 Revisions: the harness fails only on `unkeyed`, which the ending path cannot produce — say what the two nets actually cover, and record the ending-path gap until it is closed.
- Record, in Chunk 5's "What is broken today", either a row for `chat_respond.lua:1702`'s pause text or an explicit statement that a pause is out of the vocabulary's scope — right now the batch's pause is in the vocabulary and the response's is not.

```findings
dispose:
  - id: BR-66
    disposition: not-addressed
    note: |
      The value census cannot fire on the ending path: every outcome now has a row, so an
      unworded failure resolves `detail` (refusal.lua:245-254) and prints the raw token in
      parentheses instead of `unkeyed`. Measured today across eight integration specs:
      `start refused | detach` (8x), user-visible as "Response not started: the response could
      not start (detach); submit again". That is the runner/adapter token form BR-66 named, and
      the atlas/target sentences still over-credit the watch. The rule: a producer token and a
      free-text diagnosis must not share the `failure` field — type them at the producer so a
      failure that is neither keyed nor internal resolves `unkeyed` on every kind, and free text
      arrives only through the caller-declared notice channel.
  - id: BR-70
    disposition: addressed
    note: |
      chat_context.lua:4-9 now states only this module's own guarantee; verified no logger or
      notify call remains in the module, and resolve/parse/chat_buffer return typed errors.
  - id: BR-71
    disposition: addressed
    note: |
      describe is pure and stateless again (returns message + resolution); the watch lives in
      tests/minimal_init.vim and was verified to fail a spec file with exit 1 through cquit;
      dispatcher reads a plain $PARLEY_QUERY_DIR override with no harness branch.
  - id: BR-72
    disposition: not-addressed
    note: |
      one() is equality now, but the case BR-72 named (chat_refusal_spec.lua:165, two refusals)
      cannot use one() and still probes with find(); add a refusals_are({...}) helper asserting
      the whole list and have one() delegate to it.
  - id: BR-73
    disposition: addressed
    note: |
      generation.OUTCOMES declared next to stop() with an assert, and refusal.lua fails at load
      if an outcome has no words; `revoked` has a row. All nine stop() call sites checked against
      the set; removing the row makes every spec that requires refusal.lua fail at load.
  - id: BR-74
    disposition: addressed
    note: |
      The process-global _allow_unkeyed is gone (no reference remains); the exemption is
      file-scoped vim.g.parley_expected_unkeyed in refusal_spec.lua:5, with nothing to restore.
findings:
  - id: new
    severity: Important
    family: canonical-form-not-shared
    title: |
      The document-lifecycle cause has no single home: 'detach' reaches the user raw on the start path, and the detach-to-reload mapping is written twice
    detail: |
      response_target.lua:116 retires with event.kind, which reaches refuse('start','start refused',why)
      and prints "Response not started: the response could not start (detach); submit again" — a raw
      token, plus an action the user cannot take because the chat is closed. The silence/wording rule
      for detach and reload is hand-written at chat_respond.lua:1773 and again at :2088-2091, and not at
      all here. This is the 3rd finding in family canonical-form-not-shared. Do NOT fix the one site:
      refusal.lua should own the mapping from a lifecycle token to words or silence for every kind, not
      only for outcome=='revoked', with every path handing it the raw token.
  - id: new
    severity: Important
    family: comment-outlives-its-behavior
    title: |
      The harness docs still say spec children start without tests/minimal_init.vim, which this milestone changed
    detail: |
      tests/minimal_init.vim:25-27 and atlas/infra/test_harness.md:42-46 both state that children never
      load the init and that g: variables never reach a spec; spec_runner.lua:19-22 now passes
      minimal_init to every child. This is the 2nd finding in family comment-outlives-its-behavior.
      The rule: a seam's behaviour change sweeps every prose claim naming that seam in the same round
      (grep minimal_init, PlenaryBustedFile, parley_test_mode across atlas, tests and TOOLING.md).
  - id: new
    severity: Minor
    family: canonical-form-not-shared
    title: |
      The response pause and the topic abort are still hand-written user notices the vocabulary guard cannot see
    detail: |
      chat_respond.lua:1702 words a pause with its own actions, and :1166 words a topic abort; neither
      derives from refusal.lua, and the arch spec cannot see them because it keys on the PREFIX literals
      and "Response paused" is not one — while the batch's pause IS in the vocabulary. 4th finding in
      family canonical-form-not-shared. The rule: key the guard on the channel — a logger.warning or
      vim.notify literal inside the submit/generation modules that is not refuse()'s return is a finding.
  - id: new
    severity: Minor
    family: allowlist-without-dead-entry-check
    title: |
      NOT_REFUSAL still claims busy, refused, revoked and stale reach no user, while TOKENS words all four
    detail: |
      Measured against the spec's own tables: those four keys are in both refusal_vocabulary_spec.lua:19-26
      and refusal.lua TOKENS, so the allowlist entries are shadowed and their stated reason is now false.
      3rd finding in family allowlist-without-dead-entry-check. The rule: assert the allowlist is disjoint
      from TOKENS/INTERNAL and that every entry is still produced by the scan, rather than deleting
      whichever entry a reviewer noticed.
  - id: new
    severity: Minor
    family: state-change-bypasses-model
    title: |
      A batch pause's cause lives in host-side flags outside the batch machine
    detail: |
      What the pause says depends on phase, active, the weak-keyed user_stopped[batch] and the leg_spoke
      upvalue (chat_respond.lua:2037-2044, :2071-2080); the legal combinations are unwritten and only the
      happy interleaving is pinned. 2nd finding in family state-change-bypasses-model. The rule: the cause
      of a pause is part of the batch's transition (cancel(batch, {cause='user'}) surfaced on the snapshot),
      so it is readable off the model and drivable by a sequence test.
  - id: new
    severity: Minor
    family: plan-tracking-not-updated
    title: |
      Round 2's dispositions are recorded one finding id off the ledger in both the issue Log and the plan
    detail: |
      Logged "BR-73" is ledger BR-72 (the one() helper), logged "BR-74" is BR-73 (the outcome set), and
      "BR-70/72" is BR-70/74 (the file-scoped exemption). 4th finding in family plan-tracking-not-updated.
      The rule: a disposition quotes the ledger id verbatim, so a later round can verify what was claimed.
```

---

## Re-review — 2026-09-19T15:09:22-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M5 |
| milestone | M5 |
| window | a5715ec870e7f54f2dbf815b3ea647894bacd52c..6b8c71645b496bcab8607256d993cc2422976655 |
| command | sdlc milestone-close --issue 261 --milestone M5 |
| reviewer | claude |
| timestamp | 2026-09-19T15:09:22-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

All specs in the window pass and lint is clean. Here is the review.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M5 delivers what Chunk 5 specifies: `lua/parley/refusal.lua` is a genuinely pure vocabulary (message + resolution, no state, no IO), every silent return on the submit path now speaks, the static census and the new harness watch are both real and both catch things, and the inventory page lands in `atlas/`. I re-ran every spec file the window touches — `refusal_spec` (15), `refusal_vocabulary_spec` (6), `chat_refusal_spec` (17), `chat_respond_spec` (42), `batch_lifecycle_spec` (8), `generation_settles_spec` (19), `generation_sequences_spec` (32), `chat_progress_process_spec` (7), `cliproxy_caller_teardown_spec` (5), `dispatcher_query_spec` (71), `file_tracker_spec` (15), `single_source_sweeps_spec` (24) — all green, plus `make lint` (0/0 in 644 files). Eight of the nine open findings are genuinely disposed. What keeps this from SHIP is that round 3's own headline rule — *a producer token and a free-text diagnosis must not share the `failure` field* — is still un-swept on three live producers, and the new channel guard has re-acquired the exact blind spot BR-66 named (it keys on syntax, not on the value), leaving two live warning channels unrouted inside the very file it scans. Neither is a correctness bug; both are the milestone's deliverable under-delivering its own stated rule.

## 1. Strengths

- **`refusal.lua` is the right shape.** `describe` returns `(message, resolution)` and keeps nothing (`lua/parley/refusal.lua:245-311`). That single design choice is what let round 2 move the census out of production and into `tests/minimal_init.vim:59-79` without a `$PARLEY_TEST_MODE` branch anywhere in `lua/`. Confirmed-good ground.
- **The harness watch earns its keep and cannot be swallowed.** `cquit 1` from `VimLeavePre` (`tests/minimal_init.vim:70-78`) is above every `pcall` seam, and `spec_runner.lua:22-26` now passes `minimal_init` to plenary so it covers all children rather than the ones that remember to ask. I verified it fires: driving three free-text values through `describe` printed `refusal: these reached a user with no words: …`.
- **Whole-message equality, applied as a rule not a patch.** `refusals_are` → `assert.same` on the full list (`tests/integration/chat_refusal_spec.lua:78-86`), with `one()` delegating, so all 17 cases inherit it including the two-message batch case. This is what closes BR-72 properly.
- **Load-time completeness check.** `refusal.lua:314-318` asserts every `generation.OUTCOMES` member has words at require time, so an outcome added without a row fails in every spec that touches the module rather than in one user's chat.
- **The `batch active` permanent blocker removal is real and pinned.** `chat_respond.lua:2013-2022` lets a settled paused batch give way, with `leg unresolved` distinguished from `batch active`; `chat_refusal_spec.lua:170-193` drives the reworded-question path end to end.

## 2. Critical findings

None.

## 3. Important findings

### I1 — `failure` still carries free text on three producers, so a real cliproxy failure reads "unexpected (…)"

`lua/parley/response_provider.lua:21`, `lua/parley/generation_runner.lua:69`, `lua/parley/generation_runner.lua:492`

**This is the 12th finding in family `enumeration-claims-completeness`.** Earlier rounds fixed instances. Do NOT fix these three sites — state the rule and fix that.

Measured, not inferred:

```
describe("ended","provider_failed","cliproxy: proxy did not become healthy within 30s — try :ParleyProxy status")
  → unkeyed | "Response stopped: unexpected (cliproxy: proxy did not become healthy within 30s — try :ParleyProxy status); the details are in the Parley log"
describe("ended","fault","lua/parley/document/init.lua:412: attempt to index a nil value (field ?)")
  → unkeyed | "Response stopped: unexpected (lua/parley/document/init.lua:412: …); …"
```

The chain for the first: `cliproxy.ensure_running`'s `on_error` (`cliproxy.lua:731,736,777`) → `dispatcher.lua:926 abort_before_start` → `D.query`'s `on_abort` → `response_provider.lua:99 abort` → `failure_reason`, whose string branch (`:21`) returns *any* string verbatim → `cb.failed(reason)` with no `diagnosis` → `s.failure` → `chat_respond.lua:1781 refuse('ended','provider_failed', <prose>)`. `provider_failed` has a perfectly good row; it is never reached. `vault.run_with_secret`'s `on_error` (`vault.lua:251,267`) reaches the same seam. `fault` is worse still: `generation_runner.lua:492` writes a Lua error into `s.failure`, `generation_settles_spec.lua:228` pins exactly that, and the consequence is that the `fault` TOKENS row (`refusal.lua:179`) has **zero reachable consumers**.

Neither net sees any of this. The static census's `FILES` list omits `cliproxy.lua`, `vault.lua`, `response_completion.lua`, `response_preparation.lua`, `response_topic.lua` — modules whose strings provably reach `failure`. The harness watch only sees values a spec drives, and no spec drives a fault or a pre-query abort through `chat_respond`'s terminal.

**The rule:** `failure` must hold a value `refusal` can resolve, and that has to be enforced **where the value is stored**, not where it is displayed — otherwise coverage of the invariant equals coverage of the specs, which is the same syntax-vs-value mistake in a new disguise. Concretely: export `refusal.is_token(value)` (a row, an `INTERNAL` entry, a `": "` lead-in, or a `LIFECYCLE` key) and make `generation_runner.issue` route anything that fails it into `diagnosis` instead of `failure`, asserting under `$PARLEY_TEST_MODE`. `fault`, `kill_scope` and `failure_reason`'s pass-through branch are then covered by construction, together with every future producer, and the `FILES`/module enumeration stops needing to be complete.

### I2 — the channel guard keys on a string literal, so two live warning channels in the file it scans are neither routed nor declared

`tests/arch/refusal_vocabulary_spec.lua:138-152`, `lua/parley/chat_respond.lua:437`, `lua/parley/chat_respond.lua:1364`

BR-77's rule was "key the guard on the **channel**". The implementation greps `logger%.warning%(%s*(['\"])` and `vim%.notify%(%s*(['\"])` — a literal first argument. A warning whose argument is a variable or a concatenation starting with one is invisible, and two such sites live in `chat_respond.lua`, which is in `CHANNEL_FILES`:

- `:437` `logger.warning(plan.warning)` — the attachment-budget notice, reaching the user with no prefix and no action.
- `:1364` `_parley.logger.warning(label .. ' failed: ' .. tostring(err))` — the `guarded()` helper behind `cancel_topic` and `stop_batch`, i.e. the **Stop path**. A throwing batch cancel prints `batch cancel failed: lua/parley/…: attempt to …` — a raw traceback, no prefix, no action.

So `it("routes every user notice in the submit path through refuse")` passes while asserting something untrue, and `NOT_A_REFUSAL_NOTICE` claims a completeness it does not have. Same rule as I1: match on the **call**, not on its first token — scan for `logger.warning(` / `vim.notify(` regardless of argument shape, and require every site to be either `refuse()`'s return or an explicitly declared non-refusal. Then route `plan.warning` and `guarded` through the vocabulary (the latter is a lifecycle-adjacent internal failure; `INTERNAL` plus the log pointer fits it).

## 4. Minor findings

- **Two dead handles introduced this round.** `chat_respond.lua:52` exports `M._lifecycle_cause` labelled `-- test seam`, and no test references it (it is the only one of the repo's five `-- test seam` exports with no consumer; the other four are used). `result.refusal` is written at `chat_respond.lua:1754` and `:1781` and read **nowhere** in `lua/` or `tests/` — while the plan's round-3 revision claims "the leg's terminal hands its message to the batch as `result.refusal`". The batch actually derives `leg_stopped` from `generation.OUTCOMES[state.reason]` (`:2078`). **6th finding in family `returned-handle-has-no-consumer`** — the rule, rather than the two sites: an `M._*` export labelled a test seam, and a field added to a snapshot/result table, must have a reader in the same commit; a cheap arch assertion over `-- test seam` exports would pin it.
- **One-line-of-a-Lua-error is copy-pasted six ways.** `tostring(x):match('^[^\n]+')` appears at `chat_respond.lua:1670`, `:1693`, `:1297`, `response_session.lua:95`, `:164`; `response_target.lua:113` uses `:sub(1,512)` instead. Only two carry the `or 'unknown'` fallback. `debug.traceback("")` begins with `\n`, so the match returns `nil` and the three unguarded sites throw `attempt to concatenate a nil value` *inside the failure handler* (verified: `debug.traceback(""):match("^[^\n]+")` → `nil`). **5th finding in family `canonical-form-not-shared`** — one helper, `refusal.brief(err)`, with the fallback and the cap built in. (ARCH-DRY.)
- **The vocabulary's reach stops at the submit path.** `init.lua:4294-4303` still hand-words the same two conditions `refusal.lua` now owns — `not a chat` and a missing header — for `ChatPrune`, `ExchangeCut`, `ExchangePaste` and `NewQuestion`, in a different voice and with no action ("Prune is only available in chat files: …"). **6th finding in family `canonical-form-not-shared`.** Out of M5's declared scope, but it is the remaining hand-maintained restatement the ARCH-PURPOSE shadow-sweep asks for; the fix is one `refuse()` kind, not four rewordings.
- **`lifecycle_cause` trusts a buffer number.** `chat_respond.lua:48-51` maps `detach → reload` on `nvim_buf_is_valid(buf) and nvim_buf_is_loaded(buf)`, with no check that the buffer is still the same chat. Buffer numbers are reused after `:bd` — the hazard this issue's own audit named — so a closed chat whose number was taken by another file reports "the chat was reloaded". Narrow window (the terminal fires on the next deferred turn), one-line fix by comparing the buffer's name or `D.get(buf)`.
- **The per-process query dir names no end.** `tests/minimal_init.vim:56-58` creates `$TMPDIR/parley-query-<pid>` in every nvim process and nothing removes it; request bodies accumulate inside. `make test` is bounded by its leading `test-clean-env`, but `make test-spec`, `make test-changed` and the direct `PlenaryBustedFile` invocation TOOLING.md documents all leave them behind — one directory per spec file, per run. **3rd finding in family `residue-names-no-end`**; the removal path belongs beside the creation (a `VimLeavePre` `delete(…, "rf")`), not in a target the operator has to remember.

## 5. Test coverage notes

- `chat_refusal_spec`'s 17 cases are the right shape: whole-message equality, real fixture-driven flows (a 1 MiB overflow, four concurrent responses for the capacity case, `:e!` vs `enew`+unload to separate reload from close), and negative cases that assert `{}`. This is the coverage that would have caught BR-65.
- The gap that matters is the one I1 rests on: **no spec drives `fault`, a pre-query abort, or a vault resolve failure through `chat_respond`'s terminal**, so the watch — the milestone's headline net — has never seen those paths. Adding one case per producer would turn I1 red today. `generation_settles_spec.lua:214-234` exercises `fault` at the runner but stops short of the host, which is precisely where the wording is decided.
- `tests/perf/ownership.lua:33-36` now stops the way a user does, so the benchmark no longer manufactures a wordless refusal — a good catch, and the right fix (change the caller, not the vocabulary).
- ARCH-MOCK passes: `Fixture.install(parley)` is a stateful double at the dispatcher seam, production and test flow share the boundary, and `tasker.held` is stubbed at the seam with `tasker_supervision_spec` pinning it against a fake that ignores KILL.

## 6. Architectural notes for upcoming work

Marker-by-marker, as requested:

- **ARCH-DRY — flag.** The six-way `tostring(err)` idiom above. Also `refusal.lua`'s `row_of` (`:225-233`) and `internal` (`:234-241`) implement the same `": "` prefix-scan over two tables; one parametrised helper would do.
- **ARCH-PURE — pass.** `refusal.lua` touches no IO, holds no state, and its unit spec runs without doubles. The two `vim.fn.readfile` calls in the spec are source-reading guards, not mocks of the entity under test. `lifecycle_cause` correctly lives in the host, not the vocabulary.
- **ARCH-PURPOSE — flag (I1, I2).** The shadow-sweep: `refusal.lua` is the source, and the consumers that still restate the model are `response_provider.failure_reason`'s pass-through branch, `generation_runner.fault`/`kill_scope`, the two non-literal warning channels, and `init.lua`'s `chat_context` wrapper. The deferred part is not a separable extension — "no raw token" *is* M5's purpose.
- **ARCH-MOCK — pass.** See test notes.
- **ARCH-CONSTRAINTS — pass.** `refuse()` calls `tasker.held()` unconditionally, but that is an in-memory scan plus a sort over live records (`tasker.lua:359-370`), on a path that already lost a response. `row_of`'s O(|TOKENS|) fallback runs only for unkeyed tokens. Nothing here is on a keystroke path.
- **ARCH-SECURE — pass, one note.** `detail.notice` carries the provider body capped at 500 chars (`chat_respond.lua:30`) and `issue()` caps at 4096 — bounded, and pre-existing. New: `dispatcher.lua:17` now honours `$PARLEY_QUERY_DIR` for staging request bodies (full prompt payloads). The env is the user's own so blast radius is unchanged in practice, but it is worth one sentence in `atlas/infra/test_harness.md` saying the override is harness-owned and production never sets it.
- **ARCH-ORDER — flag (I1), otherwise good progress.** BR-79's fix is the right shape: `cancel(batch,{cause})` validated inside `batch.transition` (`batch.lua:76-81`), cleared on resume (`:113`), read off the snapshot — and the host-side weak table and `leg_spoke` upvalue are gone. The remaining instance is the runner: `s.failure` / `s.diagnosis` / `s.cause` / `s.detached` / `s.terminal` are independent scalars carried across events whose legal combinations are unwritten, and `(failure = <Lua traceback>, diagnosis = nil)` is exactly the illegal-but-representable state I1 describes. `is_token` at the setter is the smallest thing that makes it unrepresentable.
- **ARCH-FUNERAL — flag (Minor).** The per-process query dir. Note also that this *replaced* a bounded artifact (the shared `query_dir` with its >200→100 prune) with an unbounded per-process one under the harness — the writer lost its bound when the reader gained isolation.

## 7. Plan revision recommendations

1. **`workshop/issues/000261-audit-transcript-recovery-state.md:913-916`** — BR-80 is **not-addressed**. Round 3 renumbered the plan's round-2 entry but left the issue Log's, which BR-80 named explicitly ("in both the issue Log and the plan"). At HEAD the Log still reads `BR-73` for the `one()` helper (ledger **BR-72**), `BR-74` for the outcome set (ledger **BR-73**), and `BR-70/72` for the file-scoped exemption (ledger **BR-70/74**). Correct in place; a disposition that quotes the wrong id cannot be verified by a later round. Fixing only the plan copy is the same instance-not-class move the family tracks.
2. **`workshop/plans/000261-transcript-is-the-whole-truth-plan.md:2589-2595`** — add a `## Revisions` entry retracting the claim that "`failure` is now always a token" and that "the leg's terminal hands its message to the batch as `result.refusal`". Neither holds: three producers still write free text to `failure` (I1), and `result.refusal` has no reader. State what is actually true — free text is routed at the four sites that were changed — and record the remaining enumeration as M5's outstanding work or an explicit follow-up.
3. **`atlas/chat/transcript_truth.md:88-94`** — the "Two nets" paragraph credits the harness watch with covering "what `describe` actually resolves, across every spec in the suite". True as written, but the page reads as a completeness guarantee; add the qualifier the round-2 revision applied to the static census — the watch sees the values the suite drives, and a producer no spec exercises is covered by neither net.

```findings
dispose:
  - id: BR-66
    disposition: addressed
    note: |
      The value-keyed inversion is built (describe returns a resolution; minimal_init.vim:59-79 fails the file via cquit) and the cache hazard is removed by construction via $PARLEY_QUERY_DIR rather than a runtime assert; all three named runner tokens now have rows. The residual gap — the watch only sees values a spec drives — is raised separately.
  - id: BR-72
    disposition: addressed
    note: |
      chat_refusal_spec.lua:78-86 — refusals_are uses assert.same on the whole list and one() delegates to it, so all 17 cases compare full messages, including the two-message batch case.
  - id: BR-75
    disposition: addressed
    note: |
      refusal.LIFECYCLE (refusal.lua:198-203) is consulted before the token lookup for every kind; response_target.lua:116's raw event.kind now resolves silent/reload, and chat_respond.lua:48-51 is the single detach-to-reload mapping used by both call sites.
  - id: BR-76
    disposition: addressed
    note: |
      tests/minimal_init.vim:3,26-32 and atlas/infra/test_harness.md:43-56 both now describe what spec_runner does and name the specs that set g:parley_test_mode themselves; grep over atlas/TOOLING/Makefile finds no surviving stale claim.
  - id: BR-77
    disposition: addressed
    note: |
      chat_respond.lua:1716 and :1188 go through refuse('paused'/'topic'), and refusal_vocabulary_spec.lua:138-152 keys on the channel. The guard's literal-only match is a new finding, not this one.
  - id: BR-78
    disposition: addressed
    note: |
      refusal_vocabulary_spec.lua:124-136 asserts NOT_REFUSAL is disjoint from TOKENS/INTERNAL/LIFECYCLE and that every entry is still produced by the scan; busy/refused/revoked/stale are gone from the allowlist.
  - id: BR-79
    disposition: addressed
    note: |
      batch.lua:76-81 validates the cause in the transition, :113 clears it on resume, snapshot copies it, and chat_respond.lua:2074 reads it off the model; user_stopped and leg_spoke no longer exist anywhere in lua/ or tests/.
  - id: BR-80
    disposition: not-addressed
    note: |
      The plan's round-2 entry was renumbered but the issue Log was not — at HEAD it still reads BR-73 for the one() helper (ledger BR-72), BR-74 for the outcome set (ledger BR-73), and BR-70/72 for the exemption (ledger BR-70/74).
findings:
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      `failure` still carries free text on three producers, so a cliproxy start failure and every `fault` reach the user as "unexpected (...)"
    detail: |
      Measured: describe("ended","provider_failed","cliproxy: proxy did not become healthy within 30s — try :ParleyProxy status") resolves `unkeyed`. Chain: cliproxy.ensure_running's on_error (cliproxy.lua:731,736,777) or vault.run_with_secret's (vault.lua:251,267) -> dispatcher.lua:926 abort_before_start -> D.query on_abort -> response_provider.lua:99 abort -> failure_reason's string branch (:21) passes any string verbatim -> cb.failed(reason) with no diagnosis -> s.failure -> chat_respond.lua:1781. generation_runner.lua:492 (fault) and :69 (kill_scope) assign a raw Lua error to s.failure, which generation_settles_spec.lua:228 pins, leaving the `fault` TOKENS row (refusal.lua:179) with zero reachable consumers. Neither net sees any of it: the census FILES list omits cliproxy.lua, vault.lua, response_completion.lua, response_preparation.lua and response_topic.lua, and no spec drives these paths through the host.
      This is the 12th finding in family enumeration-claims-completeness. Earlier rounds fixed instances. Do NOT fix these three sites. The rule: `failure` must hold a value `refusal` can resolve, enforced where the value is STORED, not where it is displayed — otherwise coverage of the invariant equals coverage of the specs, which is the syntax-vs-value mistake again. Export refusal.is_token(value) (a row, an INTERNAL entry, a ": " lead-in, or a LIFECYCLE key) and have generation_runner.issue route anything failing it into `diagnosis`, asserting under $PARLEY_TEST_MODE. fault, kill_scope and failure_reason are then covered by construction, and the FILES enumeration stops needing to be complete.
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      The channel guard matches only a string-literal first argument, so two live warning channels inside the file it scans are neither routed nor declared
    detail: |
      tests/arch/refusal_vocabulary_spec.lua:138-152 greps logger%.warning%(%s*(['"]) and vim%.notify%(%s*(['"]). A warning whose argument is a variable is invisible, and two are in chat_respond.lua, which is in CHANNEL_FILES: :437 logger.warning(plan.warning) — the attachment-budget notice, no prefix, no action; and :1364 _parley.logger.warning(label .. ' failed: ' .. tostring(err)) — the guarded() helper behind cancel_topic and stop_batch, so a throwing batch cancel prints a raw traceback on the Stop path. The test "routes every user notice in the submit path through refuse" therefore passes while asserting something untrue, and NOT_A_REFUSAL_NOTICE claims a completeness it does not have.
      Same rule as the finding above, applied to the channel: match on the CALL, not on its first token — scan logger.warning( / vim.notify( regardless of argument shape and require every site to be refuse()'s return or an explicitly declared non-refusal. Then route plan.warning and guarded through the vocabulary.
  - id: new
    severity: Minor
    family: returned-handle-has-no-consumer
    title: |
      Two handles added this round have no reader: the `_lifecycle_cause` test seam and `result.refusal`
    detail: |
      chat_respond.lua:52 exports M._lifecycle_cause labelled "-- test seam" with no test referencing it — the only one of the repo's five such exports without a consumer. result.refusal is written at chat_respond.lua:1754 and :1781 and read nowhere in lua/ or tests/, while the plan's round-3 revision claims the batch consumes it; the batch actually derives leg_stopped from generation.OUTCOMES[state.reason] at :2078.
      This is the 6th finding in family returned-handle-has-no-consumer. Do NOT fix the two sites — the rule is that an M._* export labelled a test seam, and a field added to a snapshot or result table, must have a reader in the same commit. A cheap arch assertion over "-- test seam" exports in lua/ would pin the first half permanently.
  - id: new
    severity: Minor
    family: canonical-form-not-shared
    title: |
      Six hand-written variants of "first line of a Lua error", three of which throw on an empty message
    detail: |
      tostring(x):match('^[^\n]+') appears at chat_respond.lua:1670, :1693, :1297, response_session.lua:95, :164; response_target.lua:113 uses :sub(1,512) instead. Only two carry the `or 'unknown'` fallback. Verified: debug.traceback("") begins with a newline, so the match returns nil and the three unguarded sites raise "attempt to concatenate a nil value" inside the failure handler itself.
      This is the 5th finding in family canonical-form-not-shared. Do NOT fix the individual sites — one helper (refusal.brief(err)) with the fallback and the cap built in, used by all six.
  - id: new
    severity: Minor
    family: canonical-form-not-shared
    title: |
      init.lua's chat_context wrapper still hand-words "not a chat" and the missing header for four commands
    detail: |
      init.lua:4294-4303 composes its own sentences ("Prune is only available in chat files: <raw reason>", "could not find header separator ---") for ChatPrune, ExchangeCut, ExchangePaste and NewQuestion, in a different voice and with no action, while refusal.lua now owns both facts and chat_respond.respond was converted to refuse('start', nil, 'not a chat'|'chat header unavailable'). Out of M5's declared submit-path scope, but it is the remaining hand-maintained restatement the ARCH-PURPOSE shadow-sweep asks for.
      This is the 6th finding in family canonical-form-not-shared. The rule: a condition the vocabulary keys has one wording for every entry point — give chat_context's reporting wrapper a refuse() kind rather than four sentences.
  - id: new
    severity: Minor
    family: untrusted-input-unparsed
    title: |
      lifecycle_cause maps detach to reload on a buffer number alone, and buffer numbers are reused after :bd
    detail: |
      chat_respond.lua:48-51 returns 'reload' whenever nvim_buf_is_valid(buf) and nvim_buf_is_loaded(buf), without checking the buffer is still the same chat. Buffer-number reuse after :bd is the hazard this issue's own audit named, so a closed chat whose number was taken by another file reports "the chat was reloaded while the answer was being written; submit again". The window is narrow (the terminal fires on the next deferred turn) and the fix is one comparison against D.get(buf) or the buffer name.
  - id: new
    severity: Minor
    family: residue-names-no-end
    title: |
      The per-process query directory the harness creates has no removal path, and replaced a bounded artifact
    detail: |
      tests/minimal_init.vim:56-58 creates $TMPDIR/parley-query-<pid> in every nvim process and nothing removes it; request bodies accumulate inside, one directory per spec file per run. `make test` is bounded by its leading test-clean-env, but `make test-spec`, `make test-changed` and the direct PlenaryBustedFile invocation TOOLING.md documents all leave them. Note also that this replaced an artifact with a writer-side bound (the shared query_dir's >200->100 prune) with an unbounded per-process one.
      This is the 3rd finding in family residue-names-no-end. The removal belongs beside the creation (a VimLeavePre delete of the directory), not in a target the operator must remember to run.
```
