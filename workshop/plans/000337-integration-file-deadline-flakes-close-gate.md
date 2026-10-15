---
gate: boundary-review
issue: 337
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d5cd5bca-5efd-429b-9fed-f28c7351ad9a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000337"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/2aa9432f73e67dd3
            reviewed_head: 775cb6f922c13217daee958b9151817157832f6a
            slot: parley.nvim:2
            requested_at: "2026-10-15T23:23:01.811314Z"
          phase: finished
          pid: 76285
          started_at: "2026-10-15T23:23:01.916292Z"
          finished_at: "2026-10-15T23:24:22.562828Z"
          session_id: 01a141e0-50a5-7c73-961f-50dcaf436396
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 775cb6f922c13217daee958b9151817157832f6a
        tracker_head: 6e5ffdd2b2dce607c36d6899e034e16e40274fb3
        branch_point: 2e143c9da23ff52b5926e241dc59f2c61d5662f5
        since: "2026-10-15T16:04:16-07:00"
        until: "2026-10-15T16:22:48-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T16:04:16-07:00"
              end: "2026-10-15T16:22:48-07:00"
              began: "2026-10-15T16:04:16-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 2ca2b1ab9941db0a124330da1ebf094eef5c0f5fc18945438103fd6fa4fb0322
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 36455343
              windows:
                - start: "2026-10-15T16:04:16-07:00"
                  end: "2026-10-15T16:22:48-07:00"
      "n": 1
      timestamp: "2026-10-15T16:24:23-07:00"
      dispatched: "2026-10-15T16:23:01-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Native timeout tests fail at the supported load cap
          detail: tests/integration/spec_runner_native_spec.lua:62, :90 and :106 all require "stalled", but Runner.execute samples real machine load (tests/helpers/spec_runner.lua:35). At factor 4, the idle budget equals the absolute ceiling, whose documented precedence correctly produces "absolute-expired". Running this spec with vim.uv.loadavg returning 100000 reproduced all three failures (3 passed, 3 failed; exit 1). These are every instance of this assumption in the window. Inject controlled load/CPU inputs for reason-specific conformance tests and exercise both ordinary and capped load, preserving the policy's absolute-ceiling precedence. This undermines the load-flake purpose checked by ARCH-PURPOSE.
          family: control-environment-dependent-test-inputs
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 30618885-c6d8-49d5-8055-a0d8b0a0c571
            repository: github.com/xianxu/parley.nvim
            issue_id: "000337"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/e413f1475bc33c40
            reviewed_head: 013b81fccc9f2153a1202fff33c01460106e1f15
            slot: parley.nvim:2
            requested_at: "2026-10-15T23:58:33.394372Z"
          phase: finished
          pid: 85247
          started_at: "2026-10-15T23:58:33.490249Z"
          finished_at: "2026-10-15T23:59:22.708604Z"
          session_id: 01a14200-d6f3-7c20-8391-512b0cc709cf
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 013b81fccc9f2153a1202fff33c01460106e1f15
        tracker_head: e74e889292c22b55adceb1c39e883315c925622a
        branch_point: 8023e3acb99e88c79d2c51aef576ab5d42f73015
        since: "2026-10-15T16:04:16-07:00"
        until: "2026-10-15T16:58:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T16:04:16-07:00"
              end: "2026-10-15T16:58:21-07:00"
              began: "2026-10-15T16:04:16-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 64d786bc1c424a791c7604fe055cb6f52af277072eb2ea0076299e1bc637478d
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 37704069
              windows:
                - start: "2026-10-15T16:04:16-07:00"
                  end: "2026-10-15T16:58:21-07:00"
        cuts:
            - dispatched: "2026-10-15T16:23:01-07:00"
              finalized: "2026-10-15T16:24:23-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T16:59:23-07:00"
      dispatched: "2026-10-15T16:58:33-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: All three stalled-reason tests now receive controlled ordinary load/CPU inputs, and the new capped-load case exercises absolute precedence. All seven native tests pass with machine load forced to 100000. Removing the runner's injected-input handling in memory makes the capped-load regression fail at spec_runner_native_spec.lua:103 (6 passed, 1 failed; exit 1).
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 013b81fccc9f2153a1202fff33c01460106e1f15
      blocked: false
---

# Gate ledger — parley.nvim#337 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T16:24:23-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `control-environment-dependent-test-inputs` (kind: defect) Native timeout tests fail at the supported load cap
  tests/integration/spec_runner_native_spec.lua:62, :90 and :106 all require "stalled", but Runner.execute samples real machine load (tests/helpers/spec_runner.lua:35). At factor 4, the idle budget equals the absolute ceiling, whose documented precedence correctly produces "absolute-expired". Running this spec with vim.uv.loadavg returning 100000 reproduced all three failures (3 passed, 3 failed; exit 1). These are every instance of this assumption in the window. Inject controlled load/CPU inputs for reason-specific conformance tests and exercise both ordinary and capped load, preserving the policy's absolute-ceiling precedence. This undermines the load-flake purpose checked by ARCH-PURPOSE.

## Round 2 — 2026-10-15T16:59:23-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — All three stalled-reason tests now receive controlled ordinary load/CPU inputs, and the new capped-load case exercises absolute precedence. All seven native tests pass with machine load forced to 100000. Removing the runner's injected-input handling in memory makes the capped-load regression fail at spec_runner_native_spec.lua:103 (6 passed, 1 failed; exit 1).

## Open findings

(none — every finding has been disposed)
