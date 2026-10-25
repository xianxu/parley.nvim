---
gate: boundary-review
issue: 440
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: acb36ee6-2d50-42c0-92e5-cab7920dc8f7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000440"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/523a292817b772d0
            reviewed_head: 42a7409870a66fa1f888362a9c43e223a0143892
            slot: parley.nvim:1
            requested_at: "2026-10-25T08:25:10.487896Z"
          phase: finished
          pid: 69474
          started_at: "2026-10-25T08:25:10.635795Z"
          finished_at: "2026-10-25T08:29:44.740427Z"
          session_id: dc631e37-4533-4e0d-adda-1901fc143962
          outcome: returned
      actual_inputs:
        version: 4
        method: active-time-v3-branch-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 42a7409870a66fa1f888362a9c43e223a0143892
        tracker_head: e5cba381a5b9364c1623c1a54aaf97b85e2f0a42
        branch_point: 6db317ab9ec7712ebaeb14c247a494df3bfde2e8
        since: "2026-10-25T00:03:36-07:00"
        until: "2026-10-25T01:22:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-25T00:03:36-07:00"
              end: "2026-10-25T01:22:55-07:00"
              began: "2026-10-25T00:03:36-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 8f0815e0b149f9478927b01947fa616e22b9cc462bc0198aac1adcbf66b336fb
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 22832516
              windows:
                - start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
              dispatch_windows:
                - start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T01:22:55-07:00"
        queue_waits:
            - attempt_id: ff450268af020decd5469a24f6fa182d
              slot: parley.nvim:1
              record_digest: 56be251b5b77e0883c658663d8907c293ae5493b1ba24a7cb0e4abfce7e4ceb3
              start: "2026-10-25T07:28:29.790111Z"
              end: "2026-10-25T08:13:48.317208Z"
              queue_seconds: 2718.527097
              raw_seconds: 2718.527097
              exact: true
        branches:
            - root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              path: /Users/xianxu/workspace/parley.nvim/.git/worktrees/parley.nvim/logs/HEAD
              head: 42a7409870a66fa1f888362a9c43e223a0143892
              branch: 000440-a-predicate-wait-doing-child-rpc-never-times-out
              digest: 9469f6255d87dab7319285281809e02f6be89e5c721f9b5024fe2765bc4fc63f
              bytes: 168509
              intervals:
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/0ed605c3-75e4-4fc0-a1aa-e5a2cf6a5f5e
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/25391601-bb6c-4495-93ec-9ca17df63658
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/294ab56e-1303-48a8-9312-df8d4e484ea9
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/3d73ddc6-2c4d-4617-be75-f1e690b92305
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/53acb8ed-7204-4e14-bfb8-954e774fcdbb
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/5fd9cfe6-ba3b-4799-a2d6-18a004661e57
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/614d7266-98f2-4cb4-901b-cb2b908f26f6
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/81b9dc8e-790b-48a3-b384-a7f93c050e98
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/aa2f3d6f-e82d-4001-9c1c-3fed00c10f1b
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/b73b2e5c-68c3-4d9c-983f-c8ca4e5eb0ec
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ccd7458f-0a93-435d-9ad8-ef93721fedc3
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/d0921b18-345d-44d2-afbf-ee8330b92a0b
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source_index: 0
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source_index: 0
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/df9ebbe6-ac00-4c6f-89b9-58f49ba70a55
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: claude/ed0a4bfd-765f-4ca3-8eed-f8264fbaf6ba
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a138e8-e0b1-7a60-bb7e-e76aa10a425e
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423b-c235-7140-aec0-476b729ef99f
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-282c-7252-b50a-a43332482dec
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1423e-b822-7e10-98ba-78536ba8f5c3
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a49-286a-71d0-a9b1-3b2a480c0c3d
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4b-894e-7253-a995-a82ca9bdaccb
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4c-e538-7380-a5e6-3262ec911043
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a14a4d-6978-7983-87a6-96666ef3d84d
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162f7-67e1-7a50-85ba-8daa8c35ef7c
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a16386-b503-73f3-934d-1c36ecd543ba
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-6e36-7142-94d2-59f91265ff08
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T00:03:36-07:00"
                  end: "2026-10-25T07:03:48Z"
                  branch: main-slot1
                  kind: resting-excluded
                - source: codex/01a1638c-e3cf-7b91-a5c2-fb326f3ae063
                  start: "2026-10-25T07:03:48Z"
                  end: "2026-10-25T01:22:55-07:00"
                  kind: branch
      "n": 1
      timestamp: "2026-10-25T01:29:46-07:00"
      dispatched: "2026-10-25T01:25:10-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Borrowed socket Child in couch-editor-probe leaks its per-child request timer
          detail: scripts/couch-editor-probe.lua:77 borrows the Child metatable for a socket channel and never joins it, so the timer that Child:request now stores on that table is never closed. This contradicts atlas/infra/test_harness.md:350 ("closed when the child is joined") and the plan's FUNERAL claim. Close connected.timer after chanclose, or add a release method that closes the timer without joining. It is the only borrower of Child.request in the tree.
          family: handle-lifetime-tied-to-join
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 42a7409870a66fa1f888362a9c43e223a0143892
      blocked: false
---

# Gate ledger — parley.nvim#440 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-25T01:29:46-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `handle-lifetime-tied-to-join` (kind: defect) Borrowed socket Child in couch-editor-probe leaks its per-child request timer
  scripts/couch-editor-probe.lua:77 borrows the Child metatable for a socket channel and never joins it, so the timer that Child:request now stores on that table is never closed. This contradicts atlas/infra/test_harness.md:350 ("closed when the child is joined") and the plan's FUNERAL claim. Close connected.timer after chanclose, or add a release method that closes the timer without joining. It is the only borrower of Child.request in the tree.

## Open findings

- **BR-1** [Minor] `handle-lifetime-tied-to-join` (kind: defect) Borrowed socket Child in couch-editor-probe leaks its per-child request timer
