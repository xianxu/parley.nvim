---
gate: boundary-review
issue: 229
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 5c9dfbef-489b-43b1-94fd-2f2ada1c4f31
            repository: github.com/xianxu/parley.nvim
            issue_id: "000229"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b596d96584e6aad6
            reviewed_head: af12fe1db4fdeaea47cb9eefee7acd8058c82208
            slot: parley.nvim:3
            requested_at: "2026-10-16T02:03:00.323684Z"
          phase: finished
          pid: 60996
          started_at: "2026-10-16T02:03:00.423781Z"
          finished_at: "2026-10-16T02:04:47.445939Z"
          session_id: 65ca19ee-0f47-484f-ab09-7ded2e13d806
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: af12fe1db4fdeaea47cb9eefee7acd8058c82208
        tracker_head: 803cd288813e9b51749b17f37e9a277b25749fc3
        branch_point: 7762f5ed3250dcb14863617c89cbd3e5d81e0480
        since: "2026-10-15T18:29:35-07:00"
        until: "2026-10-15T19:02:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T18:29:35-07:00"
              end: "2026-10-15T19:02:21-07:00"
              began: "2026-10-15T18:29:35-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 21881f23a905f21e73abb6a965367a3db476d7998e4727df33f583ab30d15a83
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 3080941
              windows:
                - start: "2026-10-15T18:29:35-07:00"
                  end: "2026-10-15T19:02:21-07:00"
      "n": 1
      timestamp: "2026-10-15T19:04:47-07:00"
      dispatched: "2026-10-15T19:03:00-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: tasker read() comment claims EOF is delivered once, but the err path delivers it twice
          detail: On (err, nil), deliver() calls read(stream, reader, err, nil), then the callback calls read(stream, reader, nil, nil) again (tasker.lua:629 and 644). This double delivery predates the change, but the new comment at tasker.lua:609-610 states the opposite. Fix the comment, or skip the second call when deliver already passed nil data.
          family: comment-contract-drift
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Reader failure is tracked with closure flags (failed_readers, io_error), not an attempt event (ARCH-ORDER)
          detail: This matches the existing retention-limit pattern, but it widens the set of flags kept outside the record's event model. Consider a reader_failed event. Also note in the atlas that a throwing stderr reader now stops an otherwise healthy stdout stream.
          family: attempt-state-outside-transition-model
          round: 1
        - kind: unverifiable
          id: BR-3
          severity: Minor
          title: 'Plan item "Filed #341 for the two silent-stall paths" cannot be verified in the pinned checkout'
          detail: 'Searching workshop/issues/ and git log --all for 000341 in the review checkout found nothing. Evidence that would answer it: the path or commit of #341 on main, or the tracker URL.'
          family: plan-claim-evidence
          round: 1
      recipe: milestone-review
      isolation: checkout
      reviewed: af12fe1db4fdeaea47cb9eefee7acd8058c82208
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 9ca0c38d-9502-49cf-ae98-63b4ed971485
            repository: github.com/xianxu/parley.nvim
            issue_id: "000229"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/d3ec4e7c712e7bcb
            reviewed_head: 9d987af401a5af70aa599b5d5d3a76f7916c8d57
            slot: parley.nvim:3
            requested_at: "2026-10-16T02:06:41.175938Z"
          phase: finished
          pid: 79464
          started_at: "2026-10-16T02:06:41.273871Z"
          finished_at: "2026-10-16T02:07:56.665286Z"
          session_id: 80d13250-be50-4a21-bf9e-0ca9b8b64946
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9d987af401a5af70aa599b5d5d3a76f7916c8d57
        tracker_head: 487e67e80db72df793b04d1b2146bd51ab69b1af
        branch_point: bc2df5b3a8b69b6ea0dccc2be6f462e4150099de
        since: "2026-10-15T18:29:35-07:00"
        until: "2026-10-15T19:06:25-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T18:29:35-07:00"
              end: "2026-10-15T19:06:25-07:00"
              began: "2026-10-15T18:29:35-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: b6cfcf6be796c1abdeec7bab21a621e795246e4c99be4e2ab03a3ce5d1392ce8
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 3197617
              windows:
                - start: "2026-10-15T18:29:35-07:00"
                  end: "2026-10-15T19:06:25-07:00"
        cuts:
            - dispatched: "2026-10-15T19:03:00-07:00"
              finalized: "2026-10-15T19:04:47-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-15T19:07:58-07:00"
      dispatched: "2026-10-15T19:06:41-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: tasker.lua:609-612 now describes the real sequence, one (err, nil) notice then exactly one (nil, nil) EOF; tasker_run_spec.lua:617 pins it and passes 43/0.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: Still closure flags (failed_readers, io_error) outside the attempt event model; deliberately kept, same shape as the retention limit; atlas line covers reader-failure stops; Minor, non-blocking.
          round: 2
        - id: BR-3
          disposition: withdrawn
          note: workshop/issues/000341-generation-machine-rejects-some-output-and-receipt-events-without-an-outcome-possibly-hanging-the-generation.md exists in the checkout, filed in commit bc2df5b3 (the base).
          round: 2
      recipe: milestone-review
      isolation: checkout
      reviewed: 9d987af401a5af70aa599b5d5d3a76f7916c8d57
      blocked: false
---

# Gate ledger — parley.nvim#229 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T19:04:47-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `comment-contract-drift` (kind: defect) tasker read() comment claims EOF is delivered once, but the err path delivers it twice
  On (err, nil), deliver() calls read(stream, reader, err, nil), then the callback calls read(stream, reader, nil, nil) again (tasker.lua:629 and 644). This double delivery predates the change, but the new comment at tasker.lua:609-610 states the opposite. Fix the comment, or skip the second call when deliver already passed nil data.
- **BR-2** [Minor] `attempt-state-outside-transition-model` (kind: defect) Reader failure is tracked with closure flags (failed_readers, io_error), not an attempt event (ARCH-ORDER)
  This matches the existing retention-limit pattern, but it widens the set of flags kept outside the record's event model. Consider a reader_failed event. Also note in the atlas that a throwing stderr reader now stops an otherwise healthy stdout stream.
- **BR-3** [Minor] `plan-claim-evidence` (kind: unverifiable) Plan item "Filed #341 for the two silent-stall paths" cannot be verified in the pinned checkout
  Searching workshop/issues/ and git log --all for 000341 in the review checkout found nothing. Evidence that would answer it: the path or commit of #341 on main, or the tracker URL.

## Round 2 — 2026-10-15T19:07:58-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — tasker.lua:609-612 now describes the real sequence, one (err, nil) notice then exactly one (nil, nil) EOF; tasker_run_spec.lua:617 pins it and passes 43/0.
- BR-2 — not-addressed — Still closure flags (failed_readers, io_error) outside the attempt event model; deliberately kept, same shape as the retention limit; atlas line covers reader-failure stops; Minor, non-blocking.
- BR-3 — withdrawn — workshop/issues/000341-generation-machine-rejects-some-output-and-receipt-events-without-an-outcome-possibly-hanging-the-generation.md exists in the checkout, filed in commit bc2df5b3 (the base).

## Open findings

- **BR-2** [Minor] `attempt-state-outside-transition-model` (kind: defect) Reader failure is tracked with closure flags (failed_readers, io_error), not an attempt event (ARCH-ORDER)
