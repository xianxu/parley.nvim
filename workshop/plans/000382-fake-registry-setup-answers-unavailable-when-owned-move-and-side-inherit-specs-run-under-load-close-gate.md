---
gate: boundary-review
issue: 382
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d387f071-c04f-4f43-a8ed-5bcccd9a5cd5
            repository: github.com/xianxu/parley.nvim
            issue_id: "000382"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/329bdd0a4d33e763
            reviewed_head: 09ca797618c2e5807a1621f51ebceab46fe5f733
            slot: parley.nvim:4
            requested_at: "2026-10-18T06:11:06.171933Z"
          phase: finished
          pid: 55361
          started_at: "2026-10-18T06:11:06.27156Z"
          finished_at: "2026-10-18T06:13:45.624522Z"
          session_id: ee85d8e9-5e16-4db9-b5f1-f0d7eba939ec
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 09ca797618c2e5807a1621f51ebceab46fe5f733
        tracker_head: 1992984d6edac7753b6f6fc0e2ba8c1fcd4b20b2
        branch_point: 6e571cf4a8f0c46687f0329c0c3721f586748742
        since: "2026-10-17T22:18:10-07:00"
        until: "2026-10-17T23:10:40-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T22:18:10-07:00"
              end: "2026-10-17T23:10:40-07:00"
              began: "2026-10-17T22:18:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: e7842fc47bd08937686ac4c0591121e874ae9785ca1d1094e8239355b2fce183
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 41035580
              windows:
                - start: "2026-10-17T22:18:10-07:00"
                  end: "2026-10-17T23:10:40-07:00"
        queue_waits:
            - attempt_id: 98340b6962a023c03fbfc9eb0bbf9e1b
              slot: parley.nvim:4
              record_digest: cdd93e682948bca4dbbe4a06a0859c1ed9255e0788efb3484860e58ed6ee7384
              start: "2026-10-18T05:41:20.987737Z"
              end: "2026-10-18T06:06:37.339353Z"
              queue_seconds: 1516.351616
              raw_seconds: 1516.351616
              exact: true
      "n": 1
      timestamp: "2026-10-17T23:13:46-07:00"
      dispatched: "2026-10-17T23:11:06-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Journaled document_move renames get 1x submit deadline while the native rename gets 3x; atlas says registry owns all agentic deadlines
          detail: 'Family instances in this window: document_move.lua:994 and :1283 (no registry_options, so 15 s default) vs agentic_document.lua:380 (3x config_ms, 45 s, rule kept locally) and agentic_document.lua:618 (ms + 1000 margin kept locally). atlas/modes/session_sync.md:283 says document_registry owns the agentic deadlines; config.lua:500 and tests/helpers/arrival.lua describe a rename as getting three deadlines. Either derive both rename paths from one registry rename deadline helper, or narrow the atlas to say it owns the default deadline.'
          family: deadline-single-owner
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 09ca797618c2e5807a1621f51ebceab46fe5f733
      blocked: false
---

# Gate ledger — parley.nvim#382 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T23:13:46-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `deadline-single-owner` (kind: defect) Journaled document_move renames get 1x submit deadline while the native rename gets 3x; atlas says registry owns all agentic deadlines
  Family instances in this window: document_move.lua:994 and :1283 (no registry_options, so 15 s default) vs agentic_document.lua:380 (3x config_ms, 45 s, rule kept locally) and agentic_document.lua:618 (ms + 1000 margin kept locally). atlas/modes/session_sync.md:283 says document_registry owns the agentic deadlines; config.lua:500 and tests/helpers/arrival.lua describe a rename as getting three deadlines. Either derive both rename paths from one registry rename deadline helper, or narrow the atlas to say it owns the default deadline.

## Open findings

- **BR-1** [Minor] `deadline-single-owner` (kind: defect) Journaled document_move renames get 1x submit deadline while the native rename gets 3x; atlas says registry owns all agentic deadlines
