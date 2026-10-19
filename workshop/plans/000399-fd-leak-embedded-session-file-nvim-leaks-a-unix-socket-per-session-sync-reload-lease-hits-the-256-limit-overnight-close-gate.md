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

## Open findings

- **BR-1** [Important] `secret-in-persisted-diagnostic` (kind: defect) fd capture writes child argv verbatim; curl children carry Authorization/x-api-key secrets
- **BR-2** [Important] `readme-config-surface` (kind: defect) README update appears missing for config key fd_watchdog_threshold and the fd-captures warning
- **BR-3** [Important] `flaky-timer-spec` (kind: defect) fd_watchdog integration spec "stays quiet" failed 1 of 10 runs under make test-spec
- **BR-4** [Minor] `once-per-process-contract` (kind: defect) M.stop resets `fired`, so re-running setup re-arms the "once per process" capture
- **BR-5** [Minor] `arch-dry-test-helper` (kind: defect) /dev/fd counting copied into three specs and duplicating the module's private count()
