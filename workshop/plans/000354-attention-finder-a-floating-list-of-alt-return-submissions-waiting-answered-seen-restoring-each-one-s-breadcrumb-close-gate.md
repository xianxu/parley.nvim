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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ac0e7c3b-18f3-40f2-8632-a36f9eb6d313
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/95ffd20a2dc657d2
            reviewed_head: 3c39600b8ba6265429f04c07f0524444ae30499b
            slot: parley.nvim:3
            requested_at: "2026-10-16T22:26:05.2624Z"
          phase: finished
          pid: 55050
          started_at: "2026-10-16T22:26:05.408673Z"
          finished_at: "2026-10-16T22:28:33.100648Z"
          session_id: 8baf142f-7d2d-491b-97f9-e2325ceec64d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3c39600b8ba6265429f04c07f0524444ae30499b
        tracker_head: 2801e703c3e3925fe8a0dc3eea7c60fa95e4c3f3
        branch_point: a936c96ce50bc9034e175915f691b0eebc690b33
        since: "2026-10-16T11:20:37-07:00"
        until: "2026-10-16T15:25:32-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:20:37-07:00"
              end: "2026-10-16T15:25:32-07:00"
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
                  end: "2026-10-16T15:25:32-07:00"
            - harness: claude
              id: 90c11d14-54c6-4cef-b441-ee83b536d8ed
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a0b2f35f930689737acaefc211508db7e9ff6e5f9c31efd1fa2555694d341cbc
              started: "2026-10-16T21:41:15.716Z"
              spawned: false
              bytes: 364033
              windows:
                - start: "2026-10-16T21:41:15.716Z"
                  end: "2026-10-16T15:25:32-07:00"
            - harness: claude
              id: 983bc5e5-6019-4a70-8c51-b5201568013a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8907360015289702272f2f19a536a07201c34e4122278f54a205ee9b6d0daced
              started: "2026-10-16T21:40:54.825Z"
              spawned: false
              bytes: 509772
              windows:
                - start: "2026-10-16T21:40:54.825Z"
                  end: "2026-10-16T15:25:32-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d84d83c4e50a2d9e2a832a419acab5d0aaa857278fc9427dbbbbf2594f95eea8
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 16776915
              windows:
                - start: "2026-10-16T11:20:37-07:00"
                  end: "2026-10-16T15:25:32-07:00"
            - harness: claude
              id: af54b6ac-7b02-4fb4-8a7c-8ff23f227998
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a364eb1c98acced3eb731b4929001c967ef685d6feb342a2e39bce102ff7dc66
              started: "2026-10-16T21:39:24.567Z"
              spawned: false
              bytes: 537706
              windows:
                - start: "2026-10-16T21:39:24.567Z"
                  end: "2026-10-16T15:25:32-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.0931
        cuts:
            - boundary: M1
              dispatched: "2026-10-16T15:01:45-07:00"
              finalized: "2026-10-16T15:05:02-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-16T15:16:17-07:00"
              finalized: "2026-10-16T15:18:45-07:00"
              finalizing: true
      "n": 4
      timestamp: "2026-10-16T15:28:34-07:00"
      dispatched: "2026-10-16T15:26:05-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-8
          severity: Important
          title: The probe-start capture of pending IDs (PQ-2) has no test in the refresh glue
          detail: '2nd finding in family declared-ordering-untested. Mutation: in lua/parley/attention.lua:175-178, moving the Store.load()/vim.tbl_keys(entry.pending) capture into the seam.run callback brings back the stale-probe bug, and all 66 mapped specs stay green. Rule: every interleaving in the plan''s ARCH-ORDER list needs a test that drives the production glue, not only the pure model. Sweep: two editors (store lease specs), observation after close (covered), failed probe (covered), 14-day trim (same as fold, covered), stale probe vs newer submit (glue UNCOVERED). Fix: in attention_finder_spec, inject a run that holds its callback; while it is held, record and owe m2 and fold m1; then release and assert the entry is still waiting with m2 pending.'
          family: declared-ordering-untested
          round: 4
        - kind: defect
          id: BR-9
          severity: Minor
          title: 'keybindings.md: the Attention finder section was inserted above a file-history sentence, which now sits under the wrong heading'
          detail: 'atlas/ui/keybindings.md:41-49: "Markdown buffer preparation consults the read-only restoration scope..." belongs to File history (Back), but now appears under "## Attention finder". The same section also claims "Couch''s own key help lists it via pair#619", which this repo cannot check.'
          family: doc-section-misplacement
          round: 4
        - kind: defect
          id: BR-10
          severity: Minor
          title: observe_failed records fixed reasons, not the Couch Code the plan specifies
          detail: couch.query returns nil for any Code other than ok, so M.observation (lua/parley/attention.lua:138-143) cannot see the Code. Record this in the plan's Revisions, or pass the Code through.
          family: plan-code-drift
          round: 4
      boundary: M2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: f506e27f-dabe-4cc3-9282-e83de460e837
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/d236f5864df94f61
            reviewed_head: e5723e33b319a38509eb28a3bb3942288bad707d
            slot: parley.nvim:3
            requested_at: "2026-10-16T22:31:01.269806Z"
          phase: finished
          pid: 87459
          started_at: "2026-10-16T22:31:01.705126Z"
          finished_at: "2026-10-16T22:33:52.350666Z"
          session_id: beca28fc-9498-4964-8b2f-fbcdad48a6bf
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: e5723e33b319a38509eb28a3bb3942288bad707d
        tracker_head: 2801e703c3e3925fe8a0dc3eea7c60fa95e4c3f3
        branch_point: a936c96ce50bc9034e175915f691b0eebc690b33
        since: "2026-10-16T11:20:37-07:00"
        until: "2026-10-16T15:30:28-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:20:37-07:00"
              end: "2026-10-16T15:30:28-07:00"
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
                  end: "2026-10-16T15:30:28-07:00"
            - harness: claude
              id: 90c11d14-54c6-4cef-b441-ee83b536d8ed
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a0b2f35f930689737acaefc211508db7e9ff6e5f9c31efd1fa2555694d341cbc
              started: "2026-10-16T21:41:15.716Z"
              spawned: false
              bytes: 364033
              windows:
                - start: "2026-10-16T21:41:15.716Z"
                  end: "2026-10-16T15:30:28-07:00"
            - harness: claude
              id: 983bc5e5-6019-4a70-8c51-b5201568013a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8907360015289702272f2f19a536a07201c34e4122278f54a205ee9b6d0daced
              started: "2026-10-16T21:40:54.825Z"
              spawned: false
              bytes: 509772
              windows:
                - start: "2026-10-16T21:40:54.825Z"
                  end: "2026-10-16T15:30:28-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 7329d3fc67cfc45e1ec5744fe3b9ccec017477772359bbe3442a5b7f76a65e10
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 16869121
              windows:
                - start: "2026-10-16T11:20:37-07:00"
                  end: "2026-10-16T15:30:28-07:00"
            - harness: claude
              id: af54b6ac-7b02-4fb4-8a7c-8ff23f227998
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a364eb1c98acced3eb731b4929001c967ef685d6feb342a2e39bce102ff7dc66
              started: "2026-10-16T21:39:24.567Z"
              spawned: false
              bytes: 537706
              windows:
                - start: "2026-10-16T21:39:24.567Z"
                  end: "2026-10-16T15:30:28-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.0931
        cuts:
            - boundary: M1
              dispatched: "2026-10-16T15:01:45-07:00"
              finalized: "2026-10-16T15:05:02-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-16T15:16:17-07:00"
              finalized: "2026-10-16T15:18:45-07:00"
              finalizing: true
            - boundary: M2
              dispatched: "2026-10-16T15:26:05-07:00"
              finalized: "2026-10-16T15:28:34-07:00"
              finalizing: false
      "n": 5
      timestamp: "2026-10-16T15:33:54-07:00"
      dispatched: "2026-10-16T15:31:01-07:00"
      agent: claude
      dispose:
        - id: BR-8
          disposition: addressed
          note: 'Mutation verified: moving the capture into the seam.run callback fails "a probe that started before a newer submit leaves that submit waiting"; the other 66 mapped specs stay green; tree restored.'
          round: 5
        - id: BR-9
          disposition: addressed
          note: 'atlas/ui/keybindings.md: the restoration-scope sentence is back under File history, and the pair#619 line now reads as pending work ("Adding it to Couch''s own key help is pair#619").'
          round: 5
        - id: BR-10
          disposition: addressed
          note: Plan Revisions (M2 review) records the fixed reasons; lua/parley/couch.lua:41 confirms query returns nil for any Code other than ok, so the Code is not visible to observation.
          round: 5
      findings:
        - kind: defect
          id: BR-11
          severity: Important
          title: Task 5's ticked strategy names typeahead and cursor-keeping on repaint, but no spec drives the real float_picker
          detail: '2nd finding in the family. Rule: every case a ticked strategy line names maps to a spec driving the production widget, or a Revisions entry records the drop. Sweep of Task 5: typeahead is missing; cursor-keeping is unasserted because the fake update in tests/integration/attention_finder_spec.lua:41 ignores next_selection; the after-close spec tests the fake''s own closed guard, not float_picker.lua:1744; the other cases are covered. Fix: one real-float_picker spec (type a filter, land a fold, assert the filter and selection hold), or a Revisions entry narrowing the strategy.'
          family: plan-test-strategy-drift
          round: 5
        - kind: defect
          id: BR-12
          severity: Minor
          title: Attention probes have no timeout, so a hung couch holds a slot and on_refreshed never fires
          detail: lua/parley/attention.lua:105 calls couch.query, which uses couch.run with no timeout option. The plan's ARCH-CONSTRAINTS calls these short runs but does not bound their duration or extent. Pass a timeout through couch.run and treat expiry as observe_failed.
          family: optional-work-on-critical-path
          round: 5
      boundary: M2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: bc58da1e-10da-4ce3-9c36-79be2deb6bc9
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: milestone-review
            round: 5
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/07bf68763c799bb2
            reviewed_head: f2b9a172c87bb89e9d1498c2b0f53fd78841c2c6
            slot: parley.nvim:3
            requested_at: "2026-10-16T22:53:28.213144Z"
          phase: finished
          pid: 30585
          started_at: "2026-10-16T22:53:28.63124Z"
          finished_at: "2026-10-16T22:57:36.669257Z"
          session_id: 8f87ae8a-127a-4467-9299-ab502c215238
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f2b9a172c87bb89e9d1498c2b0f53fd78841c2c6
        tracker_head: 839a562690012302f4dbeb635f5019a6319ba45f
        branch_point: a936c96ce50bc9034e175915f691b0eebc690b33
        since: "2026-10-16T11:20:37-07:00"
        until: "2026-10-16T15:52:24-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:20:37-07:00"
              end: "2026-10-16T15:52:24-07:00"
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
                  end: "2026-10-16T15:52:24-07:00"
            - harness: claude
              id: 90c11d14-54c6-4cef-b441-ee83b536d8ed
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a0b2f35f930689737acaefc211508db7e9ff6e5f9c31efd1fa2555694d341cbc
              started: "2026-10-16T21:41:15.716Z"
              spawned: false
              bytes: 364033
              windows:
                - start: "2026-10-16T21:41:15.716Z"
                  end: "2026-10-16T15:52:24-07:00"
            - harness: claude
              id: 983bc5e5-6019-4a70-8c51-b5201568013a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8907360015289702272f2f19a536a07201c34e4122278f54a205ee9b6d0daced
              started: "2026-10-16T21:40:54.825Z"
              spawned: false
              bytes: 509772
              windows:
                - start: "2026-10-16T21:40:54.825Z"
                  end: "2026-10-16T15:52:24-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 24a4811cd5d497b4d4d074ec5099b0e8108ba3aecebd2455cb89bfd51c291102
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 17426720
              windows:
                - start: "2026-10-16T11:20:37-07:00"
                  end: "2026-10-16T15:52:24-07:00"
            - harness: claude
              id: af54b6ac-7b02-4fb4-8a7c-8ff23f227998
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a364eb1c98acced3eb731b4929001c967ef685d6feb342a2e39bce102ff7dc66
              started: "2026-10-16T21:39:24.567Z"
              spawned: false
              bytes: 537706
              windows:
                - start: "2026-10-16T21:39:24.567Z"
                  end: "2026-10-16T15:52:24-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 40.262566666666665
        cuts:
            - boundary: M1
              dispatched: "2026-10-16T15:01:45-07:00"
              finalized: "2026-10-16T15:05:02-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-16T15:16:17-07:00"
              finalized: "2026-10-16T15:18:45-07:00"
              finalizing: true
            - boundary: M2
              dispatched: "2026-10-16T15:26:05-07:00"
              finalized: "2026-10-16T15:28:34-07:00"
              finalizing: false
            - boundary: M2
              dispatched: "2026-10-16T15:31:01-07:00"
              finalized: "2026-10-16T15:33:54-07:00"
              finalizing: false
      "n": 6
      timestamp: "2026-10-16T15:57:38-07:00"
      dispatched: "2026-10-16T15:53:28-07:00"
      agent: claude
      dispose:
        - id: BR-11
          disposition: addressed
          note: The real-float_picker spec "keeps the typed filter and the selected row across a live repaint" drives typeahead, cursor-keeping and Enter. Reverting update's third argument fails it (tested in the checkout). The after-close case now also runs on the real picker.
          round: 6
        - id: BR-12
          disposition: addressed
          note: couch.query passes options through to vim.system, and refresh sets timeout 5000. The spec "a probe that outlives its timeout reads as failed" uses the fake's delay mode; removing the timeout fails it (tested in the checkout).
          round: 6
      findings:
        - kind: defect
          id: BR-13
          severity: Important
          title: attention.is_side_doc and discover re-implement frontmatter.parse and document_move_plan.side_path, and disagree with them
          detail: 'lua/parley/attention.lua:120-128 hand-parses frontmatter. Compared with parley.frontmatter.parse (used by session_sync.parse_header), it misses `type: side-doc # comment`, accepts an unclosed fence, and does not lower-case the key. attention.lua:140 rebuilds the side folder with fnamemodify(":r") instead of document_move_plan.side_path (document_move_plan.lua:28). Fix: use frontmatter.parse(head).fields.type == "side-doc" and side_path(entry.path), and add a spec case with a trailing comment. Rule: a fact the codebase already parses or derives is read through its existing owner.'
          family: reuse-existing-owner
          round: 6
        - kind: defect
          id: BR-14
          severity: Minor
          title: The side-doc addition left the plan's ARCH-CONSTRAINTS and the atlas's "only new files" claim out of date
          detail: 'This is the 2nd plan-code-drift finding. Rule: a scope addition re-checks every cross-cutting plan section (Core concepts state/events, ARCH-CONSTRAINTS, ARCH-ORDER, ARCH-FUNERAL) and the atlas claims, and updates each it changes. Here, the finder now renders only after a sweep write, a synchronous scan of up to 256 .side folders, and a batch write, but the plan still says "reads one file and renders at once". The atlas says rewrites don''t count, yet a side doc that predates its parent''s entry is discovered once rewritten (the check is mtime > recorded_at).'
          family: plan-code-drift
          round: 6
        - kind: defect
          id: BR-15
          severity: Minor
          title: A refused side-doc batch warns "256 files are waiting; nil was not recorded" on every open
          detail: attention_store.lua:133 formats event.path, which a batch event has no value for. Name the dropped side docs, or say "side docs" when the event is a batch.
          family: warning-names-missing-subject
          round: 6
      boundary: M2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 051a742c-2707-4c5c-a870-b3e2112da67c
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: milestone-review
            round: 6
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/83fdf9669844bb97
            reviewed_head: 4fdadd497d3754c4d572a44ed7dc60dc658d1732
            slot: parley.nvim:3
            requested_at: "2026-10-16T23:08:06.558617Z"
          phase: finished
          pid: 54291
          started_at: "2026-10-16T23:08:06.889538Z"
          finished_at: "2026-10-16T23:10:29.694728Z"
          session_id: 6f405e64-adcf-4089-8c61-c0a593305f4e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4fdadd497d3754c4d572a44ed7dc60dc658d1732
        tracker_head: c14f7168f1a4be8bf68145f3e9c9cb0e836e54a3
        branch_point: a936c96ce50bc9034e175915f691b0eebc690b33
        since: "2026-10-16T11:20:37-07:00"
        until: "2026-10-16T16:07:14-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:20:37-07:00"
              end: "2026-10-16T16:07:14-07:00"
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
                  end: "2026-10-16T16:07:14-07:00"
            - harness: claude
              id: 90c11d14-54c6-4cef-b441-ee83b536d8ed
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a0b2f35f930689737acaefc211508db7e9ff6e5f9c31efd1fa2555694d341cbc
              started: "2026-10-16T21:41:15.716Z"
              spawned: false
              bytes: 364033
              windows:
                - start: "2026-10-16T21:41:15.716Z"
                  end: "2026-10-16T16:07:14-07:00"
            - harness: claude
              id: 983bc5e5-6019-4a70-8c51-b5201568013a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8907360015289702272f2f19a536a07201c34e4122278f54a205ee9b6d0daced
              started: "2026-10-16T21:40:54.825Z"
              spawned: false
              bytes: 509772
              windows:
                - start: "2026-10-16T21:40:54.825Z"
                  end: "2026-10-16T16:07:14-07:00"
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: e99a8086a78fb278b361b19639b590739e242ed59fd91c468c4d4e2d5e436d0e
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 17594212
              windows:
                - start: "2026-10-16T11:20:37-07:00"
                  end: "2026-10-16T16:07:14-07:00"
            - harness: claude
              id: af54b6ac-7b02-4fb4-8a7c-8ff23f227998
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a364eb1c98acced3eb731b4929001c967ef685d6feb342a2e39bce102ff7dc66
              started: "2026-10-16T21:39:24.567Z"
              spawned: false
              bytes: 537706
              windows:
                - start: "2026-10-16T21:39:24.567Z"
                  end: "2026-10-16T16:07:14-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 40.262566666666665
        cuts:
            - boundary: M1
              dispatched: "2026-10-16T15:01:45-07:00"
              finalized: "2026-10-16T15:05:02-07:00"
              finalizing: false
            - boundary: M1
              dispatched: "2026-10-16T15:16:17-07:00"
              finalized: "2026-10-16T15:18:45-07:00"
              finalizing: true
            - boundary: M2
              dispatched: "2026-10-16T15:26:05-07:00"
              finalized: "2026-10-16T15:28:34-07:00"
              finalizing: false
            - boundary: M2
              dispatched: "2026-10-16T15:31:01-07:00"
              finalized: "2026-10-16T15:33:54-07:00"
              finalizing: false
            - boundary: M2
              dispatched: "2026-10-16T15:53:28-07:00"
              finalized: "2026-10-16T15:57:38-07:00"
              finalizing: false
      "n": 7
      timestamp: "2026-10-16T16:10:32-07:00"
      dispatched: "2026-10-16T16:08:06-07:00"
      agent: claude
      dispose:
        - id: BR-13
          disposition: addressed
          note: is_side_doc uses frontmatter.parse, discover uses side_path; the new comment and unclosed-block spec cases go red when the old is_side_doc is restored (verified by revert).
          round: 7
        - id: BR-14
          disposition: addressed
          note: Plan Revisions (round 3) restates Core concepts, events, ARCH-CONSTRAINTS, ARCH-ORDER and ARCH-FUNERAL; atlas/ui/attention_finder.md:17-18 states the meaning of new and the open cost, matching discover's since logic.
          round: 7
        - id: BR-15
          disposition: addressed
          note: attention_store.lua:133 names "new side docs" for a batch; attention_store_spec asserts that text, which the old nil-path format fails.
          round: 7
      findings:
        - kind: defect
          id: BR-16
          severity: Minor
          title: A probe whose start raises is recorded as "no Couch ledger for this file"
          detail: async_operation_queue calls finish("filesystem operation raised") when job.start throws (e.g. vim.system ENOENT with no couch on PATH). attention.lua passes that string to M.observation as data; indexing a string's .Status gives nil, so the entry records an invented reason instead of "couch status unavailable". Treat non-table data as nil before observation, and add a spec where run throws.
          family: adopted-owner-contract-unchecked
          round: 7
      boundary: M2
      recipe: milestone-review
      isolation: fenced
      reviewed: 4fdadd497d3754c4d572a44ed7dc60dc658d1732
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

## Round 4 — 2026-10-16T15:28:34-07:00 (claude) — BLOCKED

### Raised

- **BR-8** [Important] `declared-ordering-untested` (kind: defect) The probe-start capture of pending IDs (PQ-2) has no test in the refresh glue
  2nd finding in family declared-ordering-untested. Mutation: in lua/parley/attention.lua:175-178, moving the Store.load()/vim.tbl_keys(entry.pending) capture into the seam.run callback brings back the stale-probe bug, and all 66 mapped specs stay green. Rule: every interleaving in the plan's ARCH-ORDER list needs a test that drives the production glue, not only the pure model. Sweep: two editors (store lease specs), observation after close (covered), failed probe (covered), 14-day trim (same as fold, covered), stale probe vs newer submit (glue UNCOVERED). Fix: in attention_finder_spec, inject a run that holds its callback; while it is held, record and owe m2 and fold m1; then release and assert the entry is still waiting with m2 pending.
- **BR-9** [Minor] `doc-section-misplacement` (kind: defect) keybindings.md: the Attention finder section was inserted above a file-history sentence, which now sits under the wrong heading
  atlas/ui/keybindings.md:41-49: "Markdown buffer preparation consults the read-only restoration scope..." belongs to File history (Back), but now appears under "## Attention finder". The same section also claims "Couch's own key help lists it via pair#619", which this repo cannot check.
- **BR-10** [Minor] `plan-code-drift` (kind: defect) observe_failed records fixed reasons, not the Couch Code the plan specifies
  couch.query returns nil for any Code other than ok, so M.observation (lua/parley/attention.lua:138-143) cannot see the Code. Record this in the plan's Revisions, or pass the Code through.

## Round 5 — 2026-10-16T15:33:54-07:00 (claude) — BLOCKED

### Disposed

- BR-8 — addressed — Mutation verified: moving the capture into the seam.run callback fails "a probe that started before a newer submit leaves that submit waiting"; the other 66 mapped specs stay green; tree restored.
- BR-9 — addressed — atlas/ui/keybindings.md: the restoration-scope sentence is back under File history, and the pair#619 line now reads as pending work ("Adding it to Couch's own key help is pair#619").
- BR-10 — addressed — Plan Revisions (M2 review) records the fixed reasons; lua/parley/couch.lua:41 confirms query returns nil for any Code other than ok, so the Code is not visible to observation.

### Raised

- **BR-11** [Important] `plan-test-strategy-drift` (kind: defect) Task 5's ticked strategy names typeahead and cursor-keeping on repaint, but no spec drives the real float_picker
  2nd finding in the family. Rule: every case a ticked strategy line names maps to a spec driving the production widget, or a Revisions entry records the drop. Sweep of Task 5: typeahead is missing; cursor-keeping is unasserted because the fake update in tests/integration/attention_finder_spec.lua:41 ignores next_selection; the after-close spec tests the fake's own closed guard, not float_picker.lua:1744; the other cases are covered. Fix: one real-float_picker spec (type a filter, land a fold, assert the filter and selection hold), or a Revisions entry narrowing the strategy.
- **BR-12** [Minor] `optional-work-on-critical-path` (kind: defect) Attention probes have no timeout, so a hung couch holds a slot and on_refreshed never fires
  lua/parley/attention.lua:105 calls couch.query, which uses couch.run with no timeout option. The plan's ARCH-CONSTRAINTS calls these short runs but does not bound their duration or extent. Pass a timeout through couch.run and treat expiry as observe_failed.

## Round 6 — 2026-10-16T15:57:38-07:00 (claude) — BLOCKED

### Disposed

- BR-11 — addressed — The real-float_picker spec "keeps the typed filter and the selected row across a live repaint" drives typeahead, cursor-keeping and Enter. Reverting update's third argument fails it (tested in the checkout). The after-close case now also runs on the real picker.
- BR-12 — addressed — couch.query passes options through to vim.system, and refresh sets timeout 5000. The spec "a probe that outlives its timeout reads as failed" uses the fake's delay mode; removing the timeout fails it (tested in the checkout).

### Raised

- **BR-13** [Important] `reuse-existing-owner` (kind: defect) attention.is_side_doc and discover re-implement frontmatter.parse and document_move_plan.side_path, and disagree with them
  lua/parley/attention.lua:120-128 hand-parses frontmatter. Compared with parley.frontmatter.parse (used by session_sync.parse_header), it misses `type: side-doc # comment`, accepts an unclosed fence, and does not lower-case the key. attention.lua:140 rebuilds the side folder with fnamemodify(":r") instead of document_move_plan.side_path (document_move_plan.lua:28). Fix: use frontmatter.parse(head).fields.type == "side-doc" and side_path(entry.path), and add a spec case with a trailing comment. Rule: a fact the codebase already parses or derives is read through its existing owner.
- **BR-14** [Minor] `plan-code-drift` (kind: defect) The side-doc addition left the plan's ARCH-CONSTRAINTS and the atlas's "only new files" claim out of date
  This is the 2nd plan-code-drift finding. Rule: a scope addition re-checks every cross-cutting plan section (Core concepts state/events, ARCH-CONSTRAINTS, ARCH-ORDER, ARCH-FUNERAL) and the atlas claims, and updates each it changes. Here, the finder now renders only after a sweep write, a synchronous scan of up to 256 .side folders, and a batch write, but the plan still says "reads one file and renders at once". The atlas says rewrites don't count, yet a side doc that predates its parent's entry is discovered once rewritten (the check is mtime > recorded_at).
- **BR-15** [Minor] `warning-names-missing-subject` (kind: defect) A refused side-doc batch warns "256 files are waiting; nil was not recorded" on every open
  attention_store.lua:133 formats event.path, which a batch event has no value for. Name the dropped side docs, or say "side docs" when the event is a batch.

## Round 7 — 2026-10-16T16:10:32-07:00 (claude) — passed

### Disposed

- BR-13 — addressed — is_side_doc uses frontmatter.parse, discover uses side_path; the new comment and unclosed-block spec cases go red when the old is_side_doc is restored (verified by revert).
- BR-14 — addressed — Plan Revisions (round 3) restates Core concepts, events, ARCH-CONSTRAINTS, ARCH-ORDER and ARCH-FUNERAL; atlas/ui/attention_finder.md:17-18 states the meaning of new and the open cost, matching discover's since logic.
- BR-15 — addressed — attention_store.lua:133 names "new side docs" for a batch; attention_store_spec asserts that text, which the old nil-path format fails.

### Raised

- **BR-16** [Minor] `adopted-owner-contract-unchecked` (kind: defect) A probe whose start raises is recorded as "no Couch ledger for this file"
  async_operation_queue calls finish("filesystem operation raised") when job.start throws (e.g. vim.system ENOENT with no couch on PATH). attention.lua passes that string to M.observation as data; indexing a string's .Status gives nil, so the entry records an invented reason instead of "couch status unavailable". Treat non-table data as nil before observation, and add a spec where run throws.

## Open findings

- **BR-6** [Minor] `docs-gate-plan-gap` (kind: defect) Plan Task 6 omits a README update for the finder's chord, command and attention.seen_grace_minutes
- **BR-7** [Minor] `fake-conformance-gap` (kind: defect) No conformance check pins the couch --send-to receipt line that parse_message_id depends on
- **BR-16** [Minor] `adopted-owner-contract-unchecked` (kind: defect) A probe whose start raises is recorded as "no Couch ledger for this file"
