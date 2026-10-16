---
gate: boundary-review
issue: 354
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-16T15:05:02-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: Tasks 1, 2, 3 and 5 enumerate test cases in prose instead of one strategy line per risky function
          detail: |-
            Compress to strategy lines, e.g. transition over random event sequences, checked by the property that no failure path reaches answered and waiting is never swept.
            (carried from plan-quality PQ-4, deferred to the boundary review)
          family: test-prose-enumeration
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2cf02293-35fb-491a-aeee-d6f8ad5709c0
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/3cc0aebead8ef28b
            reviewed_head: e112cce865925f4db2f3fa824327967cdfe1ae18
            slot: parley.nvim:3
            requested_at: "2026-10-16T22:01:45.393688Z"
          phase: finished
          pid: 30696
          started_at: "2026-10-16T22:01:45.735688Z"
          finished_at: "2026-10-16T22:04:59.757644Z"
          session_id: f70c1d55-725c-46ce-9fbb-730e76eb0d3c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: e112cce865925f4db2f3fa824327967cdfe1ae18
        tracker_head: 426d20d1dfe9fc33d1d18255281ae27ba40b13ad
        branch_point: a936c96ce50bc9034e175915f691b0eebc690b33
        since: "2026-10-16T11:20:37-07:00"
        until: "2026-10-16T14:57:09-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:20:37-07:00"
              end: "2026-10-16T14:57:09-07:00"
              began: "2026-10-16T11:20:37-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 63beb7f6-5e18-48e9-8bae-6484d78ced70
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 7696a8cfa19da19757e068a8b13a0ded1ba171623a9a7a3b76c87db5fcd12ca8
              started: "2026-10-16T21:36:34.222Z"
              spawned: false
              bytes: 588762
              windows:
                - start: "2026-10-16T21:36:34.222Z"
                  end: "2026-10-16T14:57:09-07:00"
            - harness: claude
              id: 90c11d14-54c6-4cef-b441-ee83b536d8ed
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a0b2f35f930689737acaefc211508db7e9ff6e5f9c31efd1fa2555694d341cbc
              started: "2026-10-16T21:41:15.716Z"
              spawned: false
              bytes: 364033
              windows:
                - start: "2026-10-16T21:41:15.716Z"
                  end: "2026-10-16T14:57:09-07:00"
            - harness: claude
              id: 983bc5e5-6019-4a70-8c51-b5201568013a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8907360015289702272f2f19a536a07201c34e4122278f54a205ee9b6d0daced
              started: "2026-10-16T21:40:54.825Z"
              spawned: false
              bytes: 509772
              windows:
                - start: "2026-10-16T21:40:54.825Z"
                  end: "2026-10-16T14:57:09-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: adde48701b053120b2b4d73bba3262bf21e156597162c382e1ffc8d5b7126ca2
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 16104542
              windows:
                - start: "2026-10-16T11:20:37-07:00"
                  end: "2026-10-16T14:57:09-07:00"
            - harness: claude
              id: af54b6ac-7b02-4fb4-8a7c-8ff23f227998
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a364eb1c98acced3eb731b4929001c967ef685d6feb342a2e39bce102ff7dc66
              started: "2026-10-16T21:39:24.567Z"
              spawned: false
              bytes: 537706
              windows:
                - start: "2026-10-16T21:39:24.567Z"
                  end: "2026-10-16T14:57:09-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.06256666666666667
      "n": 2
      timestamp: "2026-10-16T15:05:02-07:00"
      dispatched: "2026-10-16T15:01:45-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-2
          severity: Important
          title: No regression test pins recording a submit before the send callback's stale-state guard
          detail: session_sync.lua:826 records before the guard so a send whose buffer was wiped, moved or re-epoched is still tracked, but every attention_record_spec case keeps the buffer alive; moving the line below the guard leaves all tests green. Add a FAKE_COUCH_SLEEP case that deletes the buffer mid-send and asserts the entry lands with msg-1 pending (ARCH-ORDER late completion).
          family: declared-ordering-untested
          round: 2
        - kind: defect
          id: BR-3
          severity: Minor
          title: attention.record runs unprotected inside the critical send callback
          detail: A throw from the store outside its pcalls (M.dir, leases.acquire, remove_stale_temps) would skip the submitted notice, probe(buf) and the caller callback in release_and_send; wrap the record call in pcall and warn (ARCH-CONSTRAINTS).
          family: optional-work-on-critical-path
          round: 2
        - kind: defect
          id: BR-4
          severity: Minor
          title: Planned two-stores-over-one-path store test is simulated by a direct file write
          detail: attention_store_spec.lua:37-45 interleaves a raw table_to_file_atomic write rather than two Store.apply calls contending for the lease; lease contention is covered separately by the held-lease cases.
          family: plan-test-strategy-drift
          round: 2
        - kind: defect
          id: BR-5
          severity: Minor
          title: attention_model, documented as pure, depends on vim.deepcopy
          detail: attention_model.lua:42 uses vim.deepcopy, which is not IO but ties the pure core to the Neovim runtime; a local deep copy would drop the dependency.
          family: pure-core-runtime-coupling
          round: 2
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 38739dae-cc55-4cd9-aae5-d7798cdc30a7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/31002f7faf77c5ef
            reviewed_head: 606b48c50e3f34b04122e7fb83e11ce4a9a0c2f0
            slot: parley.nvim:3
            requested_at: "2026-10-16T22:16:17.51492Z"
          phase: finished
          pid: 16066
          started_at: "2026-10-16T22:16:17.644682Z"
          finished_at: "2026-10-16T22:18:40.839207Z"
          session_id: 9ed6866b-234e-4287-997f-6d93a6cb06d5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 606b48c50e3f34b04122e7fb83e11ce4a9a0c2f0
        tracker_head: 2801e703c3e3925fe8a0dc3eea7c60fa95e4c3f3
        branch_point: a936c96ce50bc9034e175915f691b0eebc690b33
        since: "2026-10-16T11:20:37-07:00"
        until: "2026-10-16T15:15:46-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:20:37-07:00"
              end: "2026-10-16T15:15:46-07:00"
              began: "2026-10-16T11:20:37-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 63beb7f6-5e18-48e9-8bae-6484d78ced70
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 7696a8cfa19da19757e068a8b13a0ded1ba171623a9a7a3b76c87db5fcd12ca8
              started: "2026-10-16T21:36:34.222Z"
              spawned: false
              bytes: 588762
              windows:
                - start: "2026-10-16T21:36:34.222Z"
                  end: "2026-10-16T15:15:46-07:00"
            - harness: claude
              id: 90c11d14-54c6-4cef-b441-ee83b536d8ed
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a0b2f35f930689737acaefc211508db7e9ff6e5f9c31efd1fa2555694d341cbc
              started: "2026-10-16T21:41:15.716Z"
              spawned: false
              bytes: 364033
              windows:
                - start: "2026-10-16T21:41:15.716Z"
                  end: "2026-10-16T15:15:46-07:00"
            - harness: claude
              id: 983bc5e5-6019-4a70-8c51-b5201568013a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8907360015289702272f2f19a536a07201c34e4122278f54a205ee9b6d0daced
              started: "2026-10-16T21:40:54.825Z"
              spawned: false
              bytes: 509772
              windows:
                - start: "2026-10-16T21:40:54.825Z"
                  end: "2026-10-16T15:15:46-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a21d1293d9e62212b4b0ff7b85e84ced481cbd79deae8040a907b08d2c6acb62
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 16274250
              windows:
                - start: "2026-10-16T11:20:37-07:00"
                  end: "2026-10-16T15:15:46-07:00"
            - harness: claude
              id: af54b6ac-7b02-4fb4-8a7c-8ff23f227998
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a364eb1c98acced3eb731b4929001c967ef685d6feb342a2e39bce102ff7dc66
              started: "2026-10-16T21:39:24.567Z"
              spawned: false
              bytes: 537706
              windows:
                - start: "2026-10-16T21:39:24.567Z"
                  end: "2026-10-16T15:15:46-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.0931
        cuts:
            - boundary: M1
              dispatched: "2026-10-16T15:01:45-07:00"
              finalized: "2026-10-16T15:05:02-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-16T15:18:45-07:00"
      dispatched: "2026-10-16T15:16:17-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: withdrawn
          note: Tasks 1-3 now read as one strategy bullet per risky surface; Task 5's list is the M2 acceptance set and is better judged at M2 close.
          round: 3
        - id: BR-2
          disposition: addressed
          note: attention_record_spec "records a send that completes after its buffer was wiped" goes red when the record is moved below the guard (verified by mutation) and green at head.
          round: 3
        - id: BR-3
          disposition: addressed
          note: session_sync.lua:829 wraps record in pcall with a WARN notice; removing the pcall makes "a record that throws leaves the submit's own completion intact" fail (verified by mutation).
          round: 3
        - id: BR-4
          disposition: addressed
          note: 'Plan Revisions (M1 review) records the deviation: lease contention can''t be shown in one process, and the held-lease specs cover it.'
          round: 3
        - id: BR-5
          disposition: addressed
          note: attention_model.lua uses a local copy(); grep finds no vim.* or require in the module.
          round: 3
      findings:
        - kind: defect
          id: BR-6
          severity: Minor
          title: Plan Task 6 omits a README update for the finder's chord, command and attention.seen_grace_minutes
          detail: README.md:59-60 documents the session-sync config keys, but Task 6 lists only atlas files. Add README.md to Task 6 so M2 ships <M-u>, :ParleyAttention and the grace key documented.
          family: docs-gate-plan-gap
          round: 3
        - kind: defect
          id: BR-7
          severity: Minor
          title: No conformance check pins the couch --send-to receipt line that parse_message_id depends on
          detail: fake_couch.lua prints `msg-N from -> to queued`, but the registry conformance script covers only --session-sync. Drift degrades visibly (a "no message ID" warning), so either extend the conformance check or note this in the atlas.
          family: fake-conformance-gap
          round: 3
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      reviewed: 606b48c50e3f34b04122e7fb83e11ce4a9a0c2f0
      blocked: false
---

# Gate ledger — parley.nvim#354 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T15:05:02-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `test-prose-enumeration` Tasks 1, 2, 3 and 5 enumerate test cases in prose instead of one strategy line per risky function
  Compress to strategy lines, e.g. transition over random event sequences, checked by the property that no failure path reaches answered and waiting is never swept.
  (carried from plan-quality PQ-4, deferred to the boundary review)

## Round 2 — 2026-10-16T15:05:02-07:00 (claude) — BLOCKED

### Raised

- **BR-2** [Important] `declared-ordering-untested` (kind: defect) No regression test pins recording a submit before the send callback's stale-state guard
  session_sync.lua:826 records before the guard so a send whose buffer was wiped, moved or re-epoched is still tracked, but every attention_record_spec case keeps the buffer alive; moving the line below the guard leaves all tests green. Add a FAKE_COUCH_SLEEP case that deletes the buffer mid-send and asserts the entry lands with msg-1 pending (ARCH-ORDER late completion).
- **BR-3** [Minor] `optional-work-on-critical-path` (kind: defect) attention.record runs unprotected inside the critical send callback
  A throw from the store outside its pcalls (M.dir, leases.acquire, remove_stale_temps) would skip the submitted notice, probe(buf) and the caller callback in release_and_send; wrap the record call in pcall and warn (ARCH-CONSTRAINTS).
- **BR-4** [Minor] `plan-test-strategy-drift` (kind: defect) Planned two-stores-over-one-path store test is simulated by a direct file write
  attention_store_spec.lua:37-45 interleaves a raw table_to_file_atomic write rather than two Store.apply calls contending for the lease; lease contention is covered separately by the held-lease cases.
- **BR-5** [Minor] `pure-core-runtime-coupling` (kind: defect) attention_model, documented as pure, depends on vim.deepcopy
  attention_model.lua:42 uses vim.deepcopy, which is not IO but ties the pure core to the Neovim runtime; a local deep copy would drop the dependency.

## Round 3 — 2026-10-16T15:18:45-07:00 (claude) — passed

### Disposed

- BR-1 — withdrawn — Tasks 1-3 now read as one strategy bullet per risky surface; Task 5's list is the M2 acceptance set and is better judged at M2 close.
- BR-2 — addressed — attention_record_spec "records a send that completes after its buffer was wiped" goes red when the record is moved below the guard (verified by mutation) and green at head.
- BR-3 — addressed — session_sync.lua:829 wraps record in pcall with a WARN notice; removing the pcall makes "a record that throws leaves the submit's own completion intact" fail (verified by mutation).
- BR-4 — addressed — Plan Revisions (M1 review) records the deviation: lease contention can't be shown in one process, and the held-lease specs cover it.
- BR-5 — addressed — attention_model.lua uses a local copy(); grep finds no vim.* or require in the module.

### Raised

- **BR-6** [Minor] `docs-gate-plan-gap` (kind: defect) Plan Task 6 omits a README update for the finder's chord, command and attention.seen_grace_minutes
  README.md:59-60 documents the session-sync config keys, but Task 6 lists only atlas files. Add README.md to Task 6 so M2 ships <M-u>, :ParleyAttention and the grace key documented.
- **BR-7** [Minor] `fake-conformance-gap` (kind: defect) No conformance check pins the couch --send-to receipt line that parse_message_id depends on
  fake_couch.lua prints `msg-N from -> to queued`, but the registry conformance script covers only --session-sync. Drift degrades visibly (a "no message ID" warning), so either extend the conformance check or note this in the atlas.

## Open findings

- **BR-6** [Minor] `docs-gate-plan-gap` (kind: defect) Plan Task 6 omits a README update for the finder's chord, command and attention.seen_grace_minutes
- **BR-7** [Minor] `fake-conformance-gap` (kind: defect) No conformance check pins the couch --send-to receipt line that parse_message_id depends on
