---
gate: boundary-review
issue: 402
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 184c0dcb-071c-414a-abe5-a32867a3e902
            repository: github.com/xianxu/parley.nvim
            issue_id: "000402"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/421fa4b390a3fb20
            reviewed_head: d07a3ac51f57971f3bb17587629aeeab85806978
            slot: parley.nvim:3
            requested_at: "2026-10-20T04:57:59.823456Z"
          phase: finished
          pid: 33968
          started_at: "2026-10-20T04:57:59.950006Z"
          finished_at: "2026-10-20T05:02:42.800631Z"
          session_id: efe05a62-49c8-4c82-b849-d42ddfc81f33
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d07a3ac51f57971f3bb17587629aeeab85806978
        tracker_head: 12a9548fb7ca1a9b3ef88c4526d83b21e9b3bd64
        branch_point: 45ec2ab101bd9644318e25145d6638773391b96e
        since: "2026-10-19T21:37:00-07:00"
        until: "2026-10-19T21:57:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T21:37:00-07:00"
              end: "2026-10-19T21:57:30-07:00"
              began: "2026-10-19T21:37:00-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: c76de02b1ad91e255ce53ef32a945925b7157a3b00cd648e8b13ba172592e7ec
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 13006419
              windows:
                - start: "2026-10-19T21:37:00-07:00"
                  end: "2026-10-19T21:57:30-07:00"
      "n": 1
      timestamp: "2026-10-19T22:02:43-07:00"
      dispatched: "2026-10-19T21:57:59-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: 'detach=true''s grandchild-group purpose has no regression test; the #402 tests pass without it'
          detail: 'Reverting `detach = true` (spec_runner.lua:70) leaves all four #402 tests green, because the embedded nvim is a jobstart child the registry kills. Only five older deadline tests fail, because signal_group signals just -child.pid. Every instance in the window uses only jobstart descendants: idle-deadline case, runner SIGTERM case, runner SIGINT case (spec_runner_native_spec.lua:152-173). Add a fixture with a vim.system or uv.spawn grandchild whose pid must be gone after the idle kill, check it goes red without detach, and correct the Plan''s red-check line.'
          family: kept-mechanism-untested
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Leader group is signalled without the bare-pid fallback or identity guard that recorded jobs get
          detail: spec_runner.lua:60 sends only uv.kill(-child.pid). Jobs.signal falls back to the bare pid and checks start time first. The leader is also re-signalled after it is reaped (timer path plus TERM/KILL pass), with no guard against pid reuse in that short window.
          family: signal-target-guard-asymmetry
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: TERM, grace, KILL escalation written twice (end_group with uv.sleep vs the main path with vim.wait)
          detail: spec_runner.lua:63-67 and :108-112. The split is justified by the signal-callback context; add a comment, or share one helper that takes the wait function.
          family: duplicated-escalation-sequence
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Atlas and the spec_jobs comment don't say the registry only covers vim.fn.jobstart
          detail: 'termopen, nvim_call_function("jobstart") and Vimscript jobstart() skip the wrapper. None are used today; say so in atlas/infra/test_harness.md under the #402 section.'
          family: doc-scope-claim
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
---

# Gate ledger — parley.nvim#402 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T22:02:43-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `kept-mechanism-untested` (kind: defect) detach=true's grandchild-group purpose has no regression test; the #402 tests pass without it
  Reverting `detach = true` (spec_runner.lua:70) leaves all four #402 tests green, because the embedded nvim is a jobstart child the registry kills. Only five older deadline tests fail, because signal_group signals just -child.pid. Every instance in the window uses only jobstart descendants: idle-deadline case, runner SIGTERM case, runner SIGINT case (spec_runner_native_spec.lua:152-173). Add a fixture with a vim.system or uv.spawn grandchild whose pid must be gone after the idle kill, check it goes red without detach, and correct the Plan's red-check line.
- **BR-2** [Minor] `signal-target-guard-asymmetry` (kind: defect) Leader group is signalled without the bare-pid fallback or identity guard that recorded jobs get
  spec_runner.lua:60 sends only uv.kill(-child.pid). Jobs.signal falls back to the bare pid and checks start time first. The leader is also re-signalled after it is reaped (timer path plus TERM/KILL pass), with no guard against pid reuse in that short window.
- **BR-3** [Minor] `duplicated-escalation-sequence` (kind: defect) TERM, grace, KILL escalation written twice (end_group with uv.sleep vs the main path with vim.wait)
  spec_runner.lua:63-67 and :108-112. The split is justified by the signal-callback context; add a comment, or share one helper that takes the wait function.
- **BR-4** [Minor] `doc-scope-claim` (kind: defect) Atlas and the spec_jobs comment don't say the registry only covers vim.fn.jobstart
  termopen, nvim_call_function("jobstart") and Vimscript jobstart() skip the wrapper. None are used today; say so in atlas/infra/test_harness.md under the #402 section.

## Open findings

- **BR-1** [Important] `kept-mechanism-untested` (kind: defect) detach=true's grandchild-group purpose has no regression test; the #402 tests pass without it
- **BR-2** [Minor] `signal-target-guard-asymmetry` (kind: defect) Leader group is signalled without the bare-pid fallback or identity guard that recorded jobs get
- **BR-3** [Minor] `duplicated-escalation-sequence` (kind: defect) TERM, grace, KILL escalation written twice (end_group with uv.sleep vs the main path with vim.wait)
- **BR-4** [Minor] `doc-scope-claim` (kind: defect) Atlas and the spec_jobs comment don't say the registry only covers vim.fn.jobstart
