---
gate: boundary-review
issue: 399
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e9a80961-6cdc-4405-81a1-bac791b74e8d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000399"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/958cfbfc9d73b371
            reviewed_head: f5ba60ef647c77630c0dea439b370a21d5d14885
            slot: parley.nvim:3
            requested_at: "2026-10-19T14:53:31.994595Z"
          phase: finished
          pid: 18737
          started_at: "2026-10-19T14:53:32.242343Z"
          finished_at: "2026-10-19T14:58:59.504675Z"
          session_id: 144aab52-713d-4f01-ba5f-a0dc27d97a59
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f5ba60ef647c77630c0dea439b370a21d5d14885
        tracker_head: d523b7dbfd5fd591142205bb8be4b14169213fb7
        branch_point: c631353ce8819de93750cc88a9c90322adedcf0e
        since: "2026-10-19T07:21:18-07:00"
        until: "2026-10-19T07:52:45-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T07:21:18-07:00"
              end: "2026-10-19T07:52:45-07:00"
              began: "2026-10-19T07:21:18-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: c3ae0391a40849ea26ae666272a9b725253b14ff75a6c17d566198185e05c09e
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 6014912
              windows:
                - start: "2026-10-19T07:21:18-07:00"
                  end: "2026-10-19T07:52:45-07:00"
      "n": 1
      timestamp: "2026-10-19T07:59:00-07:00"
      dispatched: "2026-10-19T07:53:31-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: fd capture writes child argv verbatim; curl children carry Authorization/x-api-key secrets
          detail: fd_watchdog.children/report persist ps `command=` for each child to state_dir/fd-captures, while providers.lua:355,643,1069,1290, oauth.lua:1654 and cliproxy.lua:171 put bearer tokens and API keys on curl's argv (dispatcher.lua:886). Redact header values in the pure children/report step and add a unit case with a bearer-token curl row.
          family: secret-in-persisted-diagnostic
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: README update appears missing for config key fd_watchdog_threshold and the fd-captures warning
          detail: README.md:76-77 documents sibling session_sync_* keys; the new user-facing key, its 0-disables semantics, the once-per-process warning and the state_dir/fd-captures location are not mentioned.
          family: readme-config-surface
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: fd_watchdog integration spec "stays quiet" failed 1 of 10 runs under make test-spec
          detail: tests/integration/fd_watchdog_spec.lua:66 saw an unexpected warning once in 10 runs of `make test-spec SPEC=infra/fd_watchdog`. The shared `warnings` upvalue and the unchecked message content leave the source undiagnosable. Assert the message, and drain scheduled callbacks in after_each before restoring vim.notify.
          family: flaky-timer-spec
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: M.stop resets `fired`, so re-running setup re-arms the "once per process" capture
          detail: fd_watchdog.lua:125; the atlas says it fires once per process. The timer also keeps scanning after firing.
          family: once-per-process-contract
          round: 1
        - kind: defect
          id: BR-5
          severity: Minor
          title: /dev/fd counting copied into three specs and duplicating the module's private count()
          detail: session_sync_spec.lua:363,380 and fd_watchdog_spec.lua; expose M.count and reuse it.
          family: arch-dry-test-helper
          round: 1
      recipe: milestone-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ec9158f9-18ca-4e2d-ac06-1811435606e7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000399"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/371a869578589110
            reviewed_head: 637d080c05278db659d095dceb7b58ce5f8d174d
            slot: parley.nvim:3
            requested_at: "2026-10-19T15:07:24.015601Z"
          phase: finished
          pid: 56590
          started_at: "2026-10-19T15:07:24.240501Z"
          finished_at: "2026-10-19T15:14:23.763048Z"
          session_id: de19bc9c-25e5-4f82-a305-24c942a78042
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 637d080c05278db659d095dceb7b58ce5f8d174d
        tracker_head: d523b7dbfd5fd591142205bb8be4b14169213fb7
        branch_point: c631353ce8819de93750cc88a9c90322adedcf0e
        since: "2026-10-19T07:21:18-07:00"
        until: "2026-10-19T08:06:38-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T07:21:18-07:00"
              end: "2026-10-19T08:06:38-07:00"
              began: "2026-10-19T07:21:18-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 253080dec9739926c5de292c36ab2c3b78f493137f58bbad3e41911f6e684783
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 6289960
              windows:
                - start: "2026-10-19T07:21:18-07:00"
                  end: "2026-10-19T08:06:38-07:00"
        queue_waits:
            - attempt_id: a6494034c8fcb8f14e529d494fcc1a34
              slot: parley.nvim:3
              record_digest: cb65950cfcbf949a8eb75456f6c2b7242b0823ee868d8da1877e60411ac41742
              start: "2026-10-19T14:52:56.584346Z"
              end: "2026-10-19T14:53:15.069543Z"
              queue_seconds: 18.485197
              raw_seconds: 18.485197
              exact: true
        cuts:
            - dispatched: "2026-10-19T07:53:31-07:00"
              finalized: "2026-10-19T07:59:00-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-19T08:14:25-07:00"
      dispatched: "2026-10-19T08:07:23-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: ps now asked for comm= (fd_watchdog.lua:85); reverting to command= turns the integration spec red with the SECRET-TOKEN row.
          round: 2
        - id: BR-2
          disposition: addressed
          note: README.md:90-95 documents fd_watchdog_threshold, default 200, 0 disables, warn once, state_dir/fd-captures, keep five, no child arguments.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Each test has its own collector, and the re-arm that let a slow real-lsof capture land late is gone (BR-4); 8 of 8 runs green.
          round: 2
        - id: BR-4
          disposition: addressed
          note: stop() no longer resets fired, the timer stops after firing, setup returns early when fired; the re-setup assertion covers it.
          round: 2
        - id: BR-5
          disposition: addressed
          note: M.count is public; session_sync_spec and fd_watchdog_spec use it, no copied /dev/fd loops remain.
          round: 2
      findings:
        - kind: defect
          id: BR-6
          severity: Minor
          title: The issue's Spec paragraph still describes the root-cause fix the Revisions entry dropped
          detail: Issue line 32 says to fix every child's stdio at the root; the 2026-10-19 hub rescope made it detect-and-capture. Rewrite the Spec to match.
          family: stale-spec-after-rescope
          round: 2
      recipe: milestone-review
      isolation: checkout
      reviewed: 637d080c05278db659d095dceb7b58ce5f8d174d
      blocked: false
---

# Gate ledger — parley.nvim#399 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T07:59:00-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `secret-in-persisted-diagnostic` (kind: defect) fd capture writes child argv verbatim; curl children carry Authorization/x-api-key secrets
  fd_watchdog.children/report persist ps `command=` for each child to state_dir/fd-captures, while providers.lua:355,643,1069,1290, oauth.lua:1654 and cliproxy.lua:171 put bearer tokens and API keys on curl's argv (dispatcher.lua:886). Redact header values in the pure children/report step and add a unit case with a bearer-token curl row.
- **BR-2** [Important] `readme-config-surface` (kind: defect) README update appears missing for config key fd_watchdog_threshold and the fd-captures warning
  README.md:76-77 documents sibling session_sync_* keys; the new user-facing key, its 0-disables semantics, the once-per-process warning and the state_dir/fd-captures location are not mentioned.
- **BR-3** [Important] `flaky-timer-spec` (kind: defect) fd_watchdog integration spec "stays quiet" failed 1 of 10 runs under make test-spec
  tests/integration/fd_watchdog_spec.lua:66 saw an unexpected warning once in 10 runs of `make test-spec SPEC=infra/fd_watchdog`. The shared `warnings` upvalue and the unchecked message content leave the source undiagnosable. Assert the message, and drain scheduled callbacks in after_each before restoring vim.notify.
- **BR-4** [Minor] `once-per-process-contract` (kind: defect) M.stop resets `fired`, so re-running setup re-arms the "once per process" capture
  fd_watchdog.lua:125; the atlas says it fires once per process. The timer also keeps scanning after firing.
- **BR-5** [Minor] `arch-dry-test-helper` (kind: defect) /dev/fd counting copied into three specs and duplicating the module's private count()
  session_sync_spec.lua:363,380 and fd_watchdog_spec.lua; expose M.count and reuse it.

## Round 2 — 2026-10-19T08:14:25-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — ps now asked for comm= (fd_watchdog.lua:85); reverting to command= turns the integration spec red with the SECRET-TOKEN row.
- BR-2 — addressed — README.md:90-95 documents fd_watchdog_threshold, default 200, 0 disables, warn once, state_dir/fd-captures, keep five, no child arguments.
- BR-3 — addressed — Each test has its own collector, and the re-arm that let a slow real-lsof capture land late is gone (BR-4); 8 of 8 runs green.
- BR-4 — addressed — stop() no longer resets fired, the timer stops after firing, setup returns early when fired; the re-setup assertion covers it.
- BR-5 — addressed — M.count is public; session_sync_spec and fd_watchdog_spec use it, no copied /dev/fd loops remain.

### Raised

- **BR-6** [Minor] `stale-spec-after-rescope` (kind: defect) The issue's Spec paragraph still describes the root-cause fix the Revisions entry dropped
  Issue line 32 says to fix every child's stdio at the root; the 2026-10-19 hub rescope made it detect-and-capture. Rewrite the Spec to match.

## Open findings

- **BR-6** [Minor] `stale-spec-after-rescope` (kind: defect) The issue's Spec paragraph still describes the root-cause fix the Revisions entry dropped
