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
---

# Gate ledger — parley.nvim#390 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T15:32:26-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `cycle-recovery-preserves-parentage` (kind: defect) Cycle recovery detaches descendants whose entries precede the cycle
  lua/parley/attention_rows.lua:42 promotes every unvisited entry directly, including descendants of cycles. With input ordered leaf→a, a→b, b→a, layout emits leaf as a root, then a as another root with child b; searching leaf returns only leaf despite its listed ancestors being present. This contradicts ancestor retention and the Plan's one-root-per-component contract (ARCH-PURPOSE). The complete affected family is descendants preceding their cyclic ancestors: children of self-cycles, children of multi-node cycles, and nested descendant chains; direct pure-Lua checks reproduced respectively two, two, and three roots for single connected components. Resolve each remaining component to a deterministic cycle member before traversing its children, breaking only a cycle edge. Add regression cases for all three shapes, checking parentage, ancestor search, uniqueness, and traversal bounds.

## Open findings

- **BR-1** [Critical] `cycle-recovery-preserves-parentage` (kind: defect) Cycle recovery detaches descendants whose entries precede the cycle
