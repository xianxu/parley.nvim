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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: cb16029b-eaf4-40ec-ba3c-c563fe688100
            repository: github.com/xianxu/parley.nvim
            issue_id: "000236"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/880a7638b0d9ddb5
            reviewed_head: c1dbd49954e584805d1774b3a9958b030d244731
            slot: parley.nvim:4
            requested_at: "2026-10-16T12:54:45.403943Z"
          phase: finished
          pid: 25919
          started_at: "2026-10-16T12:54:45.54805Z"
          finished_at: "2026-10-16T12:56:05.96242Z"
          session_id: a091b382-760b-45d7-b95a-c80c345e8dd5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: c1dbd49954e584805d1774b3a9958b030d244731
        tracker_head: 35e57438cd5b777048f002335505d380af7dd3e0
        branch_point: 5abad04737d396828eb9614b28c20dbec43d7486
        since: "2026-10-16T05:39:39-07:00"
        until: "2026-10-16T05:54:19-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T05:39:39-07:00"
              end: "2026-10-16T05:54:19-07:00"
              began: "2026-10-16T05:39:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 6c3dc1e2f2edc70127436bff1d33cf2d54b3d0b3dea0f0e15330b5266be2f315
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 9734843
              windows:
                - start: "2026-10-16T05:39:39-07:00"
                  end: "2026-10-16T05:54:19-07:00"
        cuts:
            - dispatched: "2026-10-16T05:50:34-07:00"
              finalized: "2026-10-16T05:53:35-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T05:56:07-07:00"
      dispatched: "2026-10-16T05:54:45-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: 'atlas/skills/skill-system.md:40-42 and :68 are fixed, but the three code comments the finding named are unchanged: lua/parley/init.lua:107 (repo/virtual seams), lua/parley/skill_manifest.lua:4 (disk / user / repo / virtual) and :14 (unified disk/virtual). The round-2 concept sweep covered only atlas/ and README, not lua/ comments.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: 'atlas/index.md: the empty "10. Discovery Registry" heading is deleted and Traceability is renumbered to "## 10."'
          round: 2
      recipe: small-diff-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2e784204-3b9e-4cad-b161-e2217d262c6b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000236"
            recipe: small-diff-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/28f23fc1e54b1938
            reviewed_head: 430a6f913e1d4677bc330c907808a81c5274aaa8
            slot: parley.nvim:4
            requested_at: "2026-10-16T12:57:29.95442Z"
          phase: finished
          pid: 33725
          started_at: "2026-10-16T12:57:30.168864Z"
          finished_at: "2026-10-16T13:00:14.027052Z"
          session_id: 93ae4872-2be1-4b15-9efd-bf427bfca271
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 430a6f913e1d4677bc330c907808a81c5274aaa8
        tracker_head: 35e57438cd5b777048f002335505d380af7dd3e0
        branch_point: 5abad04737d396828eb9614b28c20dbec43d7486
        since: "2026-10-16T05:39:39-07:00"
        until: "2026-10-16T05:56:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T05:39:39-07:00"
              end: "2026-10-16T05:56:55-07:00"
              began: "2026-10-16T05:39:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 071052464e517f05c6224b7d349e0c111730f684cda45595c9ad2ece71dda0c8
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 9803448
              windows:
                - start: "2026-10-16T05:39:39-07:00"
                  end: "2026-10-16T05:56:55-07:00"
        cuts:
            - dispatched: "2026-10-16T05:50:34-07:00"
              finalized: "2026-10-16T05:53:35-07:00"
              finalizing: false
            - dispatched: "2026-10-16T05:54:45-07:00"
              finalized: "2026-10-16T05:56:07-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-16T06:00:15-07:00"
      dispatched: "2026-10-16T05:57:29-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'At head: skill-system.md:40-42 and :68 describe only the plugin then user disk stack; init.lua:107, skill_manifest.lua:4 and :14, the skill_providers.lua header and skill_registry.lua comments name no virtual or repo seam; a concept search of lua/, tests/, atlas/, README, scripts and packaging finds only intentional removal notes.'
          round: 3
      recipe: small-diff-review
      isolation: checkout
      reviewed: 430a6f913e1d4677bc330c907808a81c5274aaa8
      blocked: false
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

## Round 2 — 2026-10-16T05:56:07-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — not-addressed — atlas/skills/skill-system.md:40-42 and :68 are fixed, but the three code comments the finding named are unchanged: lua/parley/init.lua:107 (repo/virtual seams), lua/parley/skill_manifest.lua:4 (disk / user / repo / virtual) and :14 (unified disk/virtual). The round-2 concept sweep covered only atlas/ and README, not lua/ comments.
- BR-2 — addressed — atlas/index.md: the empty "10. Discovery Registry" heading is deleted and Traceability is renumbered to "## 10."

## Round 3 — 2026-10-16T06:00:15-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — At head: skill-system.md:40-42 and :68 describe only the plugin then user disk stack; init.lua:107, skill_manifest.lua:4 and :14, the skill_providers.lua header and skill_registry.lua comments name no virtual or repo seam; a concept search of lua/, tests/, atlas/, README, scripts and packaging finds only intentional removal notes.

## Open findings

(none — every finding has been disposed)
