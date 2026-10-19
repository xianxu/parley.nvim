---
gate: boundary-review
issue: 397
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 226861a8-8c70-4a34-b23f-344278f68270
            repository: github.com/xianxu/parley.nvim
            issue_id: "000397"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/426575a874c6971f
            reviewed_head: d1dfab038d0bd6c595b903a8fe2f4dd965988f60
            slot: parley.nvim:3
            requested_at: "2026-10-19T08:06:45.543908Z"
          phase: finished
          pid: 93383
          started_at: "2026-10-19T08:06:45.66995Z"
          finished_at: "2026-10-19T08:14:22.349562Z"
          session_id: 8545f63f-3a26-497d-b798-f195d5de6669
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d1dfab038d0bd6c595b903a8fe2f4dd965988f60
        tracker_head: f86ce54ed5802154bab1ae70ec6e0669ab9570b2
        branch_point: a1b0a08b07d10b9902680e6aabba57d73c634601
        since: "2026-10-19T01:00:46-07:00"
        until: "2026-10-19T01:06:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T01:00:46-07:00"
              end: "2026-10-19T01:06:21-07:00"
              began: "2026-10-19T01:00:46-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 32e694e6500372b4e86b4e82d9be38cd6c2b32425cf18621da6d046f318b846d
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 4231390
              windows:
                - start: "2026-10-19T01:00:46-07:00"
                  end: "2026-10-19T01:06:21-07:00"
      "n": 1
      timestamp: "2026-10-19T01:14:23-07:00"
      dispatched: "2026-10-19T01:06:45-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: New located() test fails at head, so the home and absolute branches never run
          detail: 'tests/unit/breadcrumb_model_spec.lua:82 expects "lua › x" but located("/h/r/lua/x.lua", "/h/r", "/h") projects "lua › x.lua", since only .md is stripped (line 75 already pins x.lua). The failing assert aborts the it-block, so lines 83-85 (the ~ and / branches plus the /hx lookalike) never run, and Done-when clause 3 is unmet. Fix: expect "lua › x.lua" (or use x.md) and re-run. The other located() assertions in this window (lines 83, 84, 85) use .md leaves and are correct.'
          family: test-expectation-unverified
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Depth-scan test winbar assertion accepts either chain form
          detail: tests/integration/file_history_spec.lua:165 ORs "0 › 1 › 2" with the elided form. The first substring also matches a full depth-8 chain, so the assertion does not pin which chain is displayed. Assert the exact depth-8 projection instead.
          family: assertion-too-loose
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 40147664-e921-4d3f-a972-08fcdd42ec6d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000397"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/e5b9a4369766c905
            reviewed_head: 555ad10936db22758652a4a29f0a2ce861a8b1de
            slot: parley.nvim:3
            requested_at: "2026-10-19T08:16:04.757865Z"
          phase: finished
          pid: 62167
          started_at: "2026-10-19T08:16:05.00603Z"
          finished_at: "2026-10-19T08:18:09.54694Z"
          session_id: de8468f5-3e87-4368-a3c6-8b130d9efbdb
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 555ad10936db22758652a4a29f0a2ce861a8b1de
        tracker_head: f86ce54ed5802154bab1ae70ec6e0669ab9570b2
        branch_point: a1b0a08b07d10b9902680e6aabba57d73c634601
        since: "2026-10-19T01:00:46-07:00"
        until: "2026-10-19T01:15:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T01:00:46-07:00"
              end: "2026-10-19T01:15:21-07:00"
              began: "2026-10-19T01:00:46-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d43e647c547da3829a82f4c500a9ee65eecb001f0299af12bc45183962fb86e3
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 4371330
              windows:
                - start: "2026-10-19T01:00:46-07:00"
                  end: "2026-10-19T01:15:21-07:00"
        cuts:
            - dispatched: "2026-10-19T01:06:45-07:00"
              finalized: "2026-10-19T01:14:23-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-19T01:18:11-07:00"
      dispatched: "2026-10-19T01:16:04-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Line 82 now uses x.md; breadcrumb_model_spec passes 13/13 under ui/breadcrumb (newly mapped). Deleting the home branch makes line 83 fail.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The assertion now pins the exact " 0 › 1 › … › 8%=" winbar (document_band_model emits a trailing %=), and the test passes at head.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 555ad10936db22758652a4a29f0a2ce861a8b1de
      blocked: false
---

# Gate ledger — parley.nvim#397 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T01:14:23-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `test-expectation-unverified` (kind: defect) New located() test fails at head, so the home and absolute branches never run
  tests/unit/breadcrumb_model_spec.lua:82 expects "lua › x" but located("/h/r/lua/x.lua", "/h/r", "/h") projects "lua › x.lua", since only .md is stripped (line 75 already pins x.lua). The failing assert aborts the it-block, so lines 83-85 (the ~ and / branches plus the /hx lookalike) never run, and Done-when clause 3 is unmet. Fix: expect "lua › x.lua" (or use x.md) and re-run. The other located() assertions in this window (lines 83, 84, 85) use .md leaves and are correct.
- **BR-2** [Minor] `assertion-too-loose` (kind: defect) Depth-scan test winbar assertion accepts either chain form
  tests/integration/file_history_spec.lua:165 ORs "0 › 1 › 2" with the elided form. The first substring also matches a full depth-8 chain, so the assertion does not pin which chain is displayed. Assert the exact depth-8 projection instead.

## Round 2 — 2026-10-19T01:18:11-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Line 82 now uses x.md; breadcrumb_model_spec passes 13/13 under ui/breadcrumb (newly mapped). Deleting the home branch makes line 83 fail.
- BR-2 — addressed — The assertion now pins the exact " 0 › 1 › … › 8%=" winbar (document_band_model emits a trailing %=), and the test passes at head.

## Open findings

(none — every finding has been disposed)
