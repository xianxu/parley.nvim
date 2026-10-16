---
gate: boundary-review
issue: 340
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ecaa27d9-5766-4e3b-bd21-4694b33934d8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000340"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/4bf9c3850f1a8162
            reviewed_head: 0c2547f885692b5335c041c7f82c76114c3e3372
            slot: parley.nvim:4
            requested_at: "2026-10-16T07:22:47.085008Z"
          phase: finished
          pid: 15154
          started_at: "2026-10-16T07:22:47.635553Z"
          finished_at: "2026-10-16T07:25:31.570166Z"
          session_id: 3e9eb47b-31ee-45cf-b6f1-fe3201cb748a
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0c2547f885692b5335c041c7f82c76114c3e3372
        tracker_head: bfdaf38ecb15f90fdba07f619c2d57d623e2695a
        branch_point: 30a94402e6a3978a2ce58fbf795dc3eee9389d2d
        since: "2026-10-15T23:44:45-07:00"
        until: "2026-10-16T00:09:11-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T23:44:45-07:00"
              end: "2026-10-16T00:09:11-07:00"
              began: "2026-10-15T23:44:45-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: cc62c8d6d252608be7b5fdc66a04f4631e184d2fb4bcd925ccf45f92a883b255
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 3325547
              windows:
                - start: "2026-10-15T23:44:45-07:00"
                  end: "2026-10-16T00:09:11-07:00"
      "n": 1
      timestamp: "2026-10-16T00:25:34-07:00"
      dispatched: "2026-10-16T00:22:47-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: '"Old process gone, so the port is free" holds only for signalled pids; a peer on the port is no longer probed'
          detail: 'restart_managed (lua/parley/cliproxy.lua:533-541) skips every port probe once the pids returned by stop() exit. When stop()''s lsof sweep found nothing (lsof missing or unreadable, or the identity probe timed out) but _spawned was non-empty, a peer cliproxy still on the port is never checked. A doomed replacement is spawned, and poll_until_healthy may adopt the peer, where before this change the "still answers" error was raised. Instances: the comments at cliproxy.lua:470-476 and 533-536. Fix: take the direct path only when stop() reports that the port''s listeners were enumerated, or soften the comment.'
          family: release-inferred-from-partial-pid-set
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: write_rendered_config plus its error branch is duplicated between restart_managed and ensure_running
          detail: cliproxy.lua:537-540 repeats cliproxy.lua:869-872 (ARCH-DRY). start_managed could call write_rendered_config itself, so both callers pass only the callbacks.
          family: duplicated-render-then-spawn-preamble
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: 0c2547f885692b5335c041c7f82c76114c3e3372
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d7a18c0c-99f1-4269-b3e3-1a6e766b3241
            repository: github.com/xianxu/parley.nvim
            issue_id: "000340"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/2ad5326ee870a3ce
            reviewed_head: 426c2054ab1cf82030d0e9fceb8f910afa3e2b2a
            slot: parley.nvim:4
            requested_at: "2026-10-16T07:40:53.938657Z"
          phase: finished
          pid: 65078
          started_at: "2026-10-16T07:40:54.209396Z"
          finished_at: "2026-10-16T07:44:06.219615Z"
          session_id: 87dae4d9-27c4-479b-ab7f-0b4257874d5d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 426c2054ab1cf82030d0e9fceb8f910afa3e2b2a
        tracker_head: d736ac85fe3383947567b9cda94977e2c59a6ed1
        branch_point: 30a94402e6a3978a2ce58fbf795dc3eee9389d2d
        since: "2026-10-15T23:44:45-07:00"
        until: "2026-10-16T00:28:59-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T23:44:45-07:00"
              end: "2026-10-16T00:28:59-07:00"
              began: "2026-10-15T23:44:45-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: c828f565a2c7c3c84006985df1cc79abb06d757acdd4f9f4c2d02879afe4ee86
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 3536342
              windows:
                - start: "2026-10-15T23:44:45-07:00"
                  end: "2026-10-16T00:28:59-07:00"
        cuts:
            - dispatched: "2026-10-16T00:22:47-07:00"
              finalized: "2026-10-16T00:25:34-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-16T00:44:12-07:00"
      dispatched: "2026-10-16T00:40:53-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: wait_port_released now re-reads lsof after exit and falls back to the probe on a leftover listener or failed read (cliproxy.lua:518-523); reverting it turns the new peer-on-port test red, restored green 57/57.
          round: 2
        - id: BR-2
          disposition: addressed
          note: render_or_fail (cliproxy.lua:363) is the single render-error site; ensure_running and start_managed(nil) both use it, and the duplicated block is gone.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Minor
          title: exit_poll's lsof re-read is a synchronous vim.system():wait() on the main loop
          detail: cliproxy.lua:519 blocks the editor for one lsof per restart; the implementer measured the harness max rising from 917 ms to 1557 ms under load. Acceptable as a one-time cost per restart (stop already does sync lsof and curl), but an async read would keep the UI path unblocked (ARCH-CONSTRAINTS).
          family: sync-io-on-main-loop-poll
          round: 2
      recipe: milestone-review
      isolation: checkout
      reviewed: 426c2054ab1cf82030d0e9fceb8f910afa3e2b2a
      blocked: false
---

# Gate ledger — parley.nvim#340 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T00:25:34-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `release-inferred-from-partial-pid-set` (kind: defect) "Old process gone, so the port is free" holds only for signalled pids; a peer on the port is no longer probed
  restart_managed (lua/parley/cliproxy.lua:533-541) skips every port probe once the pids returned by stop() exit. When stop()'s lsof sweep found nothing (lsof missing or unreadable, or the identity probe timed out) but _spawned was non-empty, a peer cliproxy still on the port is never checked. A doomed replacement is spawned, and poll_until_healthy may adopt the peer, where before this change the "still answers" error was raised. Instances: the comments at cliproxy.lua:470-476 and 533-536. Fix: take the direct path only when stop() reports that the port's listeners were enumerated, or soften the comment.
- **BR-2** [Minor] `duplicated-render-then-spawn-preamble` (kind: defect) write_rendered_config plus its error branch is duplicated between restart_managed and ensure_running
  cliproxy.lua:537-540 repeats cliproxy.lua:869-872 (ARCH-DRY). start_managed could call write_rendered_config itself, so both callers pass only the callbacks.

## Round 2 — 2026-10-16T00:44:12-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — wait_port_released now re-reads lsof after exit and falls back to the probe on a leftover listener or failed read (cliproxy.lua:518-523); reverting it turns the new peer-on-port test red, restored green 57/57.
- BR-2 — addressed — render_or_fail (cliproxy.lua:363) is the single render-error site; ensure_running and start_managed(nil) both use it, and the duplicated block is gone.

### Raised

- **BR-3** [Minor] `sync-io-on-main-loop-poll` (kind: defect) exit_poll's lsof re-read is a synchronous vim.system():wait() on the main loop
  cliproxy.lua:519 blocks the editor for one lsof per restart; the implementer measured the harness max rising from 917 ms to 1557 ms under load. Acceptable as a one-time cost per restart (stop already does sync lsof and curl), but an async read would keep the UI path unblocked (ARCH-CONSTRAINTS).

## Open findings

- **BR-3** [Minor] `sync-io-on-main-loop-poll` (kind: defect) exit_poll's lsof re-read is a synchronous vim.system():wait() on the main loop
