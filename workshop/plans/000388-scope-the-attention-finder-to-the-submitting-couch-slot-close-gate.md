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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 09b029a8-bfd5-4008-bd7e-bd6250ff0a3f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000388"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f368a926a06c6ac9
            reviewed_head: 8bd03ed0d49c1f3d2c037d83523134dc0e344487
            slot: parley.nvim:1
            requested_at: "2026-10-18T19:49:15.121666Z"
          phase: finished
          pid: 13909
          started_at: "2026-10-18T19:49:15.273556Z"
          finished_at: "2026-10-18T19:50:30.980979Z"
          session_id: 01a1508f-acea-7cf0-ab79-64d2469096b4
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8bd03ed0d49c1f3d2c037d83523134dc0e344487
        tracker_head: f24ffc2b0c73be1eca85ffda17400884e812b2a2
        branch_point: 938aae45c6fff478e65364aadf21766e303b102b
        since: "2026-10-18T12:01:44-07:00"
        until: "2026-10-18T12:48:33-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T12:01:44-07:00"
              end: "2026-10-18T12:48:33-07:00"
              began: "2026-10-18T12:01:44-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: a8042bcf6d39e48b3b8a1365b58c74926a0d288f45797d3626b27e5671bae43b
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 61143172
              windows:
                - start: "2026-10-18T12:01:44-07:00"
                  end: "2026-10-18T12:48:33-07:00"
        queue_waits:
            - attempt_id: b128ef609d54b16545d71033a29d85f7
              slot: parley.nvim:1
              record_digest: 754fd0cb73ac0ace4b47ceafa17d90cac20a593d424a44b2104e92e73a457e7e
              start: "2026-10-18T19:07:46.100979Z"
              end: "2026-10-18T19:41:27.827588Z"
              queue_seconds: 2021.726609
              raw_seconds: 2021.726609
              exact: true
        cuts:
            - dispatched: "2026-10-18T12:12:41-07:00"
              finalized: "2026-10-18T12:14:26-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-18T12:50:31-07:00"
      dispatched: "2026-10-18T12:49:15-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: 'ARCH-DRY: The complete family remains lua/parley/attention.lua:43 (ID extraction) and :67 (sender extraction), each independently encoding the receipt grammar. No shared parser was introduced. Retain this Minor advisory; extract one pure parser returning both fields and preserve parse_message_id as a compatibility wrapper.'
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 8bd03ed0d49c1f3d2c037d83523134dc0e344487
      blocked: false
---

# Gate ledger — parley.nvim#388 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T12:14:26-07:00 (codex) — passed

### Raised

- **BR-1** [Minor] `single-source-receipt-parsing` (kind: defect) ARCH-DRY: Couch receipt grammar is duplicated.
  The complete family is lua/parley/attention.lua:43 (message-ID extraction) and :67 (sender extraction). Both encode the same receipt structure independently. Extract one pure receipt parser returning ID and sender, retaining parse_message_id as a compatibility wrapper, so receipt-format changes cannot update only one field.

## Round 2 — 2026-10-18T12:50:31-07:00 (codex) — passed

### Disposed

- BR-1 — not-addressed — ARCH-DRY: The complete family remains lua/parley/attention.lua:43 (ID extraction) and :67 (sender extraction), each independently encoding the receipt grammar. No shared parser was introduced. Retain this Minor advisory; extract one pure parser returning both fields and preserve parse_message_id as a compatibility wrapper.

## Open findings

- **BR-1** [Minor] `single-source-receipt-parsing` (kind: defect) ARCH-DRY: Couch receipt grammar is duplicated.
