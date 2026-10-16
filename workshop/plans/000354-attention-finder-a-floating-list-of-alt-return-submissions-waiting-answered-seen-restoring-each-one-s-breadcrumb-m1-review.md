# Boundary Review — parley.nvim#354 (milestone M1)

| field | value |
|-------|-------|
| issue | 354 — Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb |
| repo | parley.nvim |
| issue file | workshop/issues/000354-attention-finder-a-floating-list-of-alt-return-submissions-waiting-answered-seen-restoring-each-one-s-breadcrumb.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | a936c96ce50bc9034e175915f691b0eebc690b33..e112cce865925f4db2f3fa824327967cdfe1ae18 |
| command | sdlc milestone-close --issue 354 --milestone M1 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T15:05:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Let me read the code files directly.

I've read the diff and specs; now I'm checking the existing `file_history` module and running the tests.

All 49 tests pass. Now checking whether the store and model specs cover what the plan promised.

Tests pass. Two last checks: whether the README lists config keys, and what the new atlas page says.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 does what the plan says. The model in `attention_model.lua` is the only place state changes. The store in `attention_store.lua` takes a lease, re-reads the file, writes it atomically, retries a busy lease a bounded number of times, then warns. The recording hook sits in the one function both Alt+Return paths share (`session_sync.lua:820-826`). I ran `make test-spec SPEC=ui/attention_finder` on the pinned head: 49 tests passed and none failed (model 27, store 12, integration 10). Nothing is Critical. One Important gap remains: the plan deliberately records a submit *before* the send callback's stale-state guard, and no test would catch that line being moved below the guard. It's cheap to add, so the verdict is FIX-THEN-SHIP rather than SHIP.

### 1. Strengths
- **One transition owns the state.** All five events go through `attention_model.transition` (`attention_model.lua:144`), and waiting/answered/seen are worked out from the data rather than stored (`:20-28`). The store never edits entries itself; it only calls `Model.transition` (`attention_store.lua:86-87`).
- **The stale-probe fix is real.** `observed` removes only IDs that were in `probed_ids` (`attention_model.lua:111-113`). Both a named test and 200 seeded random sequences check that an ID outside the probe survives, and that a failed probe never counts as answered.
- **The file is parsed into typed values when read** (`attention_store.lua:22-35`, `:55-73`). A bad version or shape reads as empty with one warning, and the file is registered in `tests/helpers/sidecars.lua`. A busy lease is retried and then warned; it is never silently dropped (`:112-120`).
- **The fake Couch keeps state between calls.** Sends print receipt IDs from a counter file, `--owe` and `--fold` edit the registry ledger, and production and tests both go through the same `couch` binary seam.
- **Leftover temp files have an owner.** Moving the store into its own `attention/` directory means stale temps can be removed under the lease without touching other sidecars (`attention_store.lua:121-122`).

### 2. Critical findings
None.

### 3. Important findings
- **No test for the "record before the guard" ordering** (`session_sync.lua:825-826`, ARCH-ORDER). The plan records a submit even if the buffer was wiped, moved or re-epoched while the send was running. No spec covers that case. Every integration test keeps the buffer alive until the record lands, so moving the `attention.record` line below `if state[buf] ~= s ... return end` would leave every test green.
  - Fix sketch: set `FAKE_COUCH_SLEEP` so the send stalls, delete or detach the buffer after pressing `<M-CR>`, then wait for `entry(file)` to exist with `msg-1` pending.

### 4. Minor findings
- `attention.record` runs inside the critical send callback without `pcall` (`session_sync.lua:826`). If the store threw outside its own pcalls (`M.dir()`, `leases.acquire`, `remove_stale_temps`), the rest of the callback would be skipped: the "submitted to" notice, the `probe(buf)`, and the caller's callback. Wrap it in `pcall` and warn on failure (ARCH-CONSTRAINTS: optional work on the critical path).
- The plan's store test "two stores over one path both keep their events" is only approximated: the test simulates the other editor with a direct `table_to_file_atomic` write (`attention_store_spec.lua:37-45`). The lease contention itself is covered by the held-lease tests.
- `attention_model` claims "Pure: no vim.api" but calls `vim.deepcopy` (`attention_model.lua:42`). That isn't IO, but it ties the pure core to the Neovim runtime. A local deep copy would remove the dependency.
- Times are whole seconds (`os.time()`). If a file is seen, resubmitted and answered within the same second, `seen_at >= answered_at` would read as seen. This is practically unreachable, since an answer needs an agent fold plus a probe.

### 5. Test coverage notes
- Model: table-driven event × state cases, a never-mutates-input check, 200 seeded random sequences with properties, the bound's drop order and refusal, and list order. Strong.
- Store: the parse boundary through the corruption cases, retry on a busy lease, a lost record when the lease stays held, sweep and grace, and the "full" warning. These use a real lease and real files under a temporary `state_dir`, so they can't touch real user state.
- Integration: both Alt+Return paths are exercised against the fake, plus a failed send, stdout without an ID, and a table of `parse_message_id` shapes. Missing: the late-completion case in Important #1.

### 6. Architecture principles
- **ARCH-DRY: pass.** There is one hook for both paths, and only the model reads `pending`.
- **ARCH-PURE: pass.** The clock is read in the store and passed in as `now`; the IO stays in the store and glue (aside from the `vim.deepcopy` note).
- **ARCH-PURPOSE: pass.** M1's scope (model, store, recording) is fully delivered. The finder is M2 by plan, not a deferral of the point.
- **ARCH-MOCK: pass.** There's a stateful fake behind the real binary seam. The live conformance check is the operator's smoke test, as the plan declares.
- **ARCH-CONSTRAINTS: pass with the Minor note.** Recording is one atomic write after a successful send, with bounded retries.
- **ARCH-SECURE: pass.** The persisted file is typed when read. The breadcrumb is kept as an opaque table and left to #353's `restore` to validate. No credentials are involved.
- **ARCH-ORDER: flag (Important #1).** The model enforces itself and the property tests are good, but the late-completion path has no test.
- **ARCH-FUNERAL: pass.** There's one file capped at 256 entries, swept on every apply. Temps are cleaned under the lease, and the lease file is a single fixed path.

### 7. Notes for upcoming work (M2)
- `refresh` must capture `probed_ids` from the stored entry right when each probe starts. Read them from `Store.load()` at that moment, not from the list the picker opened with.
- The plan's integration test should keep injecting the concurrency limit of 4 and the clock.
- When M2 adds the `<M-u>` chord and `:ParleyAttention` command, `README.md` and `atlas/ui/keybindings.md` need updating. M1 adds no surface a user runs or types.

### 8. Plan revision recommendations
None required. Optionally, add a Revisions line noting that the "two stores" store test is simulated by a direct write between two applies.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: declared-ordering-untested
    title: |
      No regression test pins recording a submit before the send callback's stale-state guard
    detail: |
      session_sync.lua:826 records before the guard so a send whose buffer was wiped, moved or re-epoched is still tracked, but every attention_record_spec case keeps the buffer alive; moving the line below the guard leaves all tests green. Add a FAKE_COUCH_SLEEP case that deletes the buffer mid-send and asserts the entry lands with msg-1 pending (ARCH-ORDER late completion).
  - id: new
    severity: Minor
    kind: defect
    family: optional-work-on-critical-path
    title: |
      attention.record runs unprotected inside the critical send callback
    detail: |
      A throw from the store outside its pcalls (M.dir, leases.acquire, remove_stale_temps) would skip the submitted notice, probe(buf) and the caller callback in release_and_send; wrap the record call in pcall and warn (ARCH-CONSTRAINTS).
  - id: new
    severity: Minor
    kind: defect
    family: plan-test-strategy-drift
    title: |
      Planned two-stores-over-one-path store test is simulated by a direct file write
    detail: |
      attention_store_spec.lua:37-45 interleaves a raw table_to_file_atomic write rather than two Store.apply calls contending for the lease; lease contention is covered separately by the held-lease cases.
  - id: new
    severity: Minor
    kind: defect
    family: pure-core-runtime-coupling
    title: |
      attention_model, documented as pure, depends on vim.deepcopy
    detail: |
      attention_model.lua:42 uses vim.deepcopy, which is not IO but ties the pure core to the Neovim runtime; a local deep copy would drop the dependency.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2cf02293-35fb-491a-aeee-d6f8ad5709c0","repository":"github.com/xianxu/parley.nvim","issue_id":"000354","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/3cc0aebead8ef28b","reviewed_head":"e112cce865925f4db2f3fa824327967cdfe1ae18","slot":"parley.nvim:3","requested_at":"2026-10-16T22:01:45.393688Z"},"phase":"finished","pid":30696,"started_at":"2026-10-16T22:01:45.735688Z","finished_at":"2026-10-16T22:04:59.757644Z","session_id":"f70c1d55-725c-46ce-9fbb-730e76eb0d3c","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T15:18:42-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 354 — Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb |
| repo | parley.nvim |
| issue file | workshop/issues/000354-attention-finder-a-floating-list-of-alt-return-submissions-waiting-answered-seen-restoring-each-one-s-breadcrumb.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | a936c96ce50bc9034e175915f691b0eebc690b33..606b48c50e3f34b04122e7fb83e11ce4a9a0c2f0 |
| command | sdlc milestone-close --issue 354 --milestone M1 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T15:18:42-07:00 |
| verdict | SHIP |

## Review

Still verifying the BR-2 regression test. Next I'll revert the fix in the disposable checkout to check that the test goes red.

Now I'll move the record call below the guard and check that the late-completion spec fails.

BR-2 is confirmed: the spec goes red when the record moves below the guard. Next I'll do the same check for BR-3's pcall.

BR-3 is confirmed too. Now checking BR-5 (whether any `vim.*` remains in the pure model) and BR-1/BR-4 against the plan text and store spec.

All five prior findings are dispositioned. Now scanning for new issues: README/config surface, the fake Couch changes and the lessons file.

The remaining code checks out. One loose end: the integration run printed `Error in command line:`, so I'm looking at where that comes from.

```verdict
verdict: SHIP
confidence: high
```

M1 delivers what the plan claims for Tasks 1–3: a pure model with a single transition, a leased, re-reading atomic store, and one record hook in `release_and_send` that both Alt+Return paths reach. I checked the two behavioral fixes from the prior round by breaking each one in the disposable checkout. Moving `attention.record` below the stale-state guard turns "records a send that completes after its buffer was wiped" red. Removing the `pcall` turns "a record that throws leaves the submit's own completion intact" red. Restoring each fix turns them green again. At head, `make test-spec SPEC=ui/attention_finder` passes 12 + 27 + 12 with no failures. The `Error in command line:` line in that output is the expected notice from the failed-send spec, not a test error. Nothing blocks SHIP. Two Minor notes are aimed at M2.

**1. Strengths**
- `lua/parley/session_sync.lua:820-832`: the breadcrumb is taken and the path captured before the send, and the record runs before the stale guard under `pcall` with a visible warning. Both orderings are pinned by tests that fail when the fix is removed.
- `lua/parley/attention_model.lua`: every change goes through `transition`. `observed` removes only the `probed_ids` that are no longer owed, so a stale probe cannot answer a newer submit. `observe_failed` has no path to answered. This is ARCH-ORDER done structurally.
- `lua/parley/attention_store.lua:105-137`: a busy lease is retried a bounded number of times, then the lost record is warned. Stale temps are swept under the lease in the store's own directory, and the parse boundary types every field, with one warning per read (ARCH-SECURE).
- The stateful fake: `fake_couch.lua` prints the receipt line and records owed IDs in the existing registry fixture, and `fold` mirrors `write --fold`. Production and tests share the same `couch` CLI seam.

**2. Critical:** none.

**3. Important:** none.

**4. Minor**
- Plan Task 6 updates the atlas only. README.md documents the session-sync config keys (README.md:59-60), but nothing in the plan updates it for `<M-u>`, `:ParleyAttention` or `attention.seen_grace_minutes` when M2 makes them visible.
- ARCH-MOCK: `parse_message_id` depends on Couch's `--send-to` receipt line (`<ID> <from> -> <to> <status>`). The fake reproduces it, but no conformance check covers it; the registry conformance script checks only `--session-sync`. Drift here degrades visibly (a "no message ID" warning), so this is a note, not a blocker.

**5. Test coverage**
- The late completion and the throwing record are both proven to fail when their fix is removed (checked by mutation in this review).
- The model is tested with table-driven cases, seeded random sequences with properties, the stale probe, and the bound.
- The store is tested on its parse boundary (including the shared sidecar corruption cases), a held lease, the sweep and the full refusal.
- The "two stores over one path" test still simulates the second editor with a direct write. That deviation is documented in the plan; see BR-4.

**6. Architecture**
- **ARCH-DRY:** pass. There is one record hook for both send paths, and the store reuses `table_to_file_atomic`, `remove_stale_temps` and `document_lease`.
- **ARCH-PURE:** pass. `attention_model` has no `vim.*` or `require`; `grep` finds only the header comment.
- **ARCH-PURPOSE:** pass for M1. The finder itself is M2 by plan, not a deferred purpose.
- **ARCH-MOCK:** pass, with the Minor note above.
- **ARCH-CONSTRAINTS:** pass. The record runs after the send succeeded, is optional work, and cannot throw into the send.
- **ARCH-SECURE:** pass. The store file is typed at the read, and wrong shapes degrade with a warning.
- **ARCH-ORDER:** pass. The ordering is explicit in the model, and the late completion is tested.
- **ARCH-FUNERAL:** pass. The file holds at most 256 entries, seen entries are swept on every apply, temps are swept under the lease, and the lease file is a single fixed inode.

For M2, `refresh`'s at-most-4 concurrency limit and observations arriving after the finder closes need tests that control the ordering, as the plan's Task 5 lists.

**7. Plan revisions:** add README.md to Task 6, covering the chord, the command and `attention.seen_grace_minutes`.

```findings
dispose:
  - id: BR-1
    disposition: withdrawn
    note: |
      Tasks 1-3 now read as one strategy bullet per risky surface; Task 5's list is the M2 acceptance set and is better judged at M2 close.
  - id: BR-2
    disposition: addressed
    note: |
      attention_record_spec "records a send that completes after its buffer was wiped" goes red when the record is moved below the guard (verified by mutation) and green at head.
  - id: BR-3
    disposition: addressed
    note: |
      session_sync.lua:829 wraps record in pcall with a WARN notice; removing the pcall makes "a record that throws leaves the submit's own completion intact" fail (verified by mutation).
  - id: BR-4
    disposition: addressed
    note: |
      Plan Revisions (M1 review) records the deviation: lease contention can't be shown in one process, and the held-lease specs cover it.
  - id: BR-5
    disposition: addressed
    note: |
      attention_model.lua uses a local copy(); grep finds no vim.* or require in the module.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: docs-gate-plan-gap
    title: |
      Plan Task 6 omits a README update for the finder's chord, command and attention.seen_grace_minutes
    detail: |
      README.md:59-60 documents the session-sync config keys, but Task 6 lists only atlas files. Add README.md to Task 6 so M2 ships <M-u>, :ParleyAttention and the grace key documented.
  - id: new
    severity: Minor
    kind: defect
    family: fake-conformance-gap
    title: |
      No conformance check pins the couch --send-to receipt line that parse_message_id depends on
    detail: |
      fake_couch.lua prints `msg-N from -> to queued`, but the registry conformance script covers only --session-sync. Drift degrades visibly (a "no message ID" warning), so either extend the conformance check or note this in the atlas.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"38739dae-cc55-4cd9-aae5-d7798cdc30a7","repository":"github.com/xianxu/parley.nvim","issue_id":"000354","recipe":"milestone-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/31002f7faf77c5ef","reviewed_head":"606b48c50e3f34b04122e7fb83e11ce4a9a0c2f0","slot":"parley.nvim:3","requested_at":"2026-10-16T22:16:17.51492Z"},"phase":"finished","pid":16066,"started_at":"2026-10-16T22:16:17.644682Z","finished_at":"2026-10-16T22:18:40.839207Z","session_id":"9ed6866b-234e-4287-997f-6d93a6cb06d5","outcome":"returned"}] -->
