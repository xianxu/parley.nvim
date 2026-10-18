---
gate: boundary-review
issue: 390
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 9eb0c234-5429-48d7-b80e-dc8e0f24d2a7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000390"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/1bd5848e4d0ad76a
            reviewed_head: 42956aba6b01b0b8232eaf6fc2ed864e6f2f18b8
            slot: parley.nvim:1
            requested_at: "2026-10-18T22:30:51.532028Z"
          phase: finished
          pid: 4960
          started_at: "2026-10-18T22:30:51.786528Z"
          finished_at: "2026-10-18T22:32:24.881637Z"
          session_id: 01a15123-a364-7011-99b8-34a9ec96e252
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 42956aba6b01b0b8232eaf6fc2ed864e6f2f18b8
        tracker_head: 1a6bd80edf01c52d6fe4b686b45bce215bdde45a
        branch_point: 04076256358d0a398f36be6201293559afa96b90
        since: "2026-10-18T15:22:33-07:00"
        until: "2026-10-18T15:30:13-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T15:22:33-07:00"
              end: "2026-10-18T15:30:13-07:00"
              began: "2026-10-18T15:22:33-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 8249f77127a23e7f463f388abecdf67a5a96deaff93e0899ca99715986ada220
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 63313439
              windows:
                - start: "2026-10-18T15:22:33-07:00"
                  end: "2026-10-18T15:30:13-07:00"
      "n": 1
      timestamp: "2026-10-18T15:32:26-07:00"
      dispatched: "2026-10-18T15:30:51-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Cycle recovery detaches descendants whose entries precede the cycle
          detail: 'lua/parley/attention_rows.lua:42 promotes every unvisited entry directly, including descendants of cycles. With input ordered leaf→a, a→b, b→a, layout emits leaf as a root, then a as another root with child b; searching leaf returns only leaf despite its listed ancestors being present. This contradicts ancestor retention and the Plan''s one-root-per-component contract (ARCH-PURPOSE). The complete affected family is descendants preceding their cyclic ancestors: children of self-cycles, children of multi-node cycles, and nested descendant chains; direct pure-Lua checks reproduced respectively two, two, and three roots for single connected components. Resolve each remaining component to a deterministic cycle member before traversing its children, breaking only a cycle edge. Add regression cases for all three shapes, checking parentage, ancestor search, uniqueness, and traversal bounds.'
          family: cycle-recovery-preserves-parentage
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 6ea5abfb-f3f6-487c-baad-a2061c9ee568
            repository: github.com/xianxu/parley.nvim
            issue_id: "000390"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/e98cbe3566749b2b
            reviewed_head: 75e98e4e6d57a55fb69c21b27b89f65d004c6b2c
            slot: parley.nvim:1
            requested_at: "2026-10-18T22:35:51.216817Z"
          phase: finished
          pid: 14282
          started_at: "2026-10-18T22:35:51.419859Z"
          finished_at: "2026-10-18T22:37:51.086057Z"
          session_id: 01a15128-34b3-7992-befb-e8df9f05bbcf
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 75e98e4e6d57a55fb69c21b27b89f65d004c6b2c
        tracker_head: 1a6bd80edf01c52d6fe4b686b45bce215bdde45a
        branch_point: 04076256358d0a398f36be6201293559afa96b90
        since: "2026-10-18T15:22:33-07:00"
        until: "2026-10-18T15:35:13-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T15:22:33-07:00"
              end: "2026-10-18T15:35:13-07:00"
              began: "2026-10-18T15:22:33-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 2f1b7fd7f2e1cd759b467a9d63a3bd1131decb244e5220cbff0c6ef721fd0e95
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 63729820
              windows:
                - start: "2026-10-18T15:22:33-07:00"
                  end: "2026-10-18T15:35:13-07:00"
        cuts:
            - dispatched: "2026-10-18T15:30:51-07:00"
              finalized: "2026-10-18T15:32:26-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-18T15:37:52-07:00"
      dispatched: "2026-10-18T15:35:51-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: attention_rows.lua:43–50 resolves each remaining component to a cycle member before traversal. Tests at attention_rows_spec.lua:70–112 cover self-cycle children, multi-node cycle children, and nested descendants, including parentage, ancestor search, uniqueness, and traversal bounds. Loading the pre-fix module in memory made all four new regression cases fail; the pinned implementation passes.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 75e98e4e6d57a55fb69c21b27b89f65d004c6b2c
      blocked: false
---

# Gate ledger — parley.nvim#390 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T15:32:26-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `cycle-recovery-preserves-parentage` (kind: defect) Cycle recovery detaches descendants whose entries precede the cycle
  lua/parley/attention_rows.lua:42 promotes every unvisited entry directly, including descendants of cycles. With input ordered leaf→a, a→b, b→a, layout emits leaf as a root, then a as another root with child b; searching leaf returns only leaf despite its listed ancestors being present. This contradicts ancestor retention and the Plan's one-root-per-component contract (ARCH-PURPOSE). The complete affected family is descendants preceding their cyclic ancestors: children of self-cycles, children of multi-node cycles, and nested descendant chains; direct pure-Lua checks reproduced respectively two, two, and three roots for single connected components. Resolve each remaining component to a deterministic cycle member before traversing its children, breaking only a cycle edge. Add regression cases for all three shapes, checking parentage, ancestor search, uniqueness, and traversal bounds.

## Round 2 — 2026-10-18T15:37:52-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — attention_rows.lua:43–50 resolves each remaining component to a cycle member before traversal. Tests at attention_rows_spec.lua:70–112 cover self-cycle children, multi-node cycle children, and nested descendants, including parentage, ancestor search, uniqueness, and traversal bounds. Loading the pre-fix module in memory made all four new regression cases fail; the pinned implementation passes.

## Open findings

(none — every finding has been disposed)
