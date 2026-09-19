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
