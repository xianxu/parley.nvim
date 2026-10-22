---
gate: boundary-review
issue: 409
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 6b22dcb8-6eb5-429b-bc56-6050b3e7e02f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000409"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/fc89e8224a9f19b3
            reviewed_head: aae4e70e14ac4b1eac5aa10da7bc94836e8bcb0a
            slot: parley.nvim:3
            requested_at: "2026-10-22T18:41:07.471911Z"
          phase: finished
          pid: 37820
          started_at: "2026-10-22T18:41:08.04492Z"
          finished_at: "2026-10-22T18:44:47.576653Z"
          session_id: 01a164ea-c127-7993-9a3a-47d2ae48f9d4
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: aae4e70e14ac4b1eac5aa10da7bc94836e8bcb0a
        tracker_head: fa338584574466d247c28e845dc966446922d1f4
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T11:20:56-07:00"
        until: "2026-10-22T11:40:27-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:20:56-07:00"
              end: "2026-10-22T11:40:27-07:00"
              began: "2026-10-22T11:20:56-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a9872e0cc429c6607367adf0dfe0df2b97ed70a3d2835e3f092a7fe02840e86d
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 2653267
              windows:
                - start: "2026-10-22T11:20:56-07:00"
                  end: "2026-10-22T11:40:27-07:00"
      "n": 1
      timestamp: "2026-10-22T11:44:49-07:00"
      dispatched: "2026-10-22T11:41:07-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Protected targets bypass the lifetime lease when reached as prerequisites
          detail: 'Makefile.parley:8 enables lease dispatch only when MAKECMDGOALS directly names a protected target. In a disposable checkout, adding `review-alias: test-spec` and invoking that alias started the gated harness without a lifetime lease; a second direct test-spec entered without waiting and SIGKILLed the first Neovim. Enforce ownership whenever a protected target executes, including prerequisite/default-goal entry, before scratch mutation through final census. Add a gated regression for this entry path. This violates ARCH-PURPOSE and ARCH-ORDER.'
          family: harness-entry-ownership
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 9ad775b5-0ddd-4b48-9cd6-70c299346c00
            repository: github.com/xianxu/parley.nvim
            issue_id: "000409"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/c1e036218a27396a
            reviewed_head: 92168f8e0df941de0c7ca17ea201071d3a9ace00
            slot: parley.nvim:3
            requested_at: "2026-10-22T18:59:51.215648Z"
          phase: finished
          pid: 15402
          started_at: "2026-10-22T18:59:51.433233Z"
          finished_at: "2026-10-22T19:03:26.024036Z"
          session_id: 01a164fb-e3f9-7b30-8d84-b17e0e5331de
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 92168f8e0df941de0c7ca17ea201071d3a9ace00
        tracker_head: 128d21973587049095a500d5e2b11a589481b7bb
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T11:20:56-07:00"
        until: "2026-10-22T11:59:12-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:20:56-07:00"
              end: "2026-10-22T11:59:12-07:00"
              began: "2026-10-22T11:20:56-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 4f55706d2e1fa7983082d844095513e0a141bea500e780708fe2efb9b03dd1cb
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 3496879
              windows:
                - start: "2026-10-22T11:20:56-07:00"
                  end: "2026-10-22T11:59:12-07:00"
        cuts:
            - dispatched: "2026-10-22T11:41:07-07:00"
              finalized: "2026-10-22T11:44:49-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-22T12:03:27-07:00"
      dispatched: "2026-10-22T11:59:51-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Makefile.parley:14-19 unconditionally wraps protected targets and guards internal bodies before effects. Alias-chain and default-goal regressions pass at the pinned head; both fail with “second run entered instead of waiting” when the prior Makefile and lease helper are restored together in a disposable checkout, removed after testing.
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 92168f8e0df941de0c7ca17ea201071d3a9ace00
      blocked: false
---

# Gate ledger — parley.nvim#409 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T11:44:49-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `harness-entry-ownership` (kind: defect) Protected targets bypass the lifetime lease when reached as prerequisites
  Makefile.parley:8 enables lease dispatch only when MAKECMDGOALS directly names a protected target. In a disposable checkout, adding `review-alias: test-spec` and invoking that alias started the gated harness without a lifetime lease; a second direct test-spec entered without waiting and SIGKILLed the first Neovim. Enforce ownership whenever a protected target executes, including prerequisite/default-goal entry, before scratch mutation through final census. Add a gated regression for this entry path. This violates ARCH-PURPOSE and ARCH-ORDER.

## Round 2 — 2026-10-22T12:03:27-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Makefile.parley:14-19 unconditionally wraps protected targets and guards internal bodies before effects. Alias-chain and default-goal regressions pass at the pinned head; both fail with “second run entered instead of waiting” when the prior Makefile and lease helper are restored together in a disposable checkout, removed after testing.

## Open findings

(none — every finding has been disposed)
