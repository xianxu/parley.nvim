---
gate: boundary-review
issue: 414
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d4d1468b-5b29-4d70-aabb-0f3543125669
            repository: github.com/xianxu/parley.nvim
            issue_id: "000414"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/048660e0440cc80f
            reviewed_head: 1fe9891317280631e212d378ebc0ac1b9a6c9bc4
            slot: parley.nvim:1
            requested_at: "2026-10-23T18:39:08.740518Z"
          phase: finished
          pid: 60523
          started_at: "2026-10-23T18:39:08.875981Z"
          finished_at: "2026-10-23T18:43:51.818694Z"
          session_id: f2c13075-678d-44ba-a84e-734dd3a900c9
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 1fe9891317280631e212d378ebc0ac1b9a6c9bc4
        tracker_head: e346e4a9f31ece1635e71024e967a67ca1914be6
        branch_point: 20f3513ba4febf46479a9081fa5e00761531aeea
        since: "2026-10-23T05:49:02-07:00"
        until: "2026-10-23T11:38:31-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T05:49:02-07:00"
              end: "2026-10-23T11:38:31-07:00"
              began: "2026-10-23T05:49:02-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 7ff89450ae3e14632338eea0c4bde9eecc37847d382803a96b945ee7e1b6b552
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 5516392
              windows:
                - start: "2026-10-23T05:49:02-07:00"
                  end: "2026-10-23T11:38:31-07:00"
        queue_waits:
            - attempt_id: 7cd79e2bae17dc53b8944d14e9f0b892
              slot: parley.nvim:1
              record_digest: d709cc00cbf9ed7c300fd0fd02e942a041310ce6c394daf30ad9f44cf4af5bc3
              start: "2026-10-23T17:15:25.956178Z"
              end: "2026-10-23T18:20:39.24136Z"
              queue_seconds: 3913.285182
              raw_seconds: 3913.285182
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.241266666666666
      "n": 1
      timestamp: "2026-10-23T11:43:53-07:00"
      dispatched: "2026-10-23T11:39:08-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Row 1 passes with a synchronous Couch wait that the move timeout cuts off; the wall-clock bound was dropped
          detail: 'I injected a bounded_request("lookup") whose result is ignored before the move begins in lua/parley/agentic_document.lua (~line 1030). Registered :saveas blocked for 5169 ms and agentic_document_spec still passed 48/0/0. With a 60 s gate and a 5000 ms move timeout, the cut-off wait leaves the operation pending and the identity unmoved, so lines 268-269 pass. Fix: set FAKE_COUCH_REGISTRY_DELAY below agentic_move_timeout_ms (for example 2 s against 5000 ms) so any synchronous wait receives the answer and the causal asserts fail. Same family in this window: rows 1/5 move_path (timeout 500, 60 s gate), row 3 and row 4 (err == why also holds after a cut-off wait). Add this regression as a negative control for each row.'
          family: causal-gate-outlasts-timeout
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Row 2's new trace assertion has no negative control and passes when the trace is empty
          detail: Done-when asks for a negative control, but the plan ran controls only for rows 1, 3 and 4. The loop at agentic_document_spec.lua:286-290 passes on an empty trace, so an asynchronous non-lookup request whose fake process has not yet written its trace line is not caught. Run a control (for example a background rename on the plain path) and record it, or document the race in the comment.
          family: negative-control-per-changed-assertion
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: A gate path with no directory part opens at once (isdir("") is false)
          detail: tests/fixtures/fake_couch_registry.py:161. Harmless with the current callers, but the behaviour is silent; treat an empty dirname as "."
          family: gate-path-edge
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: f53b5f40-4265-4ba6-ab43-5055a0f6ad5b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000414"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/1ee0f0c771f24c0e
            reviewed_head: b11e2e9ce3838fdba088932557e6425ad68b930c
            slot: parley.nvim:1
            requested_at: "2026-10-23T19:13:06.257819Z"
          phase: finished
          pid: 69284
          started_at: "2026-10-23T19:13:06.449147Z"
          finished_at: "2026-10-23T19:23:25.120319Z"
          session_id: 41235509-8a97-44f6-9ebc-c4f21e6186e3
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: b11e2e9ce3838fdba088932557e6425ad68b930c
        tracker_head: e346e4a9f31ece1635e71024e967a67ca1914be6
        branch_point: 28526aa8eefe4da49b28bac04456f56e564ecaf2
        since: "2026-10-23T05:49:02-07:00"
        until: "2026-10-23T12:00:04-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T05:49:02-07:00"
              end: "2026-10-23T12:00:04-07:00"
              began: "2026-10-23T05:49:02-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 9ed91273d6394a5622599ebb918366e536bfe9d4b92c107a95e04097cca67d87
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 5955020
              windows:
                - start: "2026-10-23T05:49:02-07:00"
                  end: "2026-10-23T12:00:04-07:00"
        queue_waits:
            - attempt_id: 7cd79e2bae17dc53b8944d14e9f0b892
              slot: parley.nvim:1
              record_digest: d709cc00cbf9ed7c300fd0fd02e942a041310ce6c394daf30ad9f44cf4af5bc3
              start: "2026-10-23T17:15:25.956178Z"
              end: "2026-10-23T18:20:39.24136Z"
              queue_seconds: 3913.285182
              raw_seconds: 3913.285182
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.241266666666666
        cuts:
            - dispatched: "2026-10-23T11:39:08-07:00"
              finalized: "2026-10-23T11:43:53-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-23T12:23:26-07:00"
      dispatched: "2026-10-23T12:13:06-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Re-injected the ignored bounded_request("lookup") before begin; row 1 now fails at unanswered (47/1/0); reverted 48/0/0. Rows 3/4 fail under an ignored sync wait in move_membership.
          round: 2
        - id: BR-2
          disposition: addressed
          note: 'Negative control run: plain BufFilePost waiting on bounded_request lookup of the target fails row 2 at unanswered (47/1/0); empty-trace race documented at spec:298-302.'
          round: 2
        - id: BR-3
          disposition: addressed
          note: fake_couch_registry.py:161,164 now use os.path.dirname(gate) or ".".
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: Spec comment says any sync wait outlasts GATE_MS, but row 1/5 deadlines are at or below it
          detail: '2nd in family. agentic_document_spec.lua:103-104 claims every synchronous wait gets an answer before giving up. In rows 1/5 (submit timeout 1000) the rename deadline is 3x1000 = 3000 ms = GATE_MS and other requests get 1000 ms (document_registry.lua:26,34), so a wait cut off there leaves no answer record; those rows rely on the operation-pending check (control E). Every instance in the window: rows 1/5 only; rows 1, 2, 3 and 4 use 15000 ms. Rule: GATE_MS must be below every deadline in force in a gated row (move timeout, submit timeout, 3x submit). Either gate_couch asserts it, or the comment names the rows that are guarded by the pending check instead.'
          family: causal-gate-outlasts-timeout
          round: 2
        - kind: defect
          id: BR-5
          severity: Minor
          title: gate_couch changes agentic_move_timeout_ms without saving the old value
          detail: 'agentic_document_spec.lua:111. The value is restored only because every caller runs with_timeouts first, which saves the old value. A gated row without with_timeouts would leak the 6 s move timeout into later cases. Fix: call with_timeouts inside gate_couch, or save the old value there.'
          family: fixture-config-restore
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: b11e2e9ce3838fdba088932557e6425ad68b930c
      blocked: false
---

# Gate ledger — parley.nvim#414 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T11:43:53-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `causal-gate-outlasts-timeout` (kind: defect) Row 1 passes with a synchronous Couch wait that the move timeout cuts off; the wall-clock bound was dropped
  I injected a bounded_request("lookup") whose result is ignored before the move begins in lua/parley/agentic_document.lua (~line 1030). Registered :saveas blocked for 5169 ms and agentic_document_spec still passed 48/0/0. With a 60 s gate and a 5000 ms move timeout, the cut-off wait leaves the operation pending and the identity unmoved, so lines 268-269 pass. Fix: set FAKE_COUCH_REGISTRY_DELAY below agentic_move_timeout_ms (for example 2 s against 5000 ms) so any synchronous wait receives the answer and the causal asserts fail. Same family in this window: rows 1/5 move_path (timeout 500, 60 s gate), row 3 and row 4 (err == why also holds after a cut-off wait). Add this regression as a negative control for each row.
- **BR-2** [Important] `negative-control-per-changed-assertion` (kind: defect) Row 2's new trace assertion has no negative control and passes when the trace is empty
  Done-when asks for a negative control, but the plan ran controls only for rows 1, 3 and 4. The loop at agentic_document_spec.lua:286-290 passes on an empty trace, so an asynchronous non-lookup request whose fake process has not yet written its trace line is not caught. Run a control (for example a background rename on the plain path) and record it, or document the race in the comment.
- **BR-3** [Minor] `gate-path-edge` (kind: defect) A gate path with no directory part opens at once (isdir("") is false)
  tests/fixtures/fake_couch_registry.py:161. Harmless with the current callers, but the behaviour is silent; treat an empty dirname as "."

## Round 2 — 2026-10-23T12:23:26-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Re-injected the ignored bounded_request("lookup") before begin; row 1 now fails at unanswered (47/1/0); reverted 48/0/0. Rows 3/4 fail under an ignored sync wait in move_membership.
- BR-2 — addressed — Negative control run: plain BufFilePost waiting on bounded_request lookup of the target fails row 2 at unanswered (47/1/0); empty-trace race documented at spec:298-302.
- BR-3 — addressed — fake_couch_registry.py:161,164 now use os.path.dirname(gate) or ".".

### Raised

- **BR-4** [Minor] `causal-gate-outlasts-timeout` (kind: defect) Spec comment says any sync wait outlasts GATE_MS, but row 1/5 deadlines are at or below it
  2nd in family. agentic_document_spec.lua:103-104 claims every synchronous wait gets an answer before giving up. In rows 1/5 (submit timeout 1000) the rename deadline is 3x1000 = 3000 ms = GATE_MS and other requests get 1000 ms (document_registry.lua:26,34), so a wait cut off there leaves no answer record; those rows rely on the operation-pending check (control E). Every instance in the window: rows 1/5 only; rows 1, 2, 3 and 4 use 15000 ms. Rule: GATE_MS must be below every deadline in force in a gated row (move timeout, submit timeout, 3x submit). Either gate_couch asserts it, or the comment names the rows that are guarded by the pending check instead.
- **BR-5** [Minor] `fixture-config-restore` (kind: defect) gate_couch changes agentic_move_timeout_ms without saving the old value
  agentic_document_spec.lua:111. The value is restored only because every caller runs with_timeouts first, which saves the old value. A gated row without with_timeouts would leak the 6 s move timeout into later cases. Fix: call with_timeouts inside gate_couch, or save the old value there.

## Open findings

- **BR-4** [Minor] `causal-gate-outlasts-timeout` (kind: defect) Spec comment says any sync wait outlasts GATE_MS, but row 1/5 deadlines are at or below it
- **BR-5** [Minor] `fixture-config-restore` (kind: defect) gate_couch changes agentic_move_timeout_ms without saving the old value
