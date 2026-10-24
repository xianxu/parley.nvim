---
gate: boundary-review
issue: 425
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ffacbe09-3a01-4c02-ad4e-e0624b39a0a6
            repository: github.com/xianxu/parley.nvim
            issue_id: "000425"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/d334469990eddf55
            reviewed_head: 4a0a48cf59449683f1672a0062f57db6f28b4e2d
            slot: parley.nvim:2
            requested_at: "2026-10-23T19:45:35.900235Z"
          phase: finished
          pid: 95105
          started_at: "2026-10-23T19:45:36.065997Z"
          finished_at: "2026-10-23T19:49:32.226935Z"
          session_id: 01a16a4c-21ad-7d00-b3bd-cefd09c15be0
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4a0a48cf59449683f1672a0062f57db6f28b4e2d
        tracker_head: 6b2e30f8e13a63c728c83b3a1b603c40b8993981
        branch_point: 5958d5f2aa7899ed3fb6b141ec4ca6a21aa8c32b
        since: "2026-10-23T12:32:20-07:00"
        until: "2026-10-23T12:44:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T12:32:20-07:00"
              end: "2026-10-23T12:44:53-07:00"
              began: "2026-10-23T12:32:20-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: ae129c732511c196645bbd600717a97557fb4b2289f407c71626b47df8cb1c34
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 77946594
              windows:
                - start: "2026-10-23T12:32:20-07:00"
                  end: "2026-10-23T12:44:53-07:00"
      "n": 1
      timestamp: "2026-10-23T12:49:33-07:00"
      dispatched: "2026-10-23T12:45:35-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: No-target Alt+o moves the Insert-mode cursor left
          detail: 'lua/parley/init.lua:5150–5152 restores Insert mode after stopinsert without restoring the insertion position. Native mapping probes starting at zero-based columns 1, 2 and 4 in "error" resume at columns 0, 1 and 3 respectively, so subsequent typing changes location. The sole new on_no_file callback is the affected site; sweep nonzero positions, including end-of-line, across absent/custom bars. Preserve the original insertion position through mode restoration and add native regressions; existing cases only exercise column zero. ARCH-PURPOSE: a no-target gesture must preserve editing position.'
          family: preserve-edit-position-on-noop
          round: 1
        - kind: defect
          id: BR-2
          severity: Critical
          title: A no-target pulse suppresses the unsubmitted-turn leave reminder
          detail: 'lua/parley/document_band.lua:233 coalesces requests solely by source buffer, so flash_notice and flash for the same source are treated as equivalent. All four interaction probes fail: queued/active notice crossed with buffer departure/WinLeave produces zero unsubmitted warnings instead of one, violating README.md:88–92. These are the two entry points sharing this guard. Distinguish pulse purpose and let leave feedback supersede a quiet notice while retaining duplicate leave-event coalescing; cover all four combinations. ARCH-PURPOSE: reuse must preserve the existing reminder contract.'
          family: coalesce-only-equivalent-feedback
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: README update appears missing for Alt+o no-target feedback
          detail: README.md:252–266 documents Alt+o and its native fallback, but the pinned range contains no README change describing the new quiet flash and temporary-bar restoration. This is the only changed user-facing gesture in the window; atlas/context/file_references.md:61–64 already documents it. Add the corresponding README explanation to satisfy the requested docs gate.
          family: document-user-visible-behavior
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 24d3cc93-3d3f-43af-824d-5762bf11dd70
            repository: github.com/xianxu/parley.nvim
            issue_id: "000425"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/a8ea9196da5a8e62
            reviewed_head: 3f9321f80a8aff88078f4d30f69c04637b8586ed
            slot: parley.nvim:2
            requested_at: "2026-10-24T02:32:18.834048Z"
          phase: finished
          pid: 54753
          started_at: "2026-10-24T02:32:18.988112Z"
          finished_at: "2026-10-24T02:34:52.555704Z"
          session_id: 01a16bc0-7cea-76b1-8b56-57d3438f2159
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3f9321f80a8aff88078f4d30f69c04637b8586ed
        tracker_head: 209a40f9cfa70681299f768cccd5c725fba3fb58
        branch_point: 5958d5f2aa7899ed3fb6b141ec4ca6a21aa8c32b
        since: "2026-10-23T12:32:20-07:00"
        until: "2026-10-23T19:31:26-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T12:32:20-07:00"
              end: "2026-10-23T19:31:26-07:00"
              began: "2026-10-23T12:32:20-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: cd4291a08ff154812ed7c8a495961407a5caaa5f271ade7e99c7aba7fbf71d89
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 78496167
              windows:
                - start: "2026-10-23T12:32:20-07:00"
                  end: "2026-10-23T19:31:26-07:00"
        queue_waits:
            - attempt_id: b55f8e0de7d3b4b2ffd06a83b4efba87
              slot: parley.nvim:2
              record_digest: c397361cc1ee03f72b59cca75365780342aa8f62a8bbd46f12591dc6bd641530
              start: "2026-10-23T19:45:12.469664Z"
              end: "2026-10-23T20:53:46.674704Z"
              queue_seconds: 4114.20504
              raw_seconds: 4114.20504
              exact: true
        cuts:
            - dispatched: "2026-10-23T12:45:35-07:00"
              finalized: "2026-10-23T12:49:33-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-23T19:34:54-07:00"
      dispatched: "2026-10-23T19:32:18-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: tests/integration/navigation_no_target_spec.lua:163–184 covers 12 insertion-position cases across absent/custom bars, nonzero columns, EOL and UTF-8. All pass at head and fail when position restoration is reverted.
          round: 2
        - id: BR-2
          disposition: addressed
          note: tests/integration/lock_leave_reminder_spec.lua:263–294 covers four notice/departure combinations and two reverse-priority cases. All pass at head and fail when purpose-aware coalescing is reverted.
          round: 2
        - id: BR-3
          disposition: addressed
          note: README.md:265–268 now documents quiet no-target feedback, prior-bar restoration and retained diagnostics, matching lua/parley/init.lua:5153–5155 and lua/parley/document_band.lua:232–287.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 3f9321f80a8aff88078f4d30f69c04637b8586ed
      blocked: false
---

# Gate ledger — parley.nvim#425 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T12:49:33-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `preserve-edit-position-on-noop` (kind: defect) No-target Alt+o moves the Insert-mode cursor left
  lua/parley/init.lua:5150–5152 restores Insert mode after stopinsert without restoring the insertion position. Native mapping probes starting at zero-based columns 1, 2 and 4 in "error" resume at columns 0, 1 and 3 respectively, so subsequent typing changes location. The sole new on_no_file callback is the affected site; sweep nonzero positions, including end-of-line, across absent/custom bars. Preserve the original insertion position through mode restoration and add native regressions; existing cases only exercise column zero. ARCH-PURPOSE: a no-target gesture must preserve editing position.
- **BR-2** [Critical] `coalesce-only-equivalent-feedback` (kind: defect) A no-target pulse suppresses the unsubmitted-turn leave reminder
  lua/parley/document_band.lua:233 coalesces requests solely by source buffer, so flash_notice and flash for the same source are treated as equivalent. All four interaction probes fail: queued/active notice crossed with buffer departure/WinLeave produces zero unsubmitted warnings instead of one, violating README.md:88–92. These are the two entry points sharing this guard. Distinguish pulse purpose and let leave feedback supersede a quiet notice while retaining duplicate leave-event coalescing; cover all four combinations. ARCH-PURPOSE: reuse must preserve the existing reminder contract.
- **BR-3** [Important] `document-user-visible-behavior` (kind: defect) README update appears missing for Alt+o no-target feedback
  README.md:252–266 documents Alt+o and its native fallback, but the pinned range contains no README change describing the new quiet flash and temporary-bar restoration. This is the only changed user-facing gesture in the window; atlas/context/file_references.md:61–64 already documents it. Add the corresponding README explanation to satisfy the requested docs gate.

## Round 2 — 2026-10-23T19:34:54-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — tests/integration/navigation_no_target_spec.lua:163–184 covers 12 insertion-position cases across absent/custom bars, nonzero columns, EOL and UTF-8. All pass at head and fail when position restoration is reverted.
- BR-2 — addressed — tests/integration/lock_leave_reminder_spec.lua:263–294 covers four notice/departure combinations and two reverse-priority cases. All pass at head and fail when purpose-aware coalescing is reverted.
- BR-3 — addressed — README.md:265–268 now documents quiet no-target feedback, prior-bar restoration and retained diagnostics, matching lua/parley/init.lua:5153–5155 and lua/parley/document_band.lua:232–287.

## Open findings

(none — every finding has been disposed)
