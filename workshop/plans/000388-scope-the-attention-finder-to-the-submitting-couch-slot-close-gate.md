---
gate: boundary-review
issue: 388
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: c5e5467d-01dc-442b-8885-c14945e170b5
            repository: github.com/xianxu/parley.nvim
            issue_id: "000388"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/6650dfef42f8e674
            reviewed_head: 5ddcb829a5655916d2769f889162701abd4e7009
            slot: parley.nvim:1
            requested_at: "2026-10-18T19:12:41.230424Z"
          phase: finished
          pid: 74847
          started_at: "2026-10-18T19:12:41.422592Z"
          finished_at: "2026-10-18T19:14:25.159493Z"
          session_id: 01a1506e-33d4-7211-b312-fa7dc1aa5bc1
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5ddcb829a5655916d2769f889162701abd4e7009
        tracker_head: 3856eb341084d93cce252bd96b31b6b57c4fd4be
        branch_point: 938aae45c6fff478e65364aadf21766e303b102b
        since: "2026-10-18T12:01:44-07:00"
        until: "2026-10-18T12:12:11-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T12:01:44-07:00"
              end: "2026-10-18T12:12:11-07:00"
              began: "2026-10-18T12:01:44-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 4ae1e5e378f70007b518a061a49ebeab91b3ad47e1286156ccfda691675dc1c4
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 60152260
              windows:
                - start: "2026-10-18T12:01:44-07:00"
                  end: "2026-10-18T12:12:11-07:00"
      "n": 1
      timestamp: "2026-10-18T12:14:26-07:00"
      dispatched: "2026-10-18T12:12:41-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: 'ARCH-DRY: Couch receipt grammar is duplicated.'
          detail: The complete family is lua/parley/attention.lua:43 (message-ID extraction) and :67 (sender extraction). Both encode the same receipt structure independently. Extract one pure receipt parser returning ID and sender, retaining parse_message_id as a compatibility wrapper, so receipt-format changes cannot update only one field.
          family: single-source-receipt-parsing
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 5ddcb829a5655916d2769f889162701abd4e7009
      blocked: false
---

# Gate ledger — parley.nvim#388 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T12:14:26-07:00 (codex) — passed

### Raised

- **BR-1** [Minor] `single-source-receipt-parsing` (kind: defect) ARCH-DRY: Couch receipt grammar is duplicated.
  The complete family is lua/parley/attention.lua:43 (message-ID extraction) and :67 (sender extraction). Both encode the same receipt structure independently. Extract one pure receipt parser returning ID and sender, retaining parse_message_id as a compatibility wrapper, so receipt-format changes cannot update only one field.

## Open findings

- **BR-1** [Minor] `single-source-receipt-parsing` (kind: defect) ARCH-DRY: Couch receipt grammar is duplicated.
