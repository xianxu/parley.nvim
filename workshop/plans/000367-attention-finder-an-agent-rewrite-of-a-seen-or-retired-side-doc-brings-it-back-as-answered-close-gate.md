---
gate: boundary-review
issue: 367
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 134ba49c-74b9-480b-bdbf-94b8d84d7285
            repository: github.com/xianxu/parley.nvim
            issue_id: "000367"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f6fe7c940e57552e
            reviewed_head: 108f5a7f689d16d3c2e9e999867538e577c3eba6
            slot: parley.nvim:3
            requested_at: "2026-10-17T03:03:59.805117Z"
          phase: finished
          pid: 29345
          started_at: "2026-10-17T03:03:59.947547Z"
          finished_at: "2026-10-17T03:06:15.351266Z"
          session_id: 6239d6a9-7714-47b3-8529-24ca2a17842c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 108f5a7f689d16d3c2e9e999867538e577c3eba6
        tracker_head: bd07f236a83a3cd365577d3b007cd36b1e191b75
        branch_point: e9a78d43e4d57f3c93721d416a5a7adbbc36d5e6
        since: "2026-10-16T19:46:30-07:00"
        until: "2026-10-16T20:03:08-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T19:46:30-07:00"
              end: "2026-10-16T20:03:08-07:00"
              began: "2026-10-16T19:46:30-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 431b74f43922b19fb880fb155e48789c691561669dd646c7909eb2332213435c
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 19974474
              windows:
                - start: "2026-10-16T19:46:30-07:00"
                  end: "2026-10-16T20:03:08-07:00"
      "n": 1
      timestamp: "2026-10-16T20:06:20-07:00"
      dispatched: "2026-10-16T20:03:59-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: saved map grows unbounded between sweeps; atlas claims at most 256
          detail: handlers.saved records every BufWritePost of any file in any .side/ folder, including non-md and unrelated folders, and only handlers.sweep (finder open) prunes and caps. Prune or cap in handlers.saved too, or narrow M.saved to *.md.
          family: writer-unbounded-between-prunes
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: saved cap of 256 can drop live saves, so operator edits resurface as agent writes
          detail: The relevant set (256 entries, 256 retired paths, plus side-folder files) can exceed LIMIT, and a pruned save makes the operator's edit read as an agent rewrite. The sort uses tonumber of sec.nsec without zero-padded nanoseconds, so order within one second is approximate.
          family: cap-smaller-than-live-set
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Pre-367 stores have no saved map; operator-edited seen or retired side docs resurface once
          detail: Not noted in the atlas or Log. Add a line under Limits or a plan Revisions entry.
          family: undocumented-upgrade-behavior
          round: 1
      recipe: milestone-review
      isolation: fenced
      reviewed: 108f5a7f689d16d3c2e9e999867538e577c3eba6
      blocked: false
---

# Gate ledger — parley.nvim#367 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T20:06:20-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `writer-unbounded-between-prunes` (kind: defect) saved map grows unbounded between sweeps; atlas claims at most 256
  handlers.saved records every BufWritePost of any file in any .side/ folder, including non-md and unrelated folders, and only handlers.sweep (finder open) prunes and caps. Prune or cap in handlers.saved too, or narrow M.saved to *.md.
- **BR-2** [Minor] `cap-smaller-than-live-set` (kind: defect) saved cap of 256 can drop live saves, so operator edits resurface as agent writes
  The relevant set (256 entries, 256 retired paths, plus side-folder files) can exceed LIMIT, and a pruned save makes the operator's edit read as an agent rewrite. The sort uses tonumber of sec.nsec without zero-padded nanoseconds, so order within one second is approximate.
- **BR-3** [Minor] `undocumented-upgrade-behavior` (kind: defect) Pre-367 stores have no saved map; operator-edited seen or retired side docs resurface once
  Not noted in the atlas or Log. Add a line under Limits or a plan Revisions entry.

## Open findings

- **BR-1** [Minor] `writer-unbounded-between-prunes` (kind: defect) saved map grows unbounded between sweeps; atlas claims at most 256
- **BR-2** [Minor] `cap-smaller-than-live-set` (kind: defect) saved cap of 256 can drop live saves, so operator edits resurface as agent writes
- **BR-3** [Minor] `undocumented-upgrade-behavior` (kind: defect) Pre-367 stores have no saved map; operator-edited seen or retired side docs resurface once
