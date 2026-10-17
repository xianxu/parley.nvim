# Boundary Review — parley.nvim#359 (whole-issue close)

| field | value |
|-------|-------|
| issue | 359 — Asynchronous rename protocol for agentic documents (BufFilePre/BufFilePost preflights) |
| repo | parley.nvim |
| issue file | workshop/issues/000359-asynchronous-rename-protocol-for-agentic-documents-buffilepre-buffilepost-preflights.md |
| boundary | whole-issue close |
| milestone | — |
| window | 630f6aac732056d390a4a21d77f4c668abda8900..656611a6c5a13a9e734f1a47ab9e94fdd7257dbc |
| command | sdlc close --issue 359 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T19:22:59-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the #359 diff: I've read the Lua source changes and the move callers, and next I'll check the tests and run the specs.

Running the changed specs now to check the tests.

All changed specs pass. Next I'll revert the `record_write` call to confirm a test catches its removal.

Revert confirmed: removing `record_write` makes the owned-move "Couch unavailable" case fail, and the file is restored. Last, a quick look at the unit spec.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The branch does what #359 set out to do. No move or rename of an agentic document waits on Couch any more, except a `:saveas!` onto an existing file, which keeps its bounded wait. When a move refuses, nothing has moved and the answer is fetched in the background. Once the file has moved, Couch's metadata rename is carried by the existing journal. I ran the whole `modes/session_sync` spec group (15+ files, including all five changed spec files) at the pinned head and every test passed. I also reverted the `record_write` call and confirmed the owned-move test "moves on a held identity while Couch is unavailable" goes red without it, then restored it. Three Important findings remain, all cheap to fix:
- A tree move of several documents parley doesn't know yet takes one rerun per document, not the single rerun the issue promises.
- An in-memory "Couch said absent" answer never expires, so a long-gone answer can still approve a plain move.
- The overwrite decision is made inline in `BufFilePost` and never through `move_preflight`, so that function's overwrite branch is never used in production.

None of these is Critical.

### 1. Strengths
- `move_preflight` and `move_outcome` (`lua/parley/document_move_plan.lua:556-603`) are genuinely pure and table-driven. Their unit tests pin the exact operator text, including shell quoting of the NEW path for the forget command (ARCH-PURE pass).
- `record_write` (`lua/parley/document_move.lua:497`) closes a real gap the plan hadn't foreseen: a save made while the rename is out used to make the journal impossible to recover. It is tested, and the revert confirms the test catches its removal.
- `document_move.begin` and `project` accept `"authority"` narrowly. Any other value, such as `'maybe'`, is still refused, and that is tested (`tests/unit/document_move_plan_spec.lua`).
- The row 6 integration test runs the whole path end to end: a stale registration, the band text, the notification carrying the full pasteable command, a real `forget`, and a reopen that finishes the journal.
- Each test asserts the editor returned in under 500 ms while the fake registry is slow (`FAKE_COUCH_REGISTRY_DELAY`). That pins the purpose of the issue, not just the mechanics.

### 2. Critical findings
None.

### 3. Important findings
- **A tree move needs one rerun per unknown document** (`lua/parley/init.lua:3887-3890` together with `agentic_document.lua:604-623`; ARCH-PURPOSE). The membership pre-pass returns at the first `nil`, so only that file's background lookup starts. A tree with N ordinary documents of unknown identity takes N+1 runs, against the issue's "the operator sees one recovery action". **Fix:** have the pre-pass call `move_membership` on every file, which starts every lookup, and only then return the first refusal. Add a two-file tree test.
- **The background "absent" memo never expires** (`agentic_document.lua:127, 139, 160`; ARCH-ORDER: "an observation is … not permanent authority"). `answered[slot] = true` is only ever cleared when that slot later comes back registered. So a lookup from hours ago still makes an unloaded file count as plain. If an agent has registered it since, the plain move leaves that registration orphaned at OLD. Unloaded files get no recheck, so this is wider than the risk the TL accepted for row 2 ("plain at open"). **Fix:** use the answer once (clear it when `known_identity` returns `"plain"` from it), or stamp it and expire it after the submit deadline.
- **The overwrite decision bypasses `move_preflight`** (`agentic_document.lua:829-843`; ARCH-DRY, plan drift). The plan says each of the three entry points, including `BufFilePost`, decides through `move_preflight`. In fact `BufFilePost` checks `filereadable` and calls `bounded_request` inline, and no caller ever passes `new_exists` or `overwrite`. The `wait_destination` branch is therefore dead in production and only exercised by unit tests. **Fix:** route `BufFilePost`'s overwrite check through `move_preflight({identity=…, new_exists=…, overwrite=…})`, or delete that branch and record a Revision.

### 4. Minor findings
- The result of `record_write` is ignored in `BufWritePost` (`agentic_document.lua:873`). If `persist` fails, the journal silently keeps a stale witness, and the reopen that rows 6 and 7 rely on will fail. It should notify.
- Background requests from `ask_in_background` are never cancelled on detach, although the plan's ARCH-FUNERAL section says they are. Their callbacks are guarded, so this is safe. The `answered` table also grows by one entry per path for the life of the session (ARCH-FUNERAL).
- The move state now lives in a growing set of flags on `moving`: `answered`, `overdue`, `pending_error`, `error`, `journal_pending`, `metadata_done`. Their legal combinations aren't written down anywhere. `move_outcome` projects views from them, but the state itself has no transition function (ARCH-ORDER).
- A registration from the `known.json` cache is now enough to let a move proceed. If that cache entry is stale (the document was forgotten in Couch), the result is row 7, and reopening may just replay the same refused rename (ARCH-SECURE: a persisted cache trusted as identity).
- Task 5 still has two unchecked items: the full `sdlc local-check run --name suite` and `sdlc close`.

### 5. Test coverage notes
- Every table row has an integration test. Row 8 is covered by the second half of the row 9 test.
- The tree-move rerun count (first finding) and the expiry of a stale "absent" answer (second finding) are not tested.
- The slow fake registry plus timing assertions is a good pattern. Still, each test sees only one ordering. Nothing injects a save arriving during the deadline timer and before the reply, beyond the one row 7 case.

### 6. Architectural notes
- ARCH-DRY: flag, the overwrite decision (above). `config_ms` was moved, not duplicated.
- ARCH-PURE: pass.
- ARCH-PURPOSE: flag, the tree reruns.
- ARCH-MOCK: pass. Tests run against the stateful fake registry, which has a conformance script.
- ARCH-CONSTRAINTS: pass. The UI path no longer blocks, and that is measured at under 500 ms.
- ARCH-SECURE: minor, the trusted cache.
- ARCH-ORDER: flag, the memo that never expires and the flag constellation.
- ARCH-FUNERAL: minor, the in-memory tables and the cancellation the plan claims but the code doesn't do.
- For upcoming work: folding `moving`'s flags into an explicit move state with its own transition function would let `move_outcome` derive its view from that state rather than from loose flags.

### 7. Plan revision recommendations
- Either `BufFilePost` decides the overwrite through `move_preflight`, or a Revision should say it decides inline and that `wait_destination` is unused.
- ARCH-FUNERAL: say plainly that background lookups are not cancelled on detach (their callbacks are guarded), and state the lifetime of the `answered` memo.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: one-recovery-action
    title: |
      Tree move pre-pass stops at the first unknown identity, so N unknown documents need N+1 reruns
    detail: |
      init.lua:3887-3890 returns on the first nil from move_membership, so only that file's background lookup starts. The issue promises one recovery action. Fix: call move_membership on every file first, then return the first refusal, and add a two-file tree test.
  - id: new
    severity: Important
    kind: defect
    family: stale-observation-authority
    title: |
      The background "absent" memo (answered) never expires and authorizes plain moves indefinitely
    detail: |
      agentic_document.lua:127/139/160 is only cleared when that slot later registers. An agent registering the file later is never seen for unloaded files (no recheck), so a plain move orphans the registration. Fix: use the answer once, or expire it at a deadline.
  - id: new
    severity: Important
    kind: defect
    family: single-decision-table
    title: |
      BufFilePost decides the :saveas! overwrite inline; move_preflight's wait_destination branch is dead in production
    detail: |
      The plan says all three entry points decide through move_preflight. BufFilePost (agentic_document.lua:829-843) checks filereadable and calls bounded_request itself, and no caller passes new_exists or overwrite. Route the check through move_preflight, or remove the branch and add a plan Revision.
  - id: new
    severity: Minor
    kind: defect
    family: silent-error-swallowing
    title: |
      BufWritePost ignores record_write's failure, leaving a stale journal witness silently
    detail: |
      agentic_document.lua:873. If persist fails, the later reopen recovery fails with no earlier warning. It should notify.
  - id: new
    severity: Minor
    kind: defect
    family: lifecycle-claim-drift
    title: |
      Background requests are not cancelled on detach as the plan's ARCH-FUNERAL claims; answered/asking grow per path
    detail: |
      The callbacks are guarded, so this is safe, but the plan's statement is wrong and the memo has no bound.
  - id: new
    severity: Minor
    kind: defect
    family: implicit-state-flags
    title: |
      The move's state is spread across flags on moving (answered, overdue, pending_error, error, journal_pending) with no transition function
    detail: |
      move_outcome projects views from these flags, but their legal combinations are unwritten (ARCH-ORDER).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"62e0c8d7-2c3d-4d2d-8e66-f3856493f966","repository":"github.com/xianxu/parley.nvim","issue_id":"000359","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/c3e2593110710224","reviewed_head":"656611a6c5a13a9e734f1a47ab9e94fdd7257dbc","slot":"parley.nvim:4","requested_at":"2026-10-17T02:15:02.623955Z"},"phase":"finished","pid":1014,"started_at":"2026-10-17T02:15:03.40328Z","finished_at":"2026-10-17T02:22:58.638647Z","session_id":"9bfea3df-1218-46aa-853e-93b7039b594e","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T19:32:21-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 359 — Asynchronous rename protocol for agentic documents (BufFilePre/BufFilePost preflights) |
| repo | parley.nvim |
| issue file | workshop/issues/000359-asynchronous-rename-protocol-for-agentic-documents-buffilepre-buffilepost-preflights.md |
| boundary | whole-issue close |
| milestone | — |
| window | 630f6aac732056d390a4a21d77f4c668abda8900..aae97db73b9403cb42264d9f7e39a5e40d877513 |
| command | sdlc close --issue 359 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T19:32:21-07:00 |
| verdict | SHIP |

## Review

Verifying the round-1 fixes now: reading `move_preflight` and the BufFilePost path, then running the specs.

Running the touched specs, then mutation-checking the round-1 fixes.

Green. Now reverting each fix to confirm its test goes red.

```verdict
verdict: SHIP
confidence: medium
```

The round-1 fixes hold. I reverted each of the three blocking fixes in the disposable checkout, and each one turned its regression test red. Reverting the tree pre-pass to an early return failed "asks about every unknown document of a tree before refusing". Removing the expiry check failed "lets a background absent answer expire". Replacing `decision.wait_destination` with `false` failed row 9 ("a :saveas! onto an existing file whose check times out…"). With the fixes in place, all five touched spec files pass: `document_move_plan_spec`, `document_session_spec`, `agentic_document_owned_move_spec`, `agentic_document_spec` and `document_move_spec`. The checkout was restored and `git status` is clean. Two Minor items from round 1 stay open (BR-4 has no test; BR-6 is documented but not enforced). There is one new Minor finding about the 60 s expiry. None of these blocks the close.

1. **Strengths**
   - `document_move_plan.lua:270` `move_preflight` and `:290` `move_outcome` are pure, unit-tested decision tables. All three entry points now use them: `move_membership` at `agentic_document.lua:647`, BufFilePre at `:817` and BufFilePost at `:872`. This is ARCH-DRY and ARCH-PURE done right.
   - `init.lua:3887-3894` asks about every file in the tree before refusing, so the operator needs only one rerun. Only two callers exist (`init.lua:3499` and `:3891`), so the class is covered, not just the instance.
   - `agentic_document.lua:576-588`: the absent answer expires using the live `M.ANSWER_TTL_MS`, which lets the test shrink the TTL without changing production code. `asking` dedupes so only one request per path is out at a time.
   - The `couch.run` spy in the tree test passes calls through to the production runner, so the test runs against the stateful fake, not a stub (ARCH-MOCK).
   - `move_outcome`'s `shell_word` (`document_move_plan.lua:283`) quotes the pasteable `forget` command with structural escaping (ARCH-SECURE).

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - **The 60 s expiry quietly bounds "one rerun".** If the operator reruns more than `ANSWER_TTL_MS` after the refusal, the move refuses again. The atlas (`atlas/modes/session_sync.md:152-161`) and README (`README.md:58-60`) still describe "an earlier background answer" with no bound. This is a new instance in the `one-recovery-action` family; see the findings block.
   - **`overwrite` is the same value as `new_exists`.** BufFilePost passes `filereadable()` as both (`agentic_document.lua:871-873`), so `move_preflight`'s `overwrite` field carries no information. One effect: `:file existing.md`, which renames without writing, also waits inline. That is conservative and harmless, but the docs say "only `:saveas!`".
   - **BR-4 (still open):** the `record_write` failure now notifies (`agentic_document.lua:903-908`), but no test reaches that branch.

5. **Test coverage notes**
   - The three new or changed blocking behaviours each have a test that fails when the fix is reverted (verified above).
   - Not covered: the `record_write`-failure notify branch, and pruning of expired `answered` entries. Pruning is cosmetic: the reader already rejects expired entries.

6. **Architectural notes**

   | Marker | Result | Note |
   |---|---|---|
   | ARCH-DRY | pass | |
   | ARCH-PURE | pass | |
   | ARCH-PURPOSE | pass | Tree sweep complete |
   | ARCH-MOCK | pass | |
   | ARCH-CONSTRAINTS | pass | The UI path waits only for an overwrite, bounded by `agentic_move_timeout_ms`. Tree fan-out is one request per unknown path, deduplicated. |
   | ARCH-SECURE | pass | |
   | ARCH-ORDER | flag (Minor, BR-6) | The move's state is now listed in order in a comment (`agentic_document.lua:134-145`). But flags still change directly, not through a transition function, and a comment does not satisfy the principle. Upcoming work should fold `s.move` into a tagged state that `move_outcome`/`move_preflight`'s module owns. |
   | ARCH-FUNERAL | pass | `answered` is pruned when a new answer is inserted and capped by expiry; `asking` clears when its callback runs. |

7. **Plan revision recommendations**
   - Add to the 2026-10-16 Revisions entry: "A rerun later than `ANSWER_TTL_MS` (60 s) after the refusal asks again; one recovery action holds only within that window." Mirror that in atlas `session_sync.md` and the README move sentence.
   - Note that `move_preflight`'s `overwrite` is filled from `filereadable(NEW)`, so any rename onto an existing path (including `:file`) asks inline.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      init.lua:3887-3894 collects the first refusal after asking about every file; reverting to the early return fails the new two-child tree test (verified).
  - id: BR-2
    disposition: addressed
    note: |
      answered now stores an expiry checked in known_identity (agentic_document.lua:599-600); dropping the expiry check fails "lets a background absent answer expire" (verified).
  - id: BR-3
    disposition: addressed
    note: |
      BufFilePost decides through move_preflight.wait_destination (agentic_document.lua:872-874); replacing it with false fails row 9 in agentic_document_spec (verified).
  - id: BR-4
    disposition: not-addressed
    note: |
      A notify was added at agentic_document.lua:903-908, but no test reaches the record_write-failure branch; Minor, non-blocking.
  - id: BR-5
    disposition: addressed
    note: |
      The plan's ARCH-FUNERAL paragraph now says requests are not cancelled and callbacks are guarded; answered expires and asking dedupes per path, matching the code.
  - id: BR-6
    disposition: not-addressed
    note: |
      The fields are documented in order (agentic_document.lua:134-145), but there is still no transition function, so ARCH-ORDER is unmet; Minor, non-blocking.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: one-recovery-action
    title: |
      The 60 s absent-answer expiry quietly bounds the one-rerun promise, and the docs do not say so
    detail: |
      This is the 2nd finding in family one-recovery-action. Rule: every refusal that tells the operator to run the move again must state how long its answer stays valid, in the plan, atlas and README. A rerun more than ANSWER_TTL_MS after the refusal refuses again (agentic_document.lua:599-600), but atlas session_sync.md:152-161 and README.md:58-60 describe "an earlier background answer" with no bound. Separately, BufFilePost passes filereadable(NEW) as both new_exists and overwrite, so :file onto an existing path also waits inline, contrary to "only :saveas!".
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"72e49f77-f526-4571-97fb-de633e074377","repository":"github.com/xianxu/parley.nvim","issue_id":"000359","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/0c104a8eca5f175a","reviewed_head":"aae97db73b9403cb42264d9f7e39a5e40d877513","slot":"parley.nvim:4","requested_at":"2026-10-17T02:28:14.719194Z"},"phase":"finished","pid":49800,"started_at":"2026-10-17T02:28:14.835028Z","finished_at":"2026-10-17T02:32:17.837824Z","session_id":"ed65899a-889b-4725-8501-94c09333129f","outcome":"returned"}] -->
