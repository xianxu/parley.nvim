---
gate: boundary-review
issue: 394
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 40f5ec4c-d13c-49ff-9d2d-30d1b3e6afa2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000394"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/d0501a49ec530696
            reviewed_head: 73da5e8a628d5ea970a8591ddb41e21f0088529e
            slot: parley.nvim:3
            requested_at: "2026-10-19T21:25:12.849315Z"
          phase: finished
          pid: 53809
          started_at: "2026-10-19T21:25:13.109118Z"
          finished_at: "2026-10-19T21:36:44.103265Z"
          session_id: e76c35b5-7fe4-47db-b975-4ac9b60f666a
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 73da5e8a628d5ea970a8591ddb41e21f0088529e
        tracker_head: 3e0f96d752725819ea7beac02552eeeff253d627
        branch_point: e8f76c78941e4ca85064086760564479eb35fecb
        since: "2026-10-19T14:14:24-07:00"
        until: "2026-10-19T14:24:00-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T14:14:24-07:00"
              end: "2026-10-19T14:24:00-07:00"
              began: "2026-10-19T14:14:24-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 50b65a1fc8be8b9503064bc7d492684269aa5ead57e005da7943d1e83711ece9
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 8986087
              windows:
                - start: "2026-10-19T14:14:24-07:00"
                  end: "2026-10-19T14:24:00-07:00"
      "n": 1
      timestamp: "2026-10-19T14:36:45-07:00"
      dispatched: "2026-10-19T14:25:12-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Comment says "a timer never fires early", but the same file notes libuv truncation can fire a deadline about 1 ms early
          detail: tests/integration/document_registry_spec.lua:101 states an absolute that the file's own comment at :174-175 contradicts (a 300 ms deadline can read 299). The argument still holds because the hold is 3x the deadline; soften to "never fires materially early". This is the only instance in the window.
          family: doc-claim-overstated-absolute
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: 73da5e8a628d5ea970a8591ddb41e21f0088529e
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e9f5afbb-afda-4f55-a337-df7c80326716
            repository: github.com/xianxu/parley.nvim
            issue_id: "000394"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/c43fb374fd861e33
            reviewed_head: 6ead4772405e93e115d7b6f86be3c3f907e16778
            slot: parley.nvim:3
            requested_at: "2026-10-19T21:38:32.660345Z"
          phase: finished
          pid: 16470
          started_at: "2026-10-19T21:38:32.915457Z"
          finished_at: "2026-10-19T21:38:59.626169Z"
          session_id: 014b034a-bdbb-4afd-abac-eafed71c94f0
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 6ead4772405e93e115d7b6f86be3c3f907e16778
        tracker_head: ea380b0a4c4a52070e335a57fe9bafc19d032810
        branch_point: e8f76c78941e4ca85064086760564479eb35fecb
        since: "2026-10-19T14:14:24-07:00"
        until: "2026-10-19T14:37:07-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T14:14:24-07:00"
              end: "2026-10-19T14:37:07-07:00"
              began: "2026-10-19T14:14:24-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 9963876b6c2f50efebd15b67e6e45e7a8358dd61f1a133e98e1451729802266e
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 9055028
              windows:
                - start: "2026-10-19T14:14:24-07:00"
                  end: "2026-10-19T14:37:07-07:00"
        cuts:
            - dispatched: "2026-10-19T14:25:12-07:00"
              finalized: "2026-10-19T14:36:45-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-19T14:39:00-07:00"
      dispatched: "2026-10-19T14:38:32-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Comment at document_registry_spec.lua:100-103 drops "a timer never fires early", says the deadline is due ~300 ms into the 900 ms hold and may fire ~1 ms early, consistent with :174-175; sweeping the file's other absolutes (:99, :102) found them accurate.
          round: 2
      recipe: fix-review
      isolation: checkout
      reviewed: 6ead4772405e93e115d7b6f86be3c3f907e16778
      blocked: false
---

# Gate ledger — parley.nvim#394 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T14:36:45-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `doc-claim-overstated-absolute` (kind: defect) Comment says "a timer never fires early", but the same file notes libuv truncation can fire a deadline about 1 ms early
  tests/integration/document_registry_spec.lua:101 states an absolute that the file's own comment at :174-175 contradicts (a 300 ms deadline can read 299). The argument still holds because the hold is 3x the deadline; soften to "never fires materially early". This is the only instance in the window.

## Round 2 — 2026-10-19T14:39:00-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Comment at document_registry_spec.lua:100-103 drops "a timer never fires early", says the deadline is due ~300 ms into the 900 ms hold and may fire ~1 ms early, consistent with :174-175; sweeping the file's other absolutes (:99, :102) found them accurate.

## Open findings

(none — every finding has been disposed)
