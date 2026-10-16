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

## Open findings

- **BR-1** [Important] `repair-budget-term-derivation` (kind: defect) port_release budget uses max(lsof, probe) but the post-exit lsof read and the deadline probe run sequentially
- **BR-2** [Minor] `doc-annotation-placement` (kind: defect) M.stop's doc block and @return annotations now attach to sigterm_all
- **BR-3** [Minor] `stateless-fake-for-stateful-dependency` (kind: defect) fake_lsof keeps reporting the pid after it exits, so the responsiveness test never reaches the exited fast path
- **BR-4** [Minor] `unmodeled-async-interleaving` (kind: defect) stop_async's async probe and lsof window lets a concurrent ensure_running's fresh proxy be found and SIGTERMed
