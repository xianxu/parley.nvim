# Boundary Review — parley.nvim#261 (whole-issue close)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | whole-issue close |
| milestone | — |
| window | ff5ed804a7d58499a2964235f9897db53f2c85d3..ba79d86f9d090db9ee5abd52c3353dd8c9619cfb |
| command | sdlc close --issue 261 |
| reviewer | claude |
| timestamp | 2026-09-19T16:03:40-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The issue delivers a great deal of real work — the on-disk recovery store is gone, processes die for certain, every wait a generation holds settles, and the refusal vocabulary is a genuinely pure phrasebook with a load-time assertion tying it to the generation machine's outcome set. But the boundary cannot be crossed as it stands: **the suite is red at HEAD**, and the failures are all caused by the close commit itself. `make test-integration` fails three specs (`cliproxy_caller_teardown_spec.lua:161`, `response_session_spec.lua:186`, `tests/arch/single_source_sweeps_spec.lua`); all three pass at the parent commit `6b8c7164`, and I reproduced each and bisected the responsible hunk. Worse, the milestone's headline fix — routing a non-token `failure` into `diagnosis`, "the one that took four rounds" — has **no test that fails without it**: I reverted the `is_token` guard in a scratch worktree and `chat_refusal_spec` 17/17, `refusal_spec` 15/15, `refusal_vocabulary_spec` 6/6, `generation_settles_spec` 19/19, `chat_respond_spec` 42/42 and `batch_lifecycle_spec` 8/8 all stayed green, while the two specs that *do* observe the change are exactly the two now failing. The plan's own counterfactual row for it is measurably false. Lint is clean (0/644), `document_semantic_spec` (20/20) and `response_tools_spec` (83/83) pass alone and are the known #267 silent-death family, not regressions.

## 1. Strengths

- **The BR-81 remedy's *shape* is right.** `generation_runner.lua:158-166` enforces the invariant where the value is **stored**, not where it is rendered, so `fault`, `kill_scope` and every adapter string are covered by construction instead of by a FILES list someone must keep complete. Only the evidence is missing, not the idea.
- **`refusal.lua:350-353` fails at `require` time** if `generation.OUTCOMES` gains an outcome with no words. A vocabulary that cannot silently fall behind its producer is the right kind of coupling.
- **`tests/arch/spawn_seam_spec.lua` derives each out-of-seam spawn's class from its own call form** (`sync`/`bounded`/`delegated`/`open`), requires a `why` iff `open > 0`, and *rejects a `why` that has gone dead. That is the correct answer to BR-46 — prose replaced by a computed classification.
- **`tests/arch/sidecar_authority_spec.lua:22-33` selects readers by where the file lives** (state_dir **or** `stdpath('data')`), which is the property that defines the class, and `file_access.json` now carries a schema, an exercise and a `table_to_file` write.
- **`helper.lua:597-720`** preserves a symlinked destination and its mode across the atomic rename and sweeps its own crash leftovers, with `helper_io_spec` F3g/F3h/F3i pinning all three and three production call sites for `remove_stale_temps`.
- **`tasker_supervision_spec`** pins the pid-0 guard against a fake that *raises* if it is ever signalled, and pins that a held record keeps no deadline handle — counterfactual-grade tests for two unreachable-today hazards.

## 2. Critical findings

**C1 — `generation_runner.issue`'s new routing breaks two specs, and nothing fails without it.**
`lua/parley/generation_runner.lua:158-166`. Reverting only the `is_token`/`brief` lines in a worktree at `ba79d86f` turns both failures green and leaves every refusal spec green:

- `tests/integration/cliproxy_caller_teardown_spec.lua:161` — `assert.equals("test abort", generation.failure)` → got `nil`.
- `tests/integration/response_session_spec.lua:186` — `assert.equals('forced preparation failure', generation.failure)` → got `nil`.

Fix sketch: both assertions should move to `generation.diagnosis` (as `generation_settles_spec.lua:228` already did), **and** a case must exist that goes red when the routing is removed — drive a free-text producer through the real session and assert the user's message names the outcome rather than the raw sentence.

## 3. Important findings

**I1 — the plan's counterfactual table trips the repo's own Core-concepts guard.**
`workshop/plans/000261-transcript-is-the-whole-truth-plan.md:2700`. The row `` | `issue` keeps free text in `failure` | the reload cases in `chat_refusal_spec` | `` matches `single_source_sweeps_spec.lua:282`'s row shape (`^| \``), so the guard demands a *definition* of the symbol `chat_refusal_spec` and finds none. Two fixes, either works: write the cell as the path `` `tests/integration/chat_refusal_spec.lua` `` so the module-strip applies, or scope the guard's row matcher to Core-concepts tables rather than any table whose first cell is a backtick.

**I2 — `chat_respond.lua:448` leaks `describe`'s second return value into `logger.warning`'s `sensitive` parameter, and names the wrong kind.**
`logger.warning(Refusal.describe('start', nil, 'attachments dropped: ' .. plan.warning))` forwards both returns. `logger.warning(msg, sensitive)` → `logger.lua:73-86`: the log line becomes `[SENSITIVE DATA] REDACTED` (default `store_sensitive = false`) and is excluded from `_log_history`. Reproduced:

```
WARNING: [SENSITIVE DATA] REDACTED                      -- logger.warning(R.describe(...))
WARNING: Response not started: the chat's text alone …   -- logger.warning((R.describe(...)))
```

`build_messages_spec.lua:2068` captures only argument 1, so it cannot see this. Second defect on the same line: the kind is `start`, but the response *does* start — only images are dropped — so the user reads "Response not started: … no images were sent". Fix: parenthesise (or assign to a local) and give the attachment notice a kind that describes what happened.

## 4. Minor findings

- `lua/parley/chat_respond.lua:48-50` duplicates the comment paragraph at `:44-47` — including the clause "One statement of it, for every path" — added by `ba79d86f`. Delete the second copy.
- `lua/parley/helper.lua:696-699` still hand-rolls `resolve(fnamemodify(x, ':p'))`; no `helper.canonical_path` exists anywhere in `lua/` (BR-34, re-raised below as a disposition).
- `refusal.is_token` and `refusal.brief` are new public functions with zero test references anywhere in `tests/`.

## 5. Test coverage notes

- **Unit:** 214 pass, `document_semantic_spec` dies under parallel load (20/20 alone, ×1) — #267 family.
- **Integration + arch:** 167 pass, 2 real assertion failures (C1), 1 real arch failure (I1), `response_tools_spec` dies under parallel load (83/83 alone) — #267 family.
- **Untested behavior changes shipped in the close commit:** the `is_token` routing (C1), `lifecycle_cause`'s buffer-reuse guard (reverting it leaves `chat_refusal_spec` 17/17 — verified), `refusal.brief`'s empty-message fallback, and `init.lua`'s four rewritten command refusals.
- **Verified counterfactual that does work:** planting `_parley.logger.warning(x)` with a variable argument in `chat_respond.lua` turns `refusal_vocabulary_spec`'s channel test red. The BR-82 guard is genuine.

## 6. Architectural notes

- **ARCH-DRY — flag (minor).** `brief()` correctly collapsed six copies of "first line of a Lua error", but path canonicalisation still has ~11 hand-rolled copies (BR-34), and the close commit added a duplicated comment paragraph at `chat_respond.lua:48-50`.
- **ARCH-PURE — pass.** `refusal.lua` is data plus two pure functions; `describe` returns the message and lets the caller log it. `_failure_notice` stays pure and exported.
- **ARCH-PURPOSE — flag.** The shadow-sweep for "`failure` holds only a token" enumerated production producers but not the *consumers in tests* that assert the old contract — which is how C1 shipped. The sweep for a stored-value invariant must include every reader of that field, specs included.
- **ARCH-MOCK — pass.** `fake_process` models groups and pid signals behind `tasker._uv`, and `process_group_conformance_spec.lua` checks the model against the real kernel.
- **ARCH-CONSTRAINTS — pass.** Deadlines are `tasker.deadline` kinds (guarded against numeric literals), TERM→KILL escalation is bounded, staging budgets are explicit.
- **ARCH-SECURE — pass.** Sidecars are parsed into typed values at the boundary; `spawn_seam_spec` forbids `curl -v`/`--trace` argv. I2 is the inverse direction (a non-secret wrongly redacted), not a leak.
- **ARCH-ORDER — pass.** The batch's pause cause lives in the transition (`batch.lua:76-81`), cleared on resume, copied into the snapshot; the runner's outcome set is declared and checked.
- **ARCH-FUNERAL — pass.** `remove_stale_temps` at three call sites, the one-shot deadline timer closing as it fires, and the harness's `VimLeavePre` delete (measured: one leftover directory out of ~380 spec processes, from the spec that died abnormally).

## 7. Plan revision recommendations

- **`## Revisions` — the counterfactual is false.** Plan line 2700 claims reverting `issue`'s free-text routing reddens "the reload cases in `chat_refusal_spec`". Measured: `chat_refusal_spec` 17/17, `refusal_spec` 15/15, `refusal_vocabulary_spec` 6/6, `generation_settles_spec` 19/19, `chat_respond_spec` 42/42, `batch_lifecycle_spec` 8/8 all green with the guard reverted; the only specs that move are the two this commit broke. Record the real counterfactual once the test exists.
- **`## Revisions` — a superseded claim.** Plan line 2395 still says the leg "hands its message to the batch as `result.refusal`", which the round-4 revision at 2672-2675 deleted. The batch derives `leg_stopped` from `generation.OUTCOMES[state.reason]` at `chat_respond.lua:2093`.
- **Issue `## Log`** — the round-2 dispositions are still recorded one ledger id off (lines 914-917: `BR-73`→BR-72, `BR-74`→BR-73, `BR-70/72`→BR-70/74).

```findings
dispose:
  - id: BR-20
    disposition: addressed
    note: |
      One BEARER_SCHEMA (vault.lua:161) applied to both the file read (:184) and the network response (:229); vault_spec V1 pins a non-numeric expires_at.
  - id: BR-23
    disposition: addressed
    note: |
      helper.lua:622-660 resolves the real target and copies its mode; remove_stale_temps has three call sites; helper_io_spec F3g/F3h/F3i pin symlink, mode and sweep.
  - id: BR-24
    disposition: addressed
    note: |
      sidecar_authority_spec.lua:22-33 selects on state_dir OR stdpath('data'); file_access.json is in sidecars.lua with a schema, an exercise and a table_to_file write.
  - id: BR-34
    disposition: not-addressed
    note: |
      helper.lua:696-699 still hand-rolls resolve(fnamemodify(n,':p')); no helper.canonical_path exists anywhere in lua/, and file_refresh.lua:6 still has its own copy.
  - id: BR-36
    disposition: addressed
    note: |
      nodiscard_spec now matches statement heads after then/do/else/; and bare pcall/xpcall, and its header lists the four forms it cannot see.
  - id: BR-37
    disposition: addressed
    note: |
      The stale check asserts seen == declared.count for every DROPPED entry and reports "declared N, found M".
  - id: BR-41
    disposition: addressed
    note: |
      chat_respond.lua:1088-1090 merges and only defaults deadline_ms when unscoped and unset; topic_gen_spec:76-80 pins partial, bare and scoped opts.
  - id: BR-43
    disposition: addressed
    note: |
      tasker.lua:219 refuses pid <= 0; tasker_supervision_spec "never signals a record whose pid is 0" drives it against a fake that raises if signalled.
  - id: BR-44
    disposition: addressed
    note: |
      tasker.lua:596-598 closes the one-shot timer as it fires; "keeps no deadline handle on a record the kernel holds" pins it.
  - id: BR-45
    disposition: addressed
    note: |
      dispatcher.lua:764-770 exports only failure.exit; response_provider.lua:18 and chat_respond.lua:21-28 both read it, and spawn_seam_spec's FIELDS guard fails any read of failure.code/signal/io_error.
  - id: BR-46
    disposition: addressed
    note: |
      spawn_seam_spec classifies each out-of-seam spawn from its call form and requires `why` iff open > 0, failing a dead `why` too.
  - id: BR-61
    disposition: addressed
    note: |
      dispatcher.lua:883-885 states the two-arg contract and that copilot now forwards it; cliproxy-managed.md:261-263 names the transport_alive precondition; the pre_query guard scans lua/ and tests/.
  - id: BR-64
    disposition: addressed
    note: |
      The plan now carries a per-hunk mutation ledger (five rows), and each named case exists in response_topic_spec.lua:90-115.
  - id: BR-80
    disposition: not-addressed
    note: |
      The issue Log at lines 914-917 still reads BR-73 for the one() helper (ledger BR-72), BR-74 for the outcome set (ledger BR-73), and BR-70/72 for the exemption (ledger BR-70/74).
  - id: BR-81
    disposition: not-addressed
    note: |
      The routing exists at generation_runner.lua:158-166, but reverting it in a worktree leaves chat_refusal_spec 17/17, refusal_spec 15/15, refusal_vocabulary_spec 6/6, generation_settles_spec 19/19, chat_respond_spec 42/42 and batch_lifecycle_spec 8/8 all green; the only specs that observe it are the two it now breaks. No test fails without the fix.
  - id: BR-82
    disposition: addressed
    note: |
      The guard keys on the call, not its first token; planting _parley.logger.warning(x) with a variable argument in chat_respond.lua turns "routes every user notice in the submit path through refuse" red (reproduced).
  - id: BR-83
    disposition: addressed
    note: |
      M._lifecycle_cause and result.refusal are both deleted, and single_source_sweeps_spec now fails any "-- test seam" export with no reader.
  - id: BR-84
    disposition: not-addressed
    note: |
      refusal.brief exists and all six sites route through it, but grep over tests/ finds zero references to brief (or is_token); the crash the finding named — debug.traceback("") with its leading newline — is pinned by nothing.
  - id: BR-85
    disposition: not-addressed
    note: |
      The wording is shared now, but the wrapper reuses the `start` kind and passes the command name as `notice`, so ExchangeCut in a headerless buffer reads "Response not started: the chat has no header; edit: restore the chat's header, then submit again — ExchangeCut" (rendered). No refuse() kind was added and no test covers the four commands.
  - id: BR-86
    disposition: not-addressed
    note: |
      The not_chat check is in place at chat_respond.lua:56-60, but reverting it to the old two-condition form leaves chat_refusal_spec 17/17 green (verified); the close case uses an unloaded buffer, which both versions treat the same. No test enters the reused-number branch.
  - id: BR-87
    disposition: addressed
    note: |
      tests/minimal_init.vim:50-56 deletes the directory on VimLeavePre beside its creation; after a full run the HEAD tree left one directory out of ~380 spec processes, from the spec that died abnormally.
findings:
  - id: new
    severity: Critical
    family: seam-change-collateral
    title: |
      The close commit's `failure`-routing change reddens two specs at HEAD, and nothing fails without it
    detail: |
      This is the 10th finding in family `seam-change-collateral`. Do NOT fix the two
      assertions alone. generation_runner.lua:158-166 changed what the `failure` field
      may hold; the sweep covered production producers but not the readers of that
      field in tests/. Measured at HEAD: cliproxy_caller_teardown_spec.lua:161 expects
      'test abort' and gets nil; response_session_spec.lua:186 expects 'forced
      preparation failure' and gets nil. Both pass at 6b8c7164, and both go green again
      when only the is_token/brief lines are reverted — while chat_refusal_spec 17/17,
      refusal_spec 15/15, refusal_vocabulary_spec 6/6, generation_settles_spec 19/19,
      chat_respond_spec 42/42 and batch_lifecycle_spec 8/8 stay green either way. The
      rule: a change to what a STORED field may hold enumerates every reader of that
      field, production and spec alike, and the round that lands it adds the case that
      goes red when the guard is removed. Move the two assertions to
      `generation.diagnosis` and add that case.
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      The plan's new counterfactual table trips the repo's own Core-concepts symbol guard, so tests/arch/single_source_sweeps_spec.lua is red at HEAD
    detail: |
      This is the 14th finding in family `enumeration-claims-completeness`. Do NOT just
      rename the cell. single_source_sweeps_spec.lua:282 selects rows by shape
      (`^| \``) rather than by the table they belong to, so the mutation-ledger row at
      plan:2700 — `| \`issue\` keeps free text in \`failure\` | the reload cases in
      \`chat_refusal_spec\` |` — is judged a Core-concepts row and its spec name is
      demanded as a symbol definition. The guard passed at 6b8c7164 and fails at HEAD.
      Either scope the row matcher to Core-concepts tables (the property that defines
      the class) or write the cell as a path so the existing module-strip applies.
  - id: new
    severity: Important
    family: seam-change-collateral
    title: |
      `logger.warning(Refusal.describe(...))` forwards the resolution string into the `sensitive` parameter, so the attachment notice is logged as REDACTED
    detail: |
      This is the 11th finding in family `seam-change-collateral`. Do NOT fix only this
      line. `describe` gained a second return value in M5 round 3; chat_respond.lua:448
      calls it as the last argument of logger.warning(msg, sensitive), so "keyed" lands
      in `sensitive` and logger.lua:73-86 writes "[SENSITIVE DATA] REDACTED" to the log
      and keeps the line out of _log_history (reproduced; the parenthesised form logs
      correctly). The channel guard added in the same commit explicitly blesses the
      form `^Refusal%.describe%(` as routed, so it cannot see this. The rule: a
      multi-return function is never called directly as another call's last argument —
      assign it, or parenthesise it — and the channel guard should require the
      parenthesised/assigned form rather than the bare call. Same line: the kind is
      `start`, but the response does start (only images are dropped), so the user reads
      "Response not started: … no images were sent".
  - id: new
    severity: Minor
    family: comment-outlives-its-behavior
    title: |
      chat_respond.lua:48-50 duplicates the comment paragraph at :44-47, including its "One statement of it" clause
    detail: |
      Introduced by ba79d86f: the new paragraph was appended rather than replacing the
      old one, so the same two sentences appear twice above lifecycle_cause, the second
      copy differing only in "a chat still loaded by then". Delete :48-50.
```

---

## Re-review — 2026-09-19T16:38:32-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | whole-issue close |
| milestone | — |
| window | ff5ed804a7d58499a2964235f9897db53f2c85d3..c0479441e7c14f38b17dde7ab14dd26c81db6bb0 |
| command | sdlc close --issue 261 |
| reviewer | claude |
| timestamp | 2026-09-19T16:38:32-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 1's blockers are genuinely closed and I verified each by measurement, not by reading the commit message: the suite is green at HEAD (lint 0/644, unit 214 pass, integration+arch pass — the two files that failed the parallel run, `packaging_launcher_spec` and `perf_ownership_spec`, both pass alone and are untouched by this diff, the known #267 load family); the two specs that read the changed `failure` field now read `generation.diagnosis`; the `is_token` routing finally has a counterfactual — I reverted it in a scratch worktree and `chat_refusal_spec` goes red with exactly the message the finding predicted (`Response stopped: unexpected (cliproxy: …)`); reverting the `describe` assignment reddens the channel guard; and the narrowed Core-concepts row selector still catches a symbol I planted that exists nowhere. What keeps this from SHIP is that BR-81's own rule — "`failure` must hold a value `refusal` can resolve, enforced where the value is STORED" — was implemented at one of the two seams that supply it. `generation_runner.issue` is gated; `chat_respond.refuse`'s `failure` argument is not, and I found a live value (`preparation outside captured output`) that reaches it and renders as `Response not started: unexpected (…)` with no action — the exact defect class four rounds chased, on the path the fix did not cover. Both new findings are cheap.

## 1. Strengths

- **The BR-81 remedy is now evidenced, not asserted.** `tests/integration/chat_refusal_spec.lua:252-262` drives cliproxy's health sentence through a real provider abort and asserts the *whole* message with the sentence as detail. Reverting only the `is_token`/`brief` lines turns that case red and leaves the other 17 green — measured. That is the counterfactual two rounds asked for.
- **The channel guard was tightened in the right direction.** Dropping the `^Refusal%.describe%(` bless from `tests/arch/refusal_vocabulary_spec.lua:157,164` means the guard now refuses the very form that caused BR-90, rather than blessing it. Reverting `chat_respond.lua:445-449` to the bare call reddens it — measured. All three `describe` call sites in `lua/` assign first.
- **The Core-concepts row selector now keys on the property that defines the class.** `single_source_sweeps_spec.lua:277-286` selects rows by the table's `Status` header instead of by row shape, and it still inspects 22 rows across 2 tables on this branch — I planted `M_totally_invented_symbol` in the Pure-entities table and it was caught.
- **`refusal.lua` is genuinely pure.** It loads and renders under `nvim -u NONE` with no `setup()`, no IO, no state; the `unkeyed` watch lives in `tests/minimal_init.vim`, not in production (BR-71's rule held through this round).
- **Deleted surface left no dangling references.** `answer_recovery`, `chat_recovery`, `response_recovery`, `recovery_paths`, `traversal_policy`, `fake_recovery_filesystem` and `atlas/chat/recovery.md` appear nowhere in `atlas/`, `README.md`, `lua/`, `tests/`, `scripts/` or `workshop/lessons.md`; `atlas/index.md` links every atlas file.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `refuse()`'s `failure` argument bypasses the store-level `is_token` gate, and a live non-token reaches it.**
`lua/parley/chat_respond.lua:59-66` and `:1770`. `generation_runner.lua:158-166` states "a producer that hands over a sentence…can never reach a user raw" — true only for producers routed through `issue`. `chat_respond.refuse` is the other supply point and has no gate: eleven of its call sites pass a *variable* as `failure`. One is confirmed live: `response_submission.lua:50` calls `cancelled(s,'preparation outside captured output')` → `reject` → `response_session.lua:233` `rejected` → `chat_respond.lua:1770` `refuse('start','start refused', why)`. Rendered: `Response not started: unexpected (preparation outside captured output); the details are in the Parley log` — no action, which is what the issue's own Done-when forbids. Neither net sees it: `refusal_vocabulary_spec`'s FORMS do not match the `cancelled(s, '…')` call shape, and the harness watch only fires when a spec drives the value (none does — the suite is green). Fix sketch: gate in `refuse` the way `issue` does — non-token `failure` becomes `detail.notice`, and assert under `$PARLEY_TEST_MODE`.

**I2 — the atlas page and the target both still describe a two-net world; the store-level enforcement that closed BR-81 is in neither.**
`atlas/chat/transcript_truth.md:86` and `workshop/targets/transcript-is-the-whole-truth.md:271` each say "Two nets keep a refusal from reaching a user as a bare token" and list the authoring-time census and the harness watch — the two mechanisms whose completeness equals spec coverage, which is precisely what BR-81 rejected. Both files were last touched at `a9b20b22`; `is_token`/`brief` landed at `ba79d86f`. A reader learning where to add the guarantee for a new producer is sent to the two weaker nets and not to `generation_runner.issue`. Docs gate: atlas update missing for the surface the plan's own Core-concepts table lists as new.

## 4. Minor findings

- `lua/parley/generation_runner.lua:165`: `Refusal.brief(reason):sub(1,4096)` — `brief` already caps at 512, so the outer cap is dead; and `brief` (documented as "the first line of a Lua error") is now applied to every diagnosis, so a multi-line provider message silently loses lines 2+.
- `tests/arch/single_source_sweeps_spec.lua:277`: the narrowed selector can match zero rows and still assert `{}` offenders. The same file asserts non-vacuity twice (`count >= 100` at :106, `sites >= 4` at :170) and states the rule at :243-244; the new selector did not adopt it. Latent today (22 rows), live the first time a plan's header spells the column differently.
- No test asserts the new `attachments` prefix. `build_messages_spec.lua:2077` matches only the embedded byte count, so "Images not sent: …" is unpinned wording.
- The rendered attachment notice repeats itself: `Images not sent: … so no images were sent (retained text alone is N bytes; 3 images not sent); …`.

## 5. Test coverage notes

- Lint 0 warnings / 0 errors in 644 files. Unit: all pass (including `document_semantic_spec`, which flaked in round 1). Integration + arch: all pass except two load-sensitive files that pass alone and are outside the diff.
- Counterfactuals I ran myself, each confirmed red: the `is_token` routing → `chat_refusal_spec`; the bare `describe(` call → `refusal_vocabulary_spec`; a planted absent symbol in a Core-concepts table → `single_source_sweeps_spec`.
- Still unpinned behavior in this window: `refusal.brief`'s `or "unknown"` fallback (zero references to `brief` or `is_token` anywhere in `tests/`), `lifecycle_cause`'s buffer-reuse guard, and the four `init.lua` command refusals — see the dispositions for BR-84, BR-85, BR-86.

## 6. Architectural notes

- **ARCH-DRY — flag (Minor).** `brief()` correctly collapsed six copies of "first line of a Lua error". Path canonicalisation still has ten hand-rolled `resolve(fnamemodify(x,':p'))` copies and no `helper.canonical_path` (BR-34, re-raised as a disposition).
- **ARCH-PURE — pass.** Verified by loading `parley.refusal` under `-u NONE`: data plus two pure functions, no IO, no state. The `unkeyed` watch is harness-side.
- **ARCH-PURPOSE — flag (I1).** The shadow-sweep for "a value the vocabulary must resolve" enumerated the runner's store and stopped there; `refuse()` is the second store and was left to the shape-based census. The instance was fixed; the class was not.
- **ARCH-MOCK — pass.** `fake_process` models groups and pid signals behind `tasker._uv`; `process_group_conformance_spec` checks the model against the real kernel.
- **ARCH-CONSTRAINTS — pass.** Deadlines are `tasker.deadline` kinds, TERM→KILL escalation bounded, `diagnosis` bounded at 512 (see the Minor about the redundant 4096).
- **ARCH-SECURE — pass.** BR-90's redaction inversion is closed and every `describe` call site assigns; sidecars parse into typed values at the boundary; `spawn_seam_spec` forbids `curl -v`/`--trace` argv.
- **ARCH-ORDER — pass.** `failure` and `diagnosis` are now distinct fields with `issue` setting exactly one per call; `(token, detail)` is a meaningful combination the renderer uses, not an undefined one.
- **ARCH-FUNERAL — pass.** `$PARLEY_QUERY_DIR` is deleted on `VimLeavePre` beside its creation; `remove_stale_temps` has three call sites.

## 7. Plan revision recommendations

- **`## Revisions` — the Core-concepts row for `is_token`/`brief` overstates its reach.** The row reads "producers use them so `failure` never holds free text". True of producers routed through `generation_runner.issue`; false of the eleven `refuse()` sites that pass `failure` directly. Restate the scope, or widen the implementation (I1) and leave the row as written.
- **`## Revisions` — the counterfactual table now has a true row.** Plan line 2700's claim about "the reload cases in `chat_refusal_spec`" was corrected in the close-round-1 entry; the entry at 2704-2747 should record the measured counterfactual (the new free-text case at `chat_refusal_spec.lua:252`) as the row rather than leaving the superseded line above it.

```findings
dispose:
  - id: BR-34
    disposition: not-addressed
    note: |
      No helper.canonical_path anywhere in lua/; helper.lua:696-698 and nine other sites still hand-roll resolve(fnamemodify(x,':p')).
  - id: BR-80
    disposition: addressed
    note: |
      Issue Log lines 911-917 now read BR-72 (one() helper), BR-73 (outcome set), BR-70/74 (file-scoped exemption), matching the ledger; the plan's round-2 entry at 2543-2554 already used those ids.
  - id: BR-81
    disposition: addressed
    note: |
      generation_runner.lua:158-166 gates the store, and chat_refusal_spec.lua:252-262 goes red when only the is_token/brief lines are reverted (measured in a scratch worktree); the other 17 cases stay green. The residual ungated seam is raised as a new finding, not this one.
  - id: BR-84
    disposition: not-addressed
    note: |
      brief() exists and seven sites route through it, but grep over tests/ finds zero references to brief or is_token; the newline-leading fallback the finding named is still pinned by nothing.
  - id: BR-85
    disposition: not-addressed
    note: |
      init.lua:4302 still passes kind "start" with the command name as notice. Rendered at HEAD: "Response not started: the chat has no header; edit: restore the chat's header, then submit again — ExchangeCut". No refuse() kind added, no test for the four commands.
  - id: BR-86
    disposition: not-addressed
    note: |
      The not_chat check is in place at chat_respond.lua:56, but chat_refusal_spec's 18 cases contain no :bd / buffer-number-reuse case; nothing in this round's commit touches it.
  - id: BR-88
    disposition: addressed
    note: |
      cliproxy_caller_teardown_spec.lua:161-164 and response_session_spec.lua:186-188 now assert generation.diagnosis with failure nil; full integration run green at HEAD, and the new free-text case reddens when the routing is reverted.
  - id: BR-89
    disposition: addressed
    note: |
      single_source_sweeps_spec.lua:277-286 scopes rows to a table whose header carries Status; the spec is green at HEAD and still catches a symbol I planted in the Pure-entities table that exists nowhere in the tree.
  - id: BR-90
    disposition: addressed
    note: |
      chat_respond.lua:445-449 assigns describe's result first; PREFIX gained "attachments" = "Images not sent"; the channel guard no longer blesses the bare call and goes red when the bare form is restored (measured). All three describe call sites in lua/ assign.
  - id: BR-91
    disposition: addressed
    note: |
      The duplicated paragraph is gone; chat_respond.lua:44-52 carries one statement of the reload/detach rule plus the buffer-reuse paragraph.
findings:
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      `refuse()`'s `failure` argument bypasses the store-level is_token gate, and a live non-token reaches a user as "unexpected (...)"
    detail: |
      This is the 15th finding in family `enumeration-claims-completeness`. Do NOT
      fix the one value. BR-81's rule was "enforced where the value is STORED"; the
      round gated ONE store (generation_runner.lua:158-166) and left the other —
      chat_respond.refuse (chat_respond.lua:59-66), whose `failure` argument is a
      variable at eleven call sites. Measured live instance:
      response_submission.lua:50 `cancelled(s,'preparation outside captured
      output')` -> reject -> response_session.lua:233 rejected ->
      chat_respond.lua:1770 `refuse('start','start refused', why)`, which
      `describe` resolves `unkeyed` and renders as "Response not started:
      unexpected (preparation outside captured output); the details are in the
      Parley log" — no action, which the issue's Done-when forbids.
      refusal_vocabulary_spec's FORMS do not match the `cancelled(s, '...')` call
      shape, and the harness watch only fires when a spec drives the value, so
      coverage of the invariant is again coverage of the specs. The rule: EVERY
      seam that supplies `failure` gates it by value, not one of them — give
      `refuse` the same `is_token` routing (non-token -> detail.notice, assert
      under $PARLEY_TEST_MODE), and correct the comment at
      generation_runner.lua:159-162 which claims a raw value "can never" reach a
      user.
  - id: new
    severity: Important
    family: comment-outlives-its-behavior
    title: |
      The atlas page and the target both still say "Two nets" and omit the store-level enforcement that closed BR-81
    detail: |
      This is the 4th finding in family `comment-outlives-its-behavior`. Do NOT fix
      only the sentence. atlas/chat/transcript_truth.md:86 and
      workshop/targets/transcript-is-the-whole-truth.md:271 each enumerate two
      mechanisms — the authoring-time census and the harness watch — whose
      completeness equals spec coverage, which is exactly what BR-81 rejected. Both
      files were last written at a9b20b22; `is_token`/`brief` and the routing landed
      at ba79d86f, and the plan's Core-concepts table lists them as new PURE
      surface. A reader sent to those two nets will add the next producer's guard in
      the wrong place. The rule the family keeps re-finding: a doc that ENUMERATES
      the mechanisms behind an invariant is a consumer of that invariant and is
      swept in the same commit that changes the set — neither atlas/ nor
      workshop/targets/ is inside superseded_comment_spec's file globs
      (lua/**, tests/**, scripts/**), so nothing mechanical will ever catch this
      class there.
  - id: new
    severity: Minor
    family: enumeration-claims-completeness
    title: |
      The narrowed Core-concepts row selector can match zero rows and still assert no offenders
    detail: |
      This is the 16th finding in family `enumeration-claims-completeness`. Do NOT
      add a one-off count to this test. single_source_sweeps_spec.lua:277 now gates
      rows on a header matching `|%s*Status%s*|`; a plan whose table spells the
      column differently silently gets zero coverage. The same FILE already states
      the rule twice ("finds the literals, so it cannot pass vacuously", :104-107;
      `sites >= 4`, :170) and writes it out in prose at :243-244. The rule: every
      selection-based guard in tests/arch asserts a non-zero selection count before
      asserting an empty offender list — sweep the file's guards for the ones that
      do not, rather than patching this one. Latent today: it inspects 22 rows
      across 2 tables on this branch (measured).
  - id: new
    severity: Minor
    family: rule-statement-scope-drift
    title: |
      `brief` is documented as "the first line of a Lua error" but now truncates every diagnosis, and its 4096 cap is dead
    detail: |
      This is the 2nd finding in family `rule-statement-scope-drift`. refusal.lua:268-273
      documents and bounds brief() for Lua errors (512 chars, first line);
      generation_runner.lua:165 applies it to every value routed to `diagnosis`,
      including provider prose such as cliproxy_auth.diagnosis, so a multi-line
      message loses everything after line 1 and the trailing action it carries. The
      `:sub(1,4096)` after it is dead, since brief already caps at 512. The rule:
      when a helper's callers widen beyond the case its doc-comment names, the
      doc-comment and the bound move with them — or the helper gets a second entry
      point for the wider case.
```

---

## Re-review — 2026-09-19T17:25:10-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | whole-issue close |
| milestone | — |
| window | ff5ed804a7d58499a2964235f9897db53f2c85d3..f636d24183046550916bf8754dbdba5e286b09c8 |
| command | sdlc close --issue 261 |
| reviewer | claude |
| timestamp | 2026-09-19T17:25:10-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Both blocking findings from round 23 are genuinely closed, each with a counterfactual I measured rather than took on faith: reverting the by-value gate in `refusal.describe` reddens `tests/unit/refusal_spec.lua:87`, and removing `brief`'s `or "unknown"` fallback reddens `tests/unit/refusal_spec.lua:100`. `make lint` is clean (0/0 across 644 files); `make test-integration JOBS=4` is fully green; the only red I could produce is the documented #267 silent-death-under-load family (`document_semantic_spec` at JOBS=4, plus `perf_ownership_spec` and `highlight_typing_spec` at JOBS=8 — all three pass alone, measured 20/20, 3/3 and 8/8). Nothing blocks SHIP. What remains is six Minors: three carried unaddressed for a second consecutive round (BR-34, BR-85, BR-86) and three new ones, all in the surface this round added — the new `stray` value is not integrated into `describe`'s existing notice precedence, `M.KIND`'s eleven `what` strings restate `M.PREFIX` verbatim, and the `brief`→`prose` routing at `generation_runner.lua:168` reddens nothing when reverted (measured across five specs).

### 1. Strengths

- **The BR-92 fix generalises rather than enumerating.** Moving the gate from "every seam that stores `failure`" to the one place the value is *read* (`lua/parley/refusal.lua:325-327`) is a strictly better answer than the finding asked for — eleven call sites inherit it instead of each repeating it, and the `unkeyed` resolution still escapes to the harness watch so the developer signal survives. `generation_runner.lua:159-163`'s comment was corrected in the same commit rather than left claiming "can never".
- **The counterfactual discipline held this round.** `tests/unit/refusal_spec.lua:87-96` asserts the *whole message*, not a substring, so the revert fails on the exact rendered sentence. `tests/integration/chat_refusal_spec.lua:247-262` drives a real provider abort with a free-text sentence end-to-end.
- **BR-94 was fixed at the selection, not the site.** Putting `assert.is_true(#out > 0, …)` inside `repo_files` (`tests/arch/single_source_sweeps_spec.lua:21`) makes every corpus guard in the file inherit the non-vacuity check; the two genuinely narrowed selections got their own counts (`:349`, `:436`). The routed-spec guard at `:796` already handled its empty case with `pending`.
- **BR-93's sweep found both consumers and no third.** `atlas/chat/transcript_truth.md:87-101` and `workshop/targets/transcript-is-the-whole-truth.md:271-277` now name the code as the guarantee and demote the two nets to developer signal; grepping `atlas/`, `workshop/targets/`, `README.md` and `docs/` turns up no other enumeration of that mechanism set.
- **Docs gate is satisfied for the window.** `atlas/chat/recovery.md` deleted with its last reader, `atlas/index.md` and `README.md:79-81` swept in the same range, and the new `atlas/chat/transcript_truth.md` is linked from the index.

### 2. Critical findings

None.

### 3. Important findings

None.

### 4. Minor findings

- `refusal.lua:327` — `notice = detail.notice or stray` discards the unworded reason whenever a notice is already present; `chat_respond.lua:2097` always supplies one (`answered()` at `:2062` never returns nil). Latent today, but it contradicts `atlas/chat/transcript_truth.md:88-90`, which states the demotion unconditionally.
- `refusal.lua:226-238` — all eleven `M.KIND[k].what` strings restate `M.PREFIX[k]`, so every floor message is a tautology: *"Response not started: the response could not start; submit again"*.
- `generation_runner.lua:168` — the `brief`→`prose` routing reddens nothing when reverted (measured: `chat_refusal_spec`, `generation_settles_spec`, `cliproxy_caller_teardown_spec`, `response_session_spec`, `refusal_spec` all stay green).
- Carried, second round unaddressed: BR-34 (no `helper.canonical_path`; `helper.lua:698` still hand-rolls the 11th copy), BR-85 (`init.lua:4294-4306` still renders *"Response not started"* for `:ParleyChatPrune`/`ExchangeCut`/`ExchangePaste`/`NewQuestion`), BR-86 (the buffer-reuse guard at `chat_respond.lua:53-58` has no test — the `_lifecycle_cause` seam was removed with BR-83, so nothing can reach it directly either).

### 5. Test coverage notes

- `refusal_spec` is now the strongest guard in the diff: whole-message equality plus a `for kind in pairs(R.PREFIX)` loop that would catch a new prefix shipped without a floor.
- The gap is at the *seam*, not the helper: `prose` and `brief` are unit-tested, but nothing drives a genuinely multi-line value through `generation_runner.issue` into a user-visible message. Note also that BR-95's premise was partly overstated — every branch of `cliproxy_auth.diagnosis` (`cliproxy_auth.lua:271-300`) returns a single line, so the live multi-line case is a provider body, not the cliproxy health sentence.
- `spec_runner.lua` now passes `minimal_init` to every child, which means `g:parley_test_mode` reaches specs for the first time. Only `file_tracker.lua:11` reads it, and both places that need the real path (`file_tracker_spec`, `tests/helpers/sidecars.lua:110-114`, correctly `pcall`-guarded) handle it — but this silently disabled file-tracker IO in every other spec child. Worth one line in `atlas/infra/test_harness.md` if it isn't there.

### 6. Architectural notes

Working each marker at its at-review lens:

- **ARCH-DRY — flag.** `M.KIND` duplicates `M.PREFIX` (finding below).
- **ARCH-PURE — pass.** The gate landed in the pure vocabulary module and returns its verdict as a value; the eleven IO seams were not touched. This is the correct side of the boundary and is why the fix was one diff instead of eleven.
- **ARCH-PURPOSE — partial.** The shadow-sweep over the refusal single source still leaves exactly one hand-maintained restatement: `init.lua`'s `chat_context` wrapper (BR-85, now unaddressed for a third round). Everything else derives.
- **ARCH-MOCK — pass.** No new external dependency this round; the stateful process fake and `process_group_conformance_spec` landed in M3 and are untouched.
- **ARCH-CONSTRAINTS — pass, with a note.** `issue()` now bounds its two fields differently — `diagnosis` at 512 via `prose`, `failure` at 4096 — on the same line. Neither is hot-path; the asymmetry is just unexplained.
- **ARCH-SECURE — pass.** Producer free text is folded and bounded before it reaches a user-facing line; no credential enters the new paths.
- **ARCH-ORDER — pass.** `describe` is a pure function of its arguments; this round adds no state carried between events.
- **ARCH-FUNERAL — pass.** No new durable artifact; `PARLEY_QUERY_DIR`'s removal sits beside its creation (`tests/minimal_init.vim:52-55`).

### 7. Plan revision recommendations

- If the `M.KIND` finding is taken, `workshop/plans/000261-transcript-is-the-whole-truth-plan.md:73` needs its wording updated with the collapsed table.
- Add a `## Revisions` line recording the measured fact that `generation_runner.issue`'s `prose` routing has no counterfactual — the close-round-2 entry at `:2748-2781` presents it as a completed Minor without saying so.

```findings
dispose:
  - id: BR-34
    disposition: not-addressed
    note: |
      No helper.canonical_path in lua/; helper.lua:698 and nine other sites still hand-roll resolve(fnamemodify(x,':p')); neither close-round commit touches it.
  - id: BR-84
    disposition: addressed
    note: |
      Zero hand-written first-line variants remain in lua/ (only refusal.lua:291); removing brief's `or "unknown"` in a scratch copy of f636d241 reddens refusal_spec.lua:100 (measured).
  - id: BR-85
    disposition: not-addressed
    note: |
      init.lua is in neither close-round commit; :ParleyChatPrune still renders "Response not started: the chat has no header; … — Prune", and no test covers the four commands.
  - id: BR-86
    disposition: not-addressed
    note: |
      The guard at chat_respond.lua:53-58 stands, but there is still no :bd / buffer-reuse case in chat_refusal_spec and no _lifecycle_cause seam to reach it directly; nothing in this round touches it.
  - id: BR-92
    disposition: addressed
    note: |
      Gate moved to the read point (refusal.lua:325-327) plus the M.KIND floor; reverting those two lines in a scratch copy of f636d241 reddens refusal_spec.lua:87 (measured), and generation_runner.lua:159-163's "can never" comment is corrected.
  - id: BR-93
    disposition: addressed
    note: |
      atlas/chat/transcript_truth.md:87-101 and workshop/targets/transcript-is-the-whole-truth.md:271-277 now name the by-value gate as the guarantee; a grep of atlas/, workshop/targets/, README.md and docs/ finds no third consumer still enumerating the two nets.
  - id: BR-94
    disposition: addressed
    note: |
      repo_files itself now fails on an empty corpus (single_source_sweeps_spec.lua:21), so every guard in the file inherits it; the two narrowed selections count rows (:349) and seams (:436), and the routed-spec guard already used `pending`.
  - id: BR-95
    disposition: addressed
    note: |
      prose() added with its own doc and bound; brief()'s doc is scoped to Lua errors and all five remaining callers are pcall errors; the dead :sub(1,4096) is gone from the diagnosis branch. The missing counterfactual for the routing is raised separately.
findings:
  - id: new
    severity: Minor
    family: fallback-order-hides-known-cause
    title: |
      describe's new `stray` loses to detail.notice, so the by-value gate drops the very reason it demoted
    detail: |
      This is the 2nd finding in family `fallback-order-hides-known-cause`. Do NOT
      fix the one line — state the rule. BR-68 was the same shape: a precedence
      test inside `describe` (`failure == nil` gating REVOKED) silently discarded
      the more specific fact. refusal.lua:327 repeats it: `notice = detail.notice
      or stray`, so when a caller already supplies a notice the unworded reason
      is dropped from the message AND from the log line `refuse` writes, and the
      user is left with only the KIND floor. chat_respond.lua:2097 is the live
      selector — `answered(state)` (chat_respond.lua:2062) is unconditional, so
      every `batch_paused` refusal carries a notice; today every batch reason is
      keyed, which makes it latent, but a by-value gate exists precisely because
      that enumeration is not trusted. The mirror symptom sits at refusal.lua:364,
      which suppresses a row's `extra` on `detail.notice` only, so a stray notice
      yields the two details BR-65 forbade. The atlas states the demotion
      unconditionally (atlas/chat/transcript_truth.md:88-90) and the target at
      :271-274 does too, so the docs are wrong on this path as well. The rule: a
      gate that demotes a value must PLACE it, never compete with an existing
      field for one slot — when two details arrive, join them in a defined order
      and run the `extra`-suppression off the joined value, not off `detail.notice`.
  - id: new
    severity: Minor
    family: canonical-form-not-shared
    title: |
      All eleven M.KIND `what` strings restate M.PREFIX, so every floor message is a tautology
    detail: |
      This is the 7th finding in family `canonical-form-not-shared`. Do NOT reword
      the eleven rows. refusal.lua:226-238 adds a second hand-maintained table
      whose `what` field is refusal.lua:12-24's `prefix` in clause form for every
      single key — start/"the response could not start", ended/"the response
      stopped", attachments/"the images were not sent", and eight more. The
      rendered result is "Response not started: the response could not start;
      submit again — <reason>", which says the same thing twice before it says
      anything useful. The only information KIND adds is `action`. The test at
      tests/unit/refusal_spec.lua:88-92 asserts a KIND row EXISTS for each PREFIX
      key but never that the two differ, so nothing catches the restatement or a
      future drift between them. The rule: one fact, one wording — a per-kind
      table carries only what the existing per-kind table does not. Fold KIND into
      PREFIX as `{prefix = …, action = …}` (or keep it as KIND_ACTION) and render
      `prefix .. ": " .. (detail.action or action)`, which also removes the
      two-tables-to-keep-in-sync obligation the presence-only test cannot enforce.
  - id: new
    severity: Minor
    family: behavior-change-without-regression-test
    title: |
      The brief-to-prose routing at generation_runner.lua:168 reddens nothing when reverted
    detail: |
      This is the 7th finding in family `behavior-change-without-regression-test`.
      Do NOT just add one case here. Measured in a scratch copy of f636d241:
      restoring `s.diagnosis=Refusal.brief(reason):sub(1,4096)` leaves
      chat_refusal_spec, generation_settles_spec, cliproxy_caller_teardown_spec,
      response_session_spec and refusal_spec all GREEN. prose() and brief() are
      unit-tested at refusal.lua's door (refusal_spec.lua:100-105), but no test
      drives a multi-line value through `issue` into a user-visible message, so
      the behavior the change exists for is unpinned. This is the same LINE that
      BR-88 was raised about one round earlier, for the same reason — which is the
      point: the rule is not "each finding gets a counterfactual", it is "each
      CHANGED ROUTING gets one, including the ones the fix round introduces".
      Apply it as a checklist step on the fix commit itself: for every line of the
      round's own diff that changes where a value goes, revert it and name the
      spec that reddens, or add one. (Note also that BR-95's cited example was
      wrong: every branch of cliproxy_auth.diagnosis at cliproxy_auth.lua:271-300
      returns a single line, so the live multi-line case is a provider body.)
```
