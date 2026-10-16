---
gate: boundary-review
issue: 345
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ca5de75c-3819-4152-a108-620a9606e4c7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000345"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/353ea23f56b3b4c1
            reviewed_head: 202bafa72fef2bbbb17b96a78027f37850da7fc1
            slot: parley.nvim:4
            requested_at: "2026-10-16T08:43:07.9057Z"
          phase: finished
          pid: 65260
          started_at: "2026-10-16T08:43:08.449313Z"
          finished_at: "2026-10-16T08:46:44.461702Z"
          session_id: ee69bd4c-d01a-41ca-b30e-af8548055738
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 202bafa72fef2bbbb17b96a78027f37850da7fc1
        tracker_head: cad0800bbc684dc5e3235a54d27da3829495e573
        branch_point: f3931fb58d00b50a2ec6a7511a06a353c538fdf0
        since: "2026-10-16T01:01:31-07:00"
        until: "2026-10-16T01:22:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T01:01:31-07:00"
              end: "2026-10-16T01:22:55-07:00"
              began: "2026-10-16T01:01:31-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 1d81bbdd94f234d5c13f572fbee8c3f93c2afe59c1189eb7f833b951921bbb8d
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 4297703
              windows:
                - start: "2026-10-16T01:01:31-07:00"
                  end: "2026-10-16T01:22:55-07:00"
      "n": 1
      timestamp: "2026-10-16T01:46:51-07:00"
      dispatched: "2026-10-16T01:43:07-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: port_release budget uses max(lsof, probe) but the post-exit lsof read and the deadline probe run sequentially
          detail: 'In wait_port_released, pids can all exit just before the 2 s deadline. The lsof read then runs up to LSOF_MAX_MS (2 s) and probe_poll adds one curl (2 s), so the worst case is 6 s, not the budgeted 2 + max(2,2) = 4 s (cliproxy.lua:463-465). The true sum, 27 s against a 30 s backstop, fails cliproxy_budget_spec''s 5 s headroom invariant, which passes today only because of the max. Fix: sum the term and restore headroom, for example by lowering LSOF_MAX_MS or by bounding lsof with the remaining release deadline. Also add stop_listener_read to restart_only.'
          family: repair-budget-term-derivation
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: M.stop's doc block and @return annotations now attach to sigterm_all
          detail: cliproxy.lua:983-989. Move the --- block to just above function M.stop().
          family: doc-annotation-placement
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: fake_lsof keeps reporting the pid after it exits, so the responsiveness test never reaches the exited fast path
          detail: The second listener read always returns the dead leftover pid, so the restart takes the probe fallback instead of start_managed. The test is valid for responsiveness but does not cover the async exited branch.
          family: stateless-fake-for-stateful-dependency
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: stop_async's async probe and lsof window lets a concurrent ensure_running's fresh proxy be found and SIGTERMed
          detail: _spawned is cleared before the async identity probe and listener read. A spawn in that window lands on the port and is reaped. The window existed already during the release wait; it is now slightly longer and is not modeled.
          family: unmodeled-async-interleaving
          round: 1
      recipe: milestone-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 566a4c6c-d8cf-4d03-8585-f4e06ebbcba4
            repository: github.com/xianxu/parley.nvim
            issue_id: "000345"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/d36c0dfe34d038d1
            reviewed_head: 8787140f9b1204cfc3a255f2a5f9102c2f6097c4
            slot: parley.nvim:4
            requested_at: "2026-10-16T09:03:42.418734Z"
          phase: finished
          pid: 26188
          started_at: "2026-10-16T09:03:42.712443Z"
          finished_at: "2026-10-16T09:07:24.876979Z"
          session_id: f7753cf0-0181-4254-9c77-3535742cb93f
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8787140f9b1204cfc3a255f2a5f9102c2f6097c4
        tracker_head: d1c735a05ec3a3c1551725bd4dffdbc67f3f3d09
        branch_point: f3931fb58d00b50a2ec6a7511a06a353c538fdf0
        since: "2026-10-16T01:01:31-07:00"
        until: "2026-10-16T01:50:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T01:01:31-07:00"
              end: "2026-10-16T01:50:55-07:00"
              began: "2026-10-16T01:01:31-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: e0f72cefa20ace2020a5970e9130fa964ebe7d124290eeac199d1848e4274f9e
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 4478313
              windows:
                - start: "2026-10-16T01:01:31-07:00"
                  end: "2026-10-16T01:50:55-07:00"
        cuts:
            - dispatched: "2026-10-16T01:43:07-07:00"
              finalized: "2026-10-16T01:46:51-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T02:07:26-07:00"
      dispatched: "2026-10-16T02:03:42-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The stacking is fixed in code (cliproxy.lua:523-532 passes the time left, port_release is deadline + one probe again), and the seam test pins the timeout parameter. Two things remain. First, restart_only in tests/unit/cliproxy_budget_spec.lua:31-34 still omits stop_listener_read, which the finding asked for explicitly; it should be derived from shared key names, not hand-listed (repair-budget-term-derivation). Second, no test fails if exit_poll stops passing remaining. Add the term, then either add a near-deadline restart test or record the untested wiring as an accepted gap in the plan.
          round: 2
        - id: BR-2
          disposition: addressed
          note: 'cliproxy.lua:1009-1016: the M.stop doc block and @return lines sit directly above function M.stop; the helpers moved above the block.'
          round: 2
        - id: BR-3
          disposition: addressed
          note: fake_lsof filters to live pids, and the responsiveness test asserts the reads list the leftover and then nothing, so the exited fast path is covered; passes at head.
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: 'Accepted, not fixed (issue log). Minor and non-blocking: a dispatch''s ensure_running racing an explicit restart can still be reaped in stop_async''s async window.'
          round: 2
      recipe: milestone-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 676f8dbb-ed64-49e8-9fd6-fc7a25e47a11
            repository: github.com/xianxu/parley.nvim
            issue_id: "000345"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/425de50f60fda53b
            reviewed_head: a3777a50afddb42c05796f811641dd8516a57c9d
            slot: parley.nvim:4
            requested_at: "2026-10-16T09:17:17.228735Z"
          phase: finished
          pid: 16716
          started_at: "2026-10-16T09:17:17.47803Z"
          finished_at: "2026-10-16T09:20:53.037786Z"
          session_id: 925103fa-19d7-490f-bb3d-029c4e1f018e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: a3777a50afddb42c05796f811641dd8516a57c9d
        tracker_head: e2b7da5ed6d5c8f0cdad99e86b567c4da73270da
        branch_point: 53be0c7ba673bb3aa243f05174d3719481259086
        since: "2026-10-16T01:01:31-07:00"
        until: "2026-10-16T02:09:49-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T01:01:31-07:00"
              end: "2026-10-16T02:09:49-07:00"
              began: "2026-10-16T01:01:31-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: dea7bbfecce461b9e1aeac384d54d162ff6bd4c97509da00a9cd36e0d968ee08
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 4694671
              windows:
                - start: "2026-10-16T01:01:31-07:00"
                  end: "2026-10-16T02:09:49-07:00"
        cuts:
            - dispatched: "2026-10-16T01:43:07-07:00"
              finalized: "2026-10-16T01:46:51-07:00"
              finalizing: false
            - dispatched: "2026-10-16T02:03:42-07:00"
              finalized: "2026-10-16T02:07:26-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-16T02:20:57-07:00"
      dispatched: "2026-10-16T02:17:17-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: The post-exit read is passed `remaining` (cliproxy.lua:536), stop_listener_read is in _restart_budget_keys, and the budget totals 25 s against 30 s. Reverting the pass-through fails "the release wait never runs its listener read past the deadline" (3789 ms); restored, all specs pass.
          round: 3
        - id: BR-4
          disposition: not-addressed
          note: Still present. The Log accepts it as a known risk (an explicit restart racing a dispatch's spawn). Minor, non-blocking; it should become its own issue if kept.
          round: 3
      findings:
        - kind: defect
          id: BR-5
          severity: Minor
          title: The pids_on_port doc block now sits above lsof_argv, separated from pids_on_port by the new helpers
          detail: 'cliproxy.lua:933-938. 2nd instance in this family (after BR-2). The rule: insert a new helper above an existing doc block, never between the block and its definition. A sweep of every insertion in this diff found no other instance. Fix: move lsof_argv and parse_listener_pids above the "PIDs listening on `port`" comment. Separately, the wait_port_released header (lines 487-496) still names M.stop() where the caller is now stop_async.'
          family: doc-annotation-placement
          round: 3
      recipe: milestone-review
      isolation: checkout
      reviewed: a3777a50afddb42c05796f811641dd8516a57c9d
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2aa09c87-03de-4e7c-be03-8aab438f1937
            repository: github.com/xianxu/parley.nvim
            issue_id: "000345"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/0365519ebe104a7a
            reviewed_head: 04169ca621b7b7c6faa94adfda2bdea4eb90ced4
            slot: parley.nvim:4
            requested_at: "2026-10-16T10:34:31.205247Z"
          phase: finished
          pid: 89081
          started_at: "2026-10-16T10:34:31.342914Z"
          finished_at: "2026-10-16T10:37:09.078519Z"
          session_id: f2d84c91-b57b-4b3b-97da-babecfe8098d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 04169ca621b7b7c6faa94adfda2bdea4eb90ced4
        tracker_head: beba87a73ba57765f207825f169aa72cbf406e7e
        branch_point: 0a616029f43d1a239f5a46bb3fc0b42a129dcd9a
        since: "2026-10-16T01:01:31-07:00"
        until: "2026-10-16T03:17:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T01:01:31-07:00"
              end: "2026-10-16T03:17:21-07:00"
              began: "2026-10-16T01:01:31-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 8078454cd8fcedf4757c1212405eacb400bb844c52fc9bad7adfd37c23999d29
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 5288704
              windows:
                - start: "2026-10-16T01:01:31-07:00"
                  end: "2026-10-16T03:17:21-07:00"
        cuts:
            - dispatched: "2026-10-16T01:43:07-07:00"
              finalized: "2026-10-16T01:46:51-07:00"
              finalizing: false
            - dispatched: "2026-10-16T02:03:42-07:00"
              finalized: "2026-10-16T02:07:26-07:00"
              finalizing: false
            - dispatched: "2026-10-16T02:17:17-07:00"
              finalized: "2026-10-16T02:20:57-07:00"
              finalizing: true
      "n": 4
      timestamp: "2026-10-16T03:37:10-07:00"
      dispatched: "2026-10-16T03:34:31-07:00"
      agent: claude
      dispose:
        - id: BR-4
          disposition: not-addressed
          note: No code change. The Log accepts the window and option B now confines it to the interactive commands, but it is still not modelled. Stays Minor.
          round: 4
        - id: BR-5
          disposition: not-addressed
          note: At head, cliproxy.lua:951-967 still puts lsof_argv/parse_listener_pids between the "PIDs listening on `port`" doc block and pids_on_port, and the wait_port_released header (line 487) still says "M.stop() returns immediately".
          round: 4
      findings:
        - kind: defect
          id: BR-6
          severity: Important
          title: The issue's Plan, Core-concepts stop row and Log still describe option A after the option-B revision
          detail: 'The Core-concepts `stop` row says "Kept for spec teardown" and the Log says "no product caller remains", yet READS.sync.stop (cliproxy.lua:551) calls M.stop() from credential_health (:1769), recovery (:2396) and update (:649). The ticked Plan item says restart_managed uses stop_async. Done-when #1''s list of remaining sync reads leaves out the budgeted paths'' sync identity curl and lsof. Sweep every Plan, Core-concepts and Log claim naming the replaced mechanism.'
          family: plan-stale-after-revision
          round: 4
        - kind: defect
          id: BR-7
          severity: Minor
          title: :ParleyProxy stop ignores stop_async's read_err and reports "stopped 0"
          detail: init.lua:384 only takes `n`. When the probe found a cliproxy but lsof timed out or failed, the proxy keeps running and the user is not told, while the restart path reports the same case. Notify a WARN that names read_err.
          family: read-error-dropped-by-caller
          round: 4
      recipe: milestone-review
      isolation: checkout
      reviewed: 04169ca621b7b7c6faa94adfda2bdea4eb90ced4
      blocked: false
---

# Gate ledger — parley.nvim#345 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T01:46:51-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `repair-budget-term-derivation` (kind: defect) port_release budget uses max(lsof, probe) but the post-exit lsof read and the deadline probe run sequentially
  In wait_port_released, pids can all exit just before the 2 s deadline. The lsof read then runs up to LSOF_MAX_MS (2 s) and probe_poll adds one curl (2 s), so the worst case is 6 s, not the budgeted 2 + max(2,2) = 4 s (cliproxy.lua:463-465). The true sum, 27 s against a 30 s backstop, fails cliproxy_budget_spec's 5 s headroom invariant, which passes today only because of the max. Fix: sum the term and restore headroom, for example by lowering LSOF_MAX_MS or by bounding lsof with the remaining release deadline. Also add stop_listener_read to restart_only.
- **BR-2** [Minor] `doc-annotation-placement` (kind: defect) M.stop's doc block and @return annotations now attach to sigterm_all
  cliproxy.lua:983-989. Move the --- block to just above function M.stop().
- **BR-3** [Minor] `stateless-fake-for-stateful-dependency` (kind: defect) fake_lsof keeps reporting the pid after it exits, so the responsiveness test never reaches the exited fast path
  The second listener read always returns the dead leftover pid, so the restart takes the probe fallback instead of start_managed. The test is valid for responsiveness but does not cover the async exited branch.
- **BR-4** [Minor] `unmodeled-async-interleaving` (kind: defect) stop_async's async probe and lsof window lets a concurrent ensure_running's fresh proxy be found and SIGTERMed
  _spawned is cleared before the async identity probe and listener read. A spawn in that window lands on the port and is reaped. The window existed already during the release wait; it is now slightly longer and is not modeled.

## Round 2 — 2026-10-16T02:07:26-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — not-addressed — The stacking is fixed in code (cliproxy.lua:523-532 passes the time left, port_release is deadline + one probe again), and the seam test pins the timeout parameter. Two things remain. First, restart_only in tests/unit/cliproxy_budget_spec.lua:31-34 still omits stop_listener_read, which the finding asked for explicitly; it should be derived from shared key names, not hand-listed (repair-budget-term-derivation). Second, no test fails if exit_poll stops passing remaining. Add the term, then either add a near-deadline restart test or record the untested wiring as an accepted gap in the plan.
- BR-2 — addressed — cliproxy.lua:1009-1016: the M.stop doc block and @return lines sit directly above function M.stop; the helpers moved above the block.
- BR-3 — addressed — fake_lsof filters to live pids, and the responsiveness test asserts the reads list the leftover and then nothing, so the exited fast path is covered; passes at head.
- BR-4 — not-addressed — Accepted, not fixed (issue log). Minor and non-blocking: a dispatch's ensure_running racing an explicit restart can still be reaped in stop_async's async window.

## Round 3 — 2026-10-16T02:20:57-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — The post-exit read is passed `remaining` (cliproxy.lua:536), stop_listener_read is in _restart_budget_keys, and the budget totals 25 s against 30 s. Reverting the pass-through fails "the release wait never runs its listener read past the deadline" (3789 ms); restored, all specs pass.
- BR-4 — not-addressed — Still present. The Log accepts it as a known risk (an explicit restart racing a dispatch's spawn). Minor, non-blocking; it should become its own issue if kept.

### Raised

- **BR-5** [Minor] `doc-annotation-placement` (kind: defect) The pids_on_port doc block now sits above lsof_argv, separated from pids_on_port by the new helpers
  cliproxy.lua:933-938. 2nd instance in this family (after BR-2). The rule: insert a new helper above an existing doc block, never between the block and its definition. A sweep of every insertion in this diff found no other instance. Fix: move lsof_argv and parse_listener_pids above the "PIDs listening on `port`" comment. Separately, the wait_port_released header (lines 487-496) still names M.stop() where the caller is now stop_async.

## Round 4 — 2026-10-16T03:37:10-07:00 (claude) — passed

### Disposed

- BR-4 — not-addressed — No code change. The Log accepts the window and option B now confines it to the interactive commands, but it is still not modelled. Stays Minor.
- BR-5 — not-addressed — At head, cliproxy.lua:951-967 still puts lsof_argv/parse_listener_pids between the "PIDs listening on `port`" doc block and pids_on_port, and the wait_port_released header (line 487) still says "M.stop() returns immediately".

### Raised

- **BR-6** [Important] `plan-stale-after-revision` (kind: defect) The issue's Plan, Core-concepts stop row and Log still describe option A after the option-B revision
  The Core-concepts `stop` row says "Kept for spec teardown" and the Log says "no product caller remains", yet READS.sync.stop (cliproxy.lua:551) calls M.stop() from credential_health (:1769), recovery (:2396) and update (:649). The ticked Plan item says restart_managed uses stop_async. Done-when #1's list of remaining sync reads leaves out the budgeted paths' sync identity curl and lsof. Sweep every Plan, Core-concepts and Log claim naming the replaced mechanism.
- **BR-7** [Minor] `read-error-dropped-by-caller` (kind: defect) :ParleyProxy stop ignores stop_async's read_err and reports "stopped 0"
  init.lua:384 only takes `n`. When the probe found a cliproxy but lsof timed out or failed, the proxy keeps running and the user is not told, while the restart path reports the same case. Notify a WARN that names read_err.

## Open findings

- **BR-4** [Minor] `unmodeled-async-interleaving` (kind: defect) stop_async's async probe and lsof window lets a concurrent ensure_running's fresh proxy be found and SIGTERMed
- **BR-5** [Minor] `doc-annotation-placement` (kind: defect) The pids_on_port doc block now sits above lsof_argv, separated from pids_on_port by the new helpers
- **BR-6** [Important] `plan-stale-after-revision` (kind: defect) The issue's Plan, Core-concepts stop row and Log still describe option A after the option-B revision
- **BR-7** [Minor] `read-error-dropped-by-caller` (kind: defect) :ParleyProxy stop ignores stop_async's read_err and reports "stopped 0"
