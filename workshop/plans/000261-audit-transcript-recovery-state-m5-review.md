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
