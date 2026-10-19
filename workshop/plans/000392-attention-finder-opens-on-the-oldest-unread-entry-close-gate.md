---
gate: boundary-review
issue: 392
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d992a290-aad6-4ed5-956c-575ce8691190
            repository: github.com/xianxu/parley.nvim
            issue_id: "000392"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/47c2a01792fb2823
            reviewed_head: 9c8302396111b0e2904588ef2f172cf729b6929f
            slot: parley.nvim:2
            requested_at: "2026-10-19T04:46:46.014017Z"
          phase: finished
          pid: 59869
          started_at: "2026-10-19T04:46:46.285873Z"
          finished_at: "2026-10-19T04:48:36.602729Z"
          session_id: 01a1527b-cac9-7820-8b7a-76b211de471d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9c8302396111b0e2904588ef2f172cf729b6929f
        tracker_head: bb6a71506d0126d6cc0fed8a804d686a24b88fe3
        branch_point: 1d4abae2f61a377d6dfbc17357c8f0250f0cce79
        since: "2026-10-18T20:51:22-07:00"
        until: "2026-10-18T21:46:01-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T20:51:22-07:00"
              end: "2026-10-18T21:46:01-07:00"
              began: "2026-10-18T20:51:22-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 291a7a25d881f36fd5a81198b2636a47a99509cd3e558aea5f86f9253ab80ff5
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 60887911
              windows:
                - start: "2026-10-18T20:51:22-07:00"
                  end: "2026-10-18T21:46:01-07:00"
        queue_waits:
            - attempt_id: 98aa813ae583e38b31231ae09ca15a3a
              slot: parley.nvim:2
              record_digest: 363ec7e0623540d31537b719adda05416599960cb0a92e146fad0d113aca357d
              start: "2026-10-19T03:56:03.783353Z"
              end: "2026-10-19T04:36:13.732394Z"
              queue_seconds: 2409.949041
              raw_seconds: 2409.949041
              exact: true
      "n": 1
      timestamp: "2026-10-18T21:48:40-07:00"
      dispatched: "2026-10-18T21:46:46-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Background refresh hides the initially selected unread entry
          detail: 'At lua/parley/float_picker.lua:1771-1775, update calls apply_filter(false), whose set_selection(sel_idx) resets the top-anchored viewport to row 1; preserve_view then preserves that reset viewport. Reproduced in a disposable pinned-head copy by completing a held waiting probe immediately after attention_finder_spec.lua:149: child.md remains selected, but visible() fails. Family enumeration: successful and failed probe repaints share attention.lua:306; both current-slot and all-slot views, including views reached through scope toggles, use this path. Preserve the viewport across the complete update and test below-fold selection through probe completion in both scopes. ARCH-PURPOSE: opening focus must remain usable when the automatically started refresh lands.'
          family: picker-repaint-preserves-viewport
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 5b2ecc25-7a1d-4e02-b7c6-83677796b85a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000392"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b48656dd771f1716
            reviewed_head: 2302826c8848bb0eac245f1009d759112adb9d5d
            slot: parley.nvim:2
            requested_at: "2026-10-19T09:16:37.015591Z"
          phase: finished
          pid: 89025
          started_at: "2026-10-19T09:16:37.109582Z"
          finished_at: "2026-10-19T09:18:41.170409Z"
          session_id: 01a15372-d66c-7851-bdbc-ef1eeca2d693
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2302826c8848bb0eac245f1009d759112adb9d5d
        tracker_head: b814fa166c66f9ef8b3c7fd9065f87aa245009fd
        branch_point: 1d4abae2f61a377d6dfbc17357c8f0250f0cce79
        since: "2026-10-18T20:51:22-07:00"
        until: "2026-10-19T02:16:22-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T20:51:22-07:00"
              end: "2026-10-19T02:16:22-07:00"
              began: "2026-10-18T20:51:22-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 8545ce264bf1047447e65fb9289bc5fe4e20a8a7e88c6da58137723be35decce
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 61295681
              windows:
                - start: "2026-10-18T20:51:22-07:00"
                  end: "2026-10-19T02:16:22-07:00"
        queue_waits:
            - attempt_id: 98aa813ae583e38b31231ae09ca15a3a
              slot: parley.nvim:2
              record_digest: 363ec7e0623540d31537b719adda05416599960cb0a92e146fad0d113aca357d
              start: "2026-10-19T03:56:03.783353Z"
              end: "2026-10-19T04:36:13.732394Z"
              queue_seconds: 2409.949041
              raw_seconds: 2409.949041
              exact: true
            - attempt_id: 415d756217a4009576077310a0ea40c6
              slot: parley.nvim:2
              record_digest: 7f0796863db06d8c6a6967fcfc2abadeb356843d91704d0dcc63a8138596936f
              start: "2026-10-19T09:10:42.020067Z"
              end: "2026-10-19T09:10:42.091334Z"
              queue_seconds: 0.071267
              raw_seconds: 0.071267
              exact: true
        cuts:
            - dispatched: "2026-10-18T21:46:46-07:00"
              finalized: "2026-10-18T21:48:40-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-19T02:18:45-07:00"
      dispatched: "2026-10-19T02:16:37-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: float_picker.lua:1743 captures the viewport before reflow/refilter and reuses it through identity restoration. Native regressions cover successful/failed probes with below-fold targets in both scopes. Replacing the picker with its pre-fix version produces 32 passing tests and two visibility failures at attention_finder_spec.lua:145; pinned head passes all 34.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 2302826c8848bb0eac245f1009d759112adb9d5d
      blocked: false
---

# Gate ledger — parley.nvim#392 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T21:48:40-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `picker-repaint-preserves-viewport` (kind: defect) Background refresh hides the initially selected unread entry
  At lua/parley/float_picker.lua:1771-1775, update calls apply_filter(false), whose set_selection(sel_idx) resets the top-anchored viewport to row 1; preserve_view then preserves that reset viewport. Reproduced in a disposable pinned-head copy by completing a held waiting probe immediately after attention_finder_spec.lua:149: child.md remains selected, but visible() fails. Family enumeration: successful and failed probe repaints share attention.lua:306; both current-slot and all-slot views, including views reached through scope toggles, use this path. Preserve the viewport across the complete update and test below-fold selection through probe completion in both scopes. ARCH-PURPOSE: opening focus must remain usable when the automatically started refresh lands.

## Round 2 — 2026-10-19T02:18:45-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — float_picker.lua:1743 captures the viewport before reflow/refilter and reuses it through identity restoration. Native regressions cover successful/failed probes with below-fold targets in both scopes. Replacing the picker with its pre-fix version produces 32 passing tests and two visibility failures at attention_finder_spec.lua:145; pinned head passes all 34.

## Open findings

(none — every finding has been disposed)
