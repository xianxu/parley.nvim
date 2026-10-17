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
