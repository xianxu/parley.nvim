# Boundary Review — parley.nvim#242 (milestone M1)

| field | value |
|-------|-------|
| issue | 242 — Retrofit ARCH-MOCK to the chat providers: one stateful fake per provider at the curl seam, integration tests through it, and a live conformance check that re-records the fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000242-arch-mock-stateful-fake-per-chat-provider.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | a53472921f064c68ee2992246396794b593d01b9..ba0d3021074610bd8de5ad44097bc53c15bd8884 |
| command | sdlc milestone-close --issue 242 --milestone M1 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T07:43:38-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the dispatcher's ending-notice path to check whether S3's assertion reflects user-visible behavior.

Now running the new specs and checking how the suite invokes single files.

Specs are running; checking the new files' results specifically.

All 11 new cases pass. Now probing whether S6's byte-split actually reaches parley's reader as many chunks, or curl coalesces them.

Byte-splitting does reach the reader (79 reads vs 1), so S6 is real, though not asserted. Checking S7a's "partial kept" assertion strength.

I've finished the review. Writing up the verdict.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 mostly delivers what it promises. There is one shared dialect module (`sse_dialects.py`), with pure `anthropic`, `behaviour` and `split` functions behind a thin `fake_provider` shell built on `LoopbackHTTPServer`. Integration specs S1–S7b run the real dispatcher → curl → out_reader path with the transport left alone. There is also a standalone proof driver for #228 and #229 on their pre-fix parents. I ran the `providers/architecture` and `providers/anthropic` spec keys in the harness. All new cases pass (sse_dialects 3/3, provider_anthropic 8/8), and the orphan check reports "clean: no surviving test processes". I also probed S6 with a wrapper around `tasker.run`. With `--split every_byte` the reader gets 79 calls, against 1 with `none`, so the byte splitting really reaches parley.

Three cheap issues block a clean SHIP:
- **Task 2's unit spec is missing.** `tests/unit/fake_provider_spec.lua` was never written, and no plan revision drops it.
- **S3 checks an internal function.** It calls `_classify_ending` directly instead of checking the notice the user actually sees.
- **S7a's "partial kept" check can't fail.** It asserts that a field initialized to `""` is not nil.

**1. Strengths**
- **One source for the wire format.** The anthropic SSE bytes come from one pure function (`tests/fixtures/sse_dialects.py:40`). The unit spec decodes them with parley's real parsers and checks them event by event against `anthropic_stream.txt` (`tests/unit/sse_dialects_spec.lua:35-48`). That makes them faithful to real bytes by construction, not by assertion.
- **The fake picks its reply from the request, not a counter** (`sse_dialects.py:103-124`). S2 checks the second request parley actually sent, via the request log, including the first call's `tool_use_id` (`provider_anthropic_spec.lua:53-58`).
- **The proofs are built well.** `run_proofs.sh` uses scratch worktrees, an isolated HOME and XDG, `PROOF-REACHED` markers so a run that never gets there counts as inconclusive, and a trap that removes everything. It needs nothing from the new code on the old trees, which follows PQ-1 closely.
- **Test-process lifecycle comes for free.** The fake inherits parent-death exit, the fixture arch count was bumped (`tests/arch/fixture_lifecycle_spec.lua:87`), and the orphan check is clean.
- **Credentials:** only dummy secrets are used, and the request log is a per-case temp file deleted in `after_each` (PQ-4/PQ-5 honoured).

**2. Critical findings**
None.

**3. Important findings**
- **Missing Task 2 spec** (ARCH-PURPOSE, ARCH-PURE). The plan lists `tests/unit/fake_provider_spec.lua` with four checks:
  - a table of request shapes → reply kind for `behaviour`;
  - "the slices concatenate back to the input, for every mode" for `split`;
  - one curl per failure mode, checking status and body;
  - the request log appears only when its variable is set.

  None of these exist, so the pure core is tested only indirectly, through the integration cases. **Fix:** add the spec. `behaviour` and `split` can be tested without IO through `python3 -I`, the same way `sse_dialects_spec` already runs the module. Otherwise, add a Revisions entry saying why it was dropped.
- **S3 bypasses the path it claims to test** (`tests/integration/provider_anthropic_spec.lua:66`).
  - The test calls `dispatcher._classify_ending(out.qt)` itself, so it would still pass if the dispatcher stopped reporting the in-band error.
  - In fact the dispatcher *does* show it to the user. `_ending_notice` returns "answer is TRUNCATED … an error the provider sent in-band — Overloaded" at warning level (`lua/parley/dispatcher.lua:362-370`), and the dispatcher logs warnings unconditionally (`:856-863`).
  - So the Log's reason for the workaround ("logs error-level notices only for empty response") is misleading.
  - **Fix:** assert `any(out.warnings, "in-band — Overloaded")`, as S5 already does for the cap, and correct the plan's M1 revision note.
- **S7a's "partial answer kept" check is vacuous** (`provider_anthropic_spec.lua:101`). `qt.response` starts as `""` (`lua/parley/dispatcher.lua:479`), so `out.qt.response ~= nil` is always true. A 600-byte cut of the ok stream contains exactly the first delta. **Fix:** `assert.equals("Hello,", out.qt.response)`.

**4. Minor findings**
- **S6 doesn't assert that splitting reached the reader.** I measured 79 reads against 1, but nothing pins that, and the plan's Risk said to measure it in Task 2; no measurement is logged. Count reader calls and assert more than 1.
- **No input validation in the fake.**
  - `behaviour` silently falls back to plain text for any unknown mode.
  - `fake_provider` doesn't check `--mode` at startup, so a bad `http_<x>` raises inside the handler and curl just sees an empty reply.
  - Validate both in argparse.
- **Scope gaps against the plan:**
  - The plan's `--split frames` mode isn't implemented.
  - S4 covers only 429, not 529 or 500.
  - Decision 2's "missing stop reason" has a unit check only, with no integration case.
  - The `http_<status>_once` mode has no consumer.
- **Weak vocabulary entry.** `'"stop_reason"'` (`tests/helpers/provider_vocabulary.lua:11`) also matches `message_start`'s `"stop_reason":null`. Use `'"stop_reason":"end_turn"'` or a `message_delta`-scoped needle.
- **Leftover state in the helper.** `provider_scenarios.query` registers a dummy vault secret and may create a `D.providers[p]` entry, and doesn't undo either.
- **Duplicated route.** The route table appears in both `fake_provider:28` and `provider_scenarios.lua:12`.
- **Traceability placement.** `provider_anthropic_spec.lua` is filed under `providers/architecture` rather than `providers/anthropic`.
- **Proof port.** `proof_run.lua:20` picks a random port without checking it is free.
- **Docs.** No atlas prose covers the new test-fake surface, and the plan defers it to M3 Task 11. That is acceptable at M1, but it should not slip past M3. No README surface is involved.

**5. Test coverage notes**
- Covered and passing in the real path: S1, S2, S4 (including no retry), S5, S6 and S7b.
- S3 and S7a are weaker than their titles claim, as above.
- The regression proofs were not re-run in this review, because they need `construct/generated/vocabulary/*.json` and two scratch worktrees. Their design is sound, though:
  - the #229 old-tree check is "LOG COMPLETE", not the plan's "later chunks consumed";
  - `handled=` is printed but not asserted.

**6. Architectural notes for upcoming work**
| Principle | Result |
|---|---|
| ARCH-DRY | pass (one dialect module; only the small route/constant duplication above) |
| ARCH-PURE | pass for structure, but the missing Task 2 spec leaves the pure core without direct tests |
| ARCH-PURPOSE | flagged, see the Important findings |
| ARCH-MOCK | pass for M1: a real process-level fake behind the production endpoint seam. Live conformance is scheduled for M3, and the vocabulary list is already shared for it |
| ARCH-CONSTRAINTS | pass (the 5 s envelope is asserted in S6) |
| ARCH-SECURE | pass (dummy keys only, isolated HOME/XDG for the proofs, a temp request log) |
| ARCH-ORDER | pass: production state is untouched, the fake's only counter (`served`) is scoped to `_once`, and the reply is chosen from the request |
| ARCH-FUNERAL | pass: the request log is deleted in `after_each`, and the worktrees and temp dir are removed by an EXIT trap. A SIGKILL would leave a worktree registered; `git worktree prune` recovers it |

For M2: give `fake_cliproxy` the same `ROUTES`/dialect lookup instead of a third route table. Also make `behaviour` take the dialect, because its `_has_tool_result` check is anthropic-specific today.

**7. Plan revision recommendations**
- Either deliver `tests/unit/fake_provider_spec.lua`, or add a "## Revisions" entry recording that Task 2's unit spec was folded into the integration specs, and why.
- Correct the M1-build revision note: the in-band error with text *is* logged, as a "TRUNCATED … in-band" warning. Only error-level notices are limited to empty responses.
- Record that the `frames` split mode and the S4 529/500 variants are deferred, or implement them.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: plan-item-undelivered
    title: |
      Task 2's tests/unit/fake_provider_spec.lua (behaviour table, split invariant, per-mode shell, request-log gating) is not delivered
    detail: |
      The plan's Task 2 names this spec and its four checks. The file does not exist at head, and no Revisions entry drops it, so the pure behaviour and split functions (sse_dialects.py:103,127) have no direct test (ARCH-PURPOSE, ARCH-PURE). Add the spec (pure checks via python3 -I, as sse_dialects_spec already does) or record a revision.
  - id: new
    severity: Important
    kind: defect
    family: test-oracle-bypasses-path
    title: |
      S3 asserts dispatcher._classify_ending directly instead of the user-visible in-band notice the dispatch path emits
    detail: |
      provider_anthropic_spec.lua:66 re-runs the classifier on qt, so it passes even if the dispatcher drops the report. In fact _ending_notice returns a warning-level 'answer is TRUNCATED ... in-band — Overloaded' (dispatcher.lua:362-370) that the dispatcher logs (:856-863). Assert out.warnings contains 'in-band — Overloaded', as S5 does, and correct the Log/plan note that claims nothing is logged.
  - id: new
    severity: Important
    kind: defect
    family: vacuous-assertion
    title: |
      S7a's 'partial answer kept' assertion cannot fail: qt.response starts as an empty string, never nil
    detail: |
      provider_anthropic_spec.lua:101 checks out.qt.response ~= nil, but dispatcher.lua:479 initializes response to "". The 600-byte cut contains exactly the first delta, so assert.equals('Hello,', out.qt.response).
  - id: new
    severity: Minor
    kind: defect
    family: vacuous-assertion
    title: |
      S6 does not assert that the byte split reached the reader; the vocabulary entry '"stop_reason"' also matches message_start's null field
    detail: |
      A probe measured 79 reader calls with every_byte against 1 with none, but the spec pins nothing, so curl coalescing would make S6 vacuous without anyone noticing. Count reader calls and assert more than 1, and tighten the stop_reason needle.
  - id: new
    severity: Minor
    kind: defect
    family: unvalidated-fake-config
    title: |
      fake_provider accepts any --mode: unknown modes silently serve text, and a malformed http_ mode raises inside the handler
    detail: |
      Validate --mode and --split at argparse time, so a typo fails loudly at startup instead of producing a passing ok stream or an empty reply.
  - id: new
    severity: Minor
    kind: defect
    family: plan-item-undelivered
    title: |
      The plan's --split frames mode, S4's 529/500 variants and an integration no_stop case are not delivered or recorded as deferred
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"6061256b-84ce-4528-8579-08bde2bd6fb2","repository":"github.com/xianxu/parley.nvim","issue_id":"000242","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/634d322e8b7cda1d","reviewed_head":"ba0d3021074610bd8de5ad44097bc53c15bd8884","slot":"parley.nvim:4","requested_at":"2026-10-16T14:40:48.035655Z"},"phase":"finished","pid":9302,"started_at":"2026-10-16T14:40:48.188207Z","finished_at":"2026-10-16T14:43:35.481583Z","session_id":"0a2f26f5-caa1-4d9c-910a-7b14cd4c16cb","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T08:02:56-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 242 — Retrofit ARCH-MOCK to the chat providers: one stateful fake per provider at the curl seam, integration tests through it, and a live conformance check that re-records the fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000242-arch-mock-stateful-fake-per-chat-provider.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | a53472921f064c68ee2992246396794b593d01b9..19bd7c773bd92def62ad64f28922cb001f54bb41 |
| command | sdlc milestone-close --issue 242 --milestone M1 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T08:02:56-07:00 |
| verdict | REWORK |

## Review

Reviewing the M1 diff now; next I'll check the dispatcher fix in context and run the specs.

Running the new specs through the harness now.

All green (15 integration, 10 fake_provider, 4 sse_dialects). Now reverting the dispatcher fix to confirm the regression test goes red.

The dispatcher fix has a real regression test: reverting it turns the S7b frame-aligned case red. Next I'm running the #228/#229 regression proofs on their pre-fix trees.

Proofs pass 6/6 (pre-fix trees reproduce, branch fixed). Checking a few remaining items: vault secret handling and the Core-concepts classification.

```verdict
verdict: REWORK
confidence: medium
```

M1 delivers what it set out to do, and I checked each claim myself. The Anthropic dialect, `fake_provider` and the integration specs all run through the real `dispatcher → curl → out_reader` path. The specs pass under the harness: provider_anthropic 15/15, fake_provider 10/10, sse_dialects 4/4, and the rest of `providers/architecture` is green. `tests/regression/run_proofs.sh` passes 6/6: #228 and #229 reproduce on `dc548920^` and `634e33a9^` and are fixed on the branch. The production fix in `dispatcher.lua:646-662` has a real regression test. With the base `dispatcher.lua` restored, "S7b frame-aligned reads" goes red; with the fix back in, it is green. All seven prior findings are resolved. One thing blocks the boundary. The plan's Core-concepts table lists `provider_scenarios` as a PURE entity holding the scenario × provider table. In the code it is an IO driver: it spawns processes, mutates the dispatcher and logger, and waits on the event loop. The table itself doesn't exist. The review contract calls any table/code contradiction Critical, and M2 will be designed against this table. The fix is cheap: a plan revision, plus deciding where the scenario table lives before M2.

### 1. Strengths
- **The production fix is minimal and pinned.** `dispatcher.lua:651-661` takes each line off the buffer before processing it, and a reader that threw decodes nothing at EOF. With the fix reverted, `provider_anthropic_spec.lua:663` fails, which is the evidence a fix needs. The atlas entry (`atlas/chat/document.md:166-168`) and the lesson (`workshop/lessons.md:627-630`) record the class, not just the instance.
- **The regression proofs are honest.** `run_proofs.sh` runs each case on the pre-fix tree and on the branch. It needs a `PROOF-REACHED` marker before it reads any result, cleans up its worktrees with `trap`, and uses only APIs both trees have. I ran it: 6/6.
- **The fake's pure parts are kept apart from the server.** `behaviour`, `split` and `check_mode` are pure functions in `sse_dialects.py:315-381`. `fake_provider` is a thin shell over them. Bad modes and splits are refused at argparse time (`fake_provider:121-122`), and there's a test for it (`fake_provider_spec.lua:890`).
- **The oracles are exact.** S3 checks the warning the dispatcher actually logs (`:578`). S7a checks for `"Hello,"` exactly (`:649`). S6 shows the split reached the reader (`:612`). sse_dialects_spec decodes the fake's bytes with parley's own parsers and matches `anthropic_stream.txt` event for event (`:958`).
- **The S6 envelope is checked** with a 5 s timing assert (`:614`).

### 2. Critical findings
- **Core concepts: the `provider_scenarios` row doesn't match the code** (plan line 66; `tests/helpers/provider_scenarios.lua`).
  - The plan lists it under Pure entities as "ProviderScenario: the table of the scenarios × the providers… the integration specs iterate it, so adding a provider is one row".
  - The module is IO glue. It calls `fixture_process.spawn`, `ready_port.wait_listening` and `vim.wait`. It mutates `dispatcher.providers[p].endpoint`, `logger.error`/`logger.warning` and the vault, and it reads files.
  - It has no scenario table. The scenarios are hand-written `it(...)` blocks in `provider_anthropic_spec.lua`.
  - Fix:
    - Add a `## Revisions` entry that moves `provider_scenarios` to Integration points (the scenario driver).
    - State where the scenario table lives. Either build it as a data table now, so M2's openai/googleai rows are added as data, or say the scenarios are per-dialect spec cases. If you take the second option, change M2 Task 8 to match, because it currently creates separate spec files.
  - ARCH-PURE, ARCH-DRY: without a shared table, M2 will copy S1–S7 into two more spec files.

### 3. Important findings
None new.

### 4. Minor findings
- **ARCH-ORDER: the reader's state is now two loose booleans.** `out_reader` tracks `stdout_finished` and `threw` separately, so the unreachable `threw && stdout_finished` combination is representable. A small tagged state (`reading | threw | finished`) would make the legal states readable from the code.
- **ARCH-ORDER: the only regression test for the fix depends on timing.** It relies on `--split frames --write-delay-ms 20` making each frame its own curl read. A deterministic unit case in `dispatcher_query_spec` would remove the timing dependence: feed `"line\n"` to `out_reader` with a throwing handler, then send `(nil, nil)`, and assert one handler call.
- **`provider_scenarios.query` leaves state behind.** It may create `dispatcher.providers[p] = {}` and never removes it, and it never removes the dummy secret it adds. Both are in-memory and per-process, so this is harmless.
- **`proof_run.lua:700` picks its port with `math.random`** instead of a free-port probe, so it can collide on a busy host.
- **`"Hello, world! 👋"` is written out in three places:** `sse_dialects.py:222`, `provider_anthropic_spec.lua:522` and `sse_dialects_spec.lua:949`.

### 5. Test coverage notes
- Reverting `lua/parley/dispatcher.lua` to base fails exactly one case, "S7b frame-aligned reads". So the fix has a test that fails without it.
- `run_proofs.sh` checks for the fixed notice on the branch but doesn't check that "response is empty" is absent there. That is acceptable, because each tree's needle is checked separately.
- `fake_provider_spec` covers the behaviour table, the split invariant, the mode check, a curl per mode, a 404 for an unknown route, and the request-log gating.

### 6. Architectural notes for upcoming work
| Marker | Result | Notes |
|---|---|---|
| ARCH-DRY | pass, see Critical | One shared dialect module. Missing scenario table, see Critical. |
| ARCH-PURE | flag | The Core-concepts contradiction above. Otherwise the pure dialect functions are well separated. |
| ARCH-PURPOSE | pass for M1 | Anthropic only, as the milestones plan it. |
| ARCH-MOCK | pass for M1 | The fake sits behind the production curl seam. Live conformance is scheduled for M3. |
| ARCH-CONSTRAINTS | pass | The every_byte case is capped at 5 s and asserted. |
| ARCH-SECURE | pass | Dummy secrets are held in memory only. The request log holds bodies, not headers, so the key never reaches it. The proofs set `HOME`/`XDG_*` to temp directories. |
| ARCH-ORDER | minor | Ordering is controlled by the fake's `--split`/`--write-delay-ms`. See the Minor notes on the reader booleans and the timing-based test. |
| ARCH-FUNERAL | pass | The request log is deleted in `after_each`, fakes are reaped, and the proof worktrees are removed by `trap`. |

- **Docs:** the atlas covers the fix. The test-harness atlas pages are deferred to M3 Task 11 as planned. M1 adds nothing user-facing, so README is unaffected.

### 7. Plan revision recommendations
- Reclassify `provider_scenarios` as Integration (the scenario driver), and either deliver the ProviderScenario data table or record that scenarios are per-dialect spec cases. Make M2 Task 8 consistent with whichever you choose.
- Plan line 226 still says the in-band error "is observable as `dispatcher._classify_ending(qt)`, not as a logged notice". BR-3 showed that is wrong, and the issue Log has already struck it through. Correct the plan's Revisions entry to match.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      run_proofs.sh:764-767 uses cap_empty/inband_error_empty and checks the notice text on each tree; ran it, 6/6 ok.
  - id: BR-2
    disposition: addressed
    note: |
      tests/unit/fake_provider_spec.lua delivers the behaviour table, split invariant, check_mode, a curl per mode and request-log gating; 10/10 pass.
  - id: BR-3
    disposition: addressed
    note: |
      S3 now asserts the warning containing "in-band — Overloaded" (provider_anthropic_spec.lua:578); the issue Log is struck through, but plan.md:226 still carries the retracted claim (see plan revisions).
  - id: BR-4
    disposition: addressed
    note: |
      provider_anthropic_spec.lua:649 asserts equals("Hello,", out.qt.response); passes.
  - id: BR-5
    disposition: addressed
    note: |
      S6 asserts raw_at_first_chunk < the total raw bytes (:612); the vocabulary needle is now '"stop_reason":"end_turn"'.
  - id: BR-6
    disposition: addressed
    note: |
      check_mode/check_split are argparse types (fake_provider:121-122); fake_provider_spec.lua:890 asserts exit 2 for a typo.
  - id: BR-7
    disposition: addressed
    note: |
      The frames split (sse_dialects.py:368), S4 for 429/529/500 (:581) and the no_stop integration case (:636) are delivered and pass.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: core-concepts-table-drift
    title: |
      Core concepts lists provider_scenarios as a PURE scenario table; the code is an IO driver and no scenario table exists
    detail: |
      plan.md:66 and :79 describe a pure ProviderScenario table that the specs iterate, so adding a provider is one row. tests/helpers/provider_scenarios.lua spawns the fake, waits on uv, and mutates dispatcher.providers, logger and vault; it holds no table, and the scenarios are hand-written cases in provider_anthropic_spec.lua. Fix: a Revisions entry moving it to Integration points, and either build the data table before M2 or record per-dialect spec cases and align M2 Task 8 (ARCH-PURE, ARCH-DRY).
  - id: new
    severity: Minor
    kind: defect
    family: reader-state-flags
    title: |
      out_reader's reader state is two independent booleans, and the only test of the fix depends on write timing
    detail: |
      dispatcher.lua:531-532 tracks stdout_finished and threw separately (a tagged reading/threw/finished state would do). The regression test needs frames plus a 20 ms write delay to line up reads; a deterministic dispatcher_query_spec case (a line with a throwing handler, then EOF (nil,nil), expecting one handler call) would pin it without timing (ARCH-ORDER).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"677f09f1-15bc-4ff9-83a4-c8f5edd516c6","repository":"github.com/xianxu/parley.nvim","issue_id":"000242","recipe":"milestone-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f0854e826beaffeb","reviewed_head":"19bd7c773bd92def62ad64f28922cb001f54bb41","slot":"parley.nvim:4","requested_at":"2026-10-16T15:00:02.413673Z"},"phase":"finished","pid":1801,"started_at":"2026-10-16T15:00:02.5775Z","finished_at":"2026-10-16T15:02:55.221242Z","session_id":"4d04a54f-448d-4144-bd6c-9e2756031514","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T09:53:47-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 242 — Retrofit ARCH-MOCK to the chat providers: one stateful fake per provider at the curl seam, integration tests through it, and a live conformance check that re-records the fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000242-arch-mock-stateful-fake-per-chat-provider.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 76f1d090df46997ef8df56041640248d86383872..54aad52d508e15795c80c98dd1087af24049a056 |
| command | sdlc milestone-close --issue 242 --milestone M1 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T09:53:47-07:00 |
| verdict | SHIP |

## Review

I'm running the new specs and reverting the reader fix to check that A6–A8 go red.

Both halves of the reader fix are pinned. Now checking what the "threw" state does to the EOF path (finish_stdout).

```verdict
verdict: SHIP
confidence: high
```

Both open findings are fixed, and the fixes are backed by tests I ran. BR-8: `tests/helpers/provider_scenario_table.lua` now holds the scenario rows, the per-provider profiles and a pure judge (`mismatches`). The integration spec loops over profiles × rows. The plan's Core concepts table now lists `provider_scenarios` as the IO driver under Integration points. BR-9: the reader's two booleans are now one `reader_state` value (`reading` / `threw` / `finished`). Three new tests, A6–A8, pin the fix with no timing involved. I reverted the fix in the disposable checkout three ways, and each time a test failed:
- **Full revert to the base `dispatcher.lua`:** A6 and A8 fail.
- **Remove only the `threw` guard:** A7 and A8 fail.
- **Restore only the old order (decode the line before removing it from the buffer):** A6 and A8 fail.

All the specs this range adds or changes pass at head: dispatcher_query 74, provider_scenario_table 3, fake_provider 10, sse_dialects 4, provider_scenarios integration 15, fixture_lifecycle 4. The dispatcher spec prints "Error detected while processing command line" on the base tree as well, so this range didn't cause it. Nothing blocks SHIP. Two Minor notes follow.

1. **Strengths**
   - `provider_scenario_table.lua:105` `mismatches` is a real pure judge. Its unit spec checks that a matching outcome passes and also that each expectation rejects the outcome that breaks it, so the oracle itself is tested.
   - `provider_scenarios.run` is the only IO driver, and it never branches on a provider name. M2 adds profiles, not new spec files (plan Task 8 now says so).
   - `dispatcher.lua:655-662`: each line comes off the buffer before it is decoded, and the `threw` mark is set around the decode. One small, readable change fixes the duplicate delta, and A6–A8 cover each half separately.
   - Clean-up is handled: the request log uses a per-test temp file deleted in `after_each`, the fake is reaped with `fixture_process.reap`, and only dummy secrets are used.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `dispatcher.lua:645-648`: once the reader is in `threw`, EOF never calls `finish_stdout`. On the base tree it did, so after a throw `qt.usage`, `qt.stop_reason`, `tasker.set_cache_metrics` and `empty_response` are no longer recorded. The attempt has already failed with `stdout reader failed`, and the terminal closure only reads those fields on the success path, so I see no visible effect. But it is a behaviour change nobody wrote down, and no test pins it either way. Either add one sentence to the atlas paragraph or call `finish_stdout(qt)` from the `threw` branch when EOF arrives (`chunk == nil`).
   - Plan Task 3, `plan.md:142-143`: the Files list still says `provider_scenarios.lua` holds "the scenario table and a `drive(provider, mode)`" and still creates `provider_anthropic_spec.lua`. The round-2 Revisions entry supersedes this, but Task 8's list got an inline strike-through and Task 3's did not.

5. **Test coverage notes**
   - A6–A8 are deterministic and each fails without its half of the fix.
   - The integration row `S7b/frames` still uses a 20 ms write delay. It is now extra coverage on top of A6–A8, not the only test of the fix, so that's fine.
   - S6's 1 ms pacing is a test-side fix for flakiness, and the plan records it.

6. **Architectural notes**
   - **ARCH-DRY: pass.** There is one driver, one judge and one vocabulary list.
   - **ARCH-PURE: pass.** The table and judge are tested without IO. Profile functions only transform data.
   - **ARCH-PURPOSE: pass for M1.** Anthropic runs end to end through the real `dispatcher → curl → out_reader` path. The other providers are planned M2 profiles, not deferred purpose.
   - **ARCH-MOCK: pass.** Production and tests share the same seam: the configured endpoint plus the real transport. Live conformance is M3 Task 9.
   - **ARCH-CONSTRAINTS: pass.** S6 checks the PQ-7 limit (`within_ms = 5000`).
   - **ARCH-SECURE: pass.** Only dummy secrets are used, the tests run with an isolated HOME and TMPDIR, and the fake rejects unknown modes (BR-6, already disposed).
   - **ARCH-ORDER: pass.** The reader's state is one tagged value, and ordering is controlled by calling `captured_out_reader` directly. The `finish_stdout` skip above is the one transition left unwritten.
   - **ARCH-FUNERAL: pass.** The request log and fake process are cleaned up per test, and `run_proofs.sh` worktrees are scratch.
   - For M2, keep profiles as data plus pure transforms. Copilot's token route should go in its profile, not become a branch in `run`.

7. **Plan revision recommendations**
   - Strike through Task 3's stale Files bullets (`plan.md:142-143`) and point them to the round-2 revision, the same way Task 8 does.

```findings
dispose:
  - id: BR-8
    disposition: addressed
    note: |
      provider_scenario_table.lua holds ROWS/PROFILES/rows_for/mismatches (pure, unit-tested in provider_scenario_table_spec); provider_scenarios_spec iterates profiles x rows; plan Core concepts moves provider_scenarios to Integration points and Task 8 adds profiles. 15/15 integration cases pass.
  - id: BR-9
    disposition: addressed
    note: |
      dispatcher.lua uses a single tagged reader_state; A6-A8 are timing-free. Reverted in checkout: full revert fails A6+A8, dropping threw guard fails A7+A8, old ordering fails A6+A8.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: undocumented-behavior-change
    title: |
      After a reader throws, EOF no longer runs finish_stdout, so usage/stop_reason/cache metrics go unrecorded
    detail: |
      dispatcher.lua:645-648: the threw branch consumes EOF (nil,nil) and skips finish_stdout, which the base tree ran. The failure path does not read these fields today, but no test or atlas text states it. Either document it or call finish_stdout from the threw branch when chunk is nil.
  - id: new
    severity: Minor
    kind: defect
    family: plan-text-stale-after-revision
    title: |
      Plan Task 3 Files list still names provider_anthropic_spec.lua and a drive() in provider_scenarios.lua
    detail: |
      plan.md:142-143 contradicts the round-2 Revisions entry. Strike through those bullets the way Task 8's list was struck, pointing to the revision.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"0c105810-ed61-4eb9-846b-00134cb14708","repository":"github.com/xianxu/parley.nvim","issue_id":"000242","recipe":"milestone-review","round":4,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/1d34eb75364e6675","reviewed_head":"54aad52d508e15795c80c98dd1087af24049a056","slot":"parley.nvim:4","requested_at":"2026-10-16T16:50:49.525292Z"},"phase":"finished","pid":44316,"started_at":"2026-10-16T16:50:49.949954Z","finished_at":"2026-10-16T16:53:46.064219Z","session_id":"cf903fdd-11ca-40b7-91a2-85c9a62ad556","outcome":"returned"}] -->
