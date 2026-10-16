---
gate: boundary-review
issue: 236
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 8aa21b78-3040-467b-8f7e-15f5335aa305
            repository: github.com/xianxu/parley.nvim
            issue_id: "000236"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/c82aa16ba0e06af0
            reviewed_head: d1daab0afe2a00a881424d67f54759925983f252
            slot: parley.nvim:4
            requested_at: "2026-10-16T12:50:34.838505Z"
          phase: finished
          pid: 16814
          started_at: "2026-10-16T12:50:34.993561Z"
          finished_at: "2026-10-16T12:53:34.233717Z"
          session_id: 3d6f5382-07ef-49f7-9588-abb70e9bbacd
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d1daab0afe2a00a881424d67f54759925983f252
        tracker_head: 35e57438cd5b777048f002335505d380af7dd3e0
        branch_point: 5abad04737d396828eb9614b28c20dbec43d7486
        since: "2026-10-16T05:39:39-07:00"
        until: "2026-10-16T05:47:49-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T05:39:39-07:00"
              end: "2026-10-16T05:47:49-07:00"
              began: "2026-10-16T05:39:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 2687bacb693e234ab23aaa605a38a40cd37802a010ea6e6104b0cf78ffa51dd0
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 9677157
              windows:
                - start: "2026-10-16T05:39:39-07:00"
                  end: "2026-10-16T05:47:49-07:00"
      "n": 1
      timestamp: "2026-10-16T05:53:35-07:00"
      dispatched: "2026-10-16T05:50:34-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: atlas/skills/skill-system.md still documents the deleted virtual provider and default_stack generator seams
          detail: 'This breaks the Done-when clause that atlas/ must not reference a deleted module. Every stale mention of the removed virtual/repo seams: atlas/skills/skill-system.md:40-42 (says default_stack accepts repo/virtual generator providers); atlas/skills/skill-system.md:68 ("Load disk/virtual providers"); lua/parley/init.lua:107 ("repo/virtual seams"); lua/parley/skill_manifest.lua:4 ("disk / user / repo / virtual"); lua/parley/skill_manifest.lua:14 ("unified disk/virtual"). Fix: delete the paragraph at lines 40-42, change line 68 to "disk providers", and update the three code comments.'
          family: deleted-surface-stale-reference
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: atlas/index.md keeps an empty "10. Discovery Registry" section heading
          detail: Its only entry was removed. Delete the heading and renumber the sections after it (Traceability becomes 10).
          family: deleted-surface-stale-reference
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
---

# Gate ledger — parley.nvim#236 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T05:53:35-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `deleted-surface-stale-reference` (kind: defect) atlas/skills/skill-system.md still documents the deleted virtual provider and default_stack generator seams
  This breaks the Done-when clause that atlas/ must not reference a deleted module. Every stale mention of the removed virtual/repo seams: atlas/skills/skill-system.md:40-42 (says default_stack accepts repo/virtual generator providers); atlas/skills/skill-system.md:68 ("Load disk/virtual providers"); lua/parley/init.lua:107 ("repo/virtual seams"); lua/parley/skill_manifest.lua:4 ("disk / user / repo / virtual"); lua/parley/skill_manifest.lua:14 ("unified disk/virtual"). Fix: delete the paragraph at lines 40-42, change line 68 to "disk providers", and update the three code comments.
- **BR-2** [Minor] `deleted-surface-stale-reference` (kind: defect) atlas/index.md keeps an empty "10. Discovery Registry" section heading
  Its only entry was removed. Delete the heading and renumber the sections after it (Traceability becomes 10).

## Open findings

- **BR-1** [Important] `deleted-surface-stale-reference` (kind: defect) atlas/skills/skill-system.md still documents the deleted virtual provider and default_stack generator seams
- **BR-2** [Minor] `deleted-surface-stale-reference` (kind: defect) atlas/index.md keeps an empty "10. Discovery Registry" section heading
