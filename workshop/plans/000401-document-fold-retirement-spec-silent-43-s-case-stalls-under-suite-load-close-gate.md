---
gate: boundary-review
issue: 401
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2ef97936-8c5b-470d-be8c-a555a1167992
            repository: github.com/xianxu/parley.nvim
            issue_id: "000401"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/f529fa537503d4c9
            reviewed_head: c676e97c0e62e3c2dd6b8aad947c979d8bd1ff59
            slot: parley.nvim:3
            requested_at: "2026-10-20T01:23:16.664057Z"
          phase: finished
          pid: 28415
          started_at: "2026-10-20T01:23:16.751915Z"
          finished_at: "2026-10-20T01:25:00.232673Z"
          session_id: 4a1286f6-da49-41b9-8ae2-e5d80c370fcc
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: c676e97c0e62e3c2dd6b8aad947c979d8bd1ff59
        tracker_head: a1ed5460efe8c2e9955045e36b54aabe8156e556
        branch_point: 7c99d689403ce315f1eca1dc5f5ba1924ac8d167
        since: "2026-10-19T17:57:41-07:00"
        until: "2026-10-19T18:22:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T17:57:41-07:00"
              end: "2026-10-19T18:22:55-07:00"
              began: "2026-10-19T17:57:41-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 839598adf1a6737f61d783aed369f4b4353f9a9ae83466378b7387b3571968ce
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 10827470
              windows:
                - start: "2026-10-19T17:57:41-07:00"
                  end: "2026-10-19T18:22:55-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 5.523383333333333
      "n": 1
      timestamp: "2026-10-19T18:25:00-07:00"
      dispatched: "2026-10-19T18:23:16-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: embedded_nvim.start does not set the runtimepath as the Plan claims; nine call sites still restate it
          detail: 'The Plan says start() "appends the repo to the child''s runtimepath", but M.start (tests/helpers/embedded_nvim.lua:54-62) never touches it (ARCH-DRY, plan drift). Instances: document_fold_retirement_spec.lua:7, document_fold_uncertainty_retirement_spec.lua:7, document_presentation_reentrant_spec.lua:8, document_move_spec.lua:423, document_lease_spec.lua:16, entity_navigation_native_spec.lua:28, session_sync_native_spec.lua:100 and :683, stream_view_spec.lua:11 (prepend). Fix: add a runtime option to start and delete the per-spec lines, or add a Revisions entry.'
          family: helper-owns-shared-setup
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Embedded.start leaks the spawned child if nvim_ui_attach raises
          detail: 'The child is spawned before the attach, but start never returns it on failure, so the caller''s after_each cannot stop it. Before this change the spec held the job id before attaching. Fix: pcall the attach, stop the child, then re-raise.'
          family: spawned-child-ownership
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Arch guard misses pcall(vim.rpcrequest, ...) and rpcnotify; its user floor counts itself and the helper spec
          detail: RAW only matches "rpcrequest(" and quoted "--embed". The users floor of 9 currently counts 11 files, including tests/arch/embedded_rpc_spec.lua and tests/integration/embedded_nvim_spec.lua, so two real users could disappear unnoticed.
          family: arch-guard-coverage
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Done-when asks for a margin measured under suite load; only run-alone times were logged
          detail: The log records 1-2 s per spec run alone on both runtimes. No timing under parallel suite load was recorded, though the margin against the 50 s budget is plainly large.
          family: done-when-both-states
          round: 1
        - kind: defect
          id: BR-5
          severity: Minor
          title: tool_folds comments still hardcode 50k instead of naming INTERACTIVE_ROWS
          detail: lua/parley/tool_folds.lua:19 and :263 restate the field's default value as a fixed number now that a spec can change it.
          family: comment-restates-constant
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 52c2925f-38c7-4a13-9a4b-c96f2a2bdb1a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000401"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/f1f8f9ffa319cce7
            reviewed_head: 08c40cc09b69f2eb922f80eedc31c87ee3de2c99
            slot: parley.nvim:3
            requested_at: "2026-10-20T01:34:58.306301Z"
          phase: finished
          pid: 46162
          started_at: "2026-10-20T01:34:58.397947Z"
          finished_at: "2026-10-20T01:38:16.51042Z"
          session_id: 06a9602d-565b-4347-a8e3-e2d987660102
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 08c40cc09b69f2eb922f80eedc31c87ee3de2c99
        tracker_head: a1ed5460efe8c2e9955045e36b54aabe8156e556
        branch_point: 7c99d689403ce315f1eca1dc5f5ba1924ac8d167
        since: "2026-10-19T17:57:41-07:00"
        until: "2026-10-19T18:34:38-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T17:57:41-07:00"
              end: "2026-10-19T18:34:38-07:00"
              began: "2026-10-19T17:57:41-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d1869b41251e82f9097ea3bf48bac280d2741cddd14c17179b84d4b335d2c084
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 11106443
              windows:
                - start: "2026-10-19T17:57:41-07:00"
                  end: "2026-10-19T18:34:38-07:00"
        queue_waits:
            - attempt_id: f72dafcf8f78d73827f250cfda6acc42
              slot: parley.nvim:3
              record_digest: be81c021f47469e6ddca03f1b4f2c4e55778910a126bd4ed99c92cf52fc991c6
              start: "2026-10-20T01:23:01.648852Z"
              end: "2026-10-20T01:31:08.786391Z"
              queue_seconds: 487.137539
              raw_seconds: 487.137539
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 5.523383333333333
        cuts:
            - dispatched: "2026-10-19T18:23:16-07:00"
              finalized: "2026-10-19T18:25:00-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-19T18:38:17-07:00"
      dispatched: "2026-10-19T18:34:58-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: M.start appends (or prepends) cwd at embedded_nvim.lua:67; grep finds no rtp restatement left in the nine specs; their existing require('parley...') behavior is the evidence.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: The pcall/stop in M.start (embedded_nvim.lua:62-71) is plausible, but no test drives a failed setup and asserts the child is reaped, so there is no regression evidence.
          round: 2
        - id: BR-3
          disposition: addressed
          note: 'Red-checked: appending pcall(vim.rpcrequest, 0, "x") to stream_view_spec fails the guard naming the line; NOT_USERS excludes both non-users, so the floor counts exactly 9.'
          round: 2
        - id: BR-4
          disposition: addressed
          note: Log records 1 s and 2 s in the recorded parallel suite on c676e97; I reproduced 2 s each at load 11 on 12 CPUs.
          round: 2
        - id: BR-5
          disposition: addressed
          note: tool_folds.lua:19 and :263-264 now name M.INTERACTIVE_ROWS; prose-only.
          round: 2
      findings:
        - kind: defect
          id: BR-6
          severity: Critical
          title: REQUEST_MS (60 s) exceeds the runner's 50 s quiet-machine idle budget, so a wedged child still dies by an unnamed harness kill
          detail: 'embedded_nvim.lua:12 sets 4*arrival.MS = 60 s, but every helper user runs on spec_runner DEFAULT_TIMEOUT 50 s times load_factor (1 to 4). The retirement specs left the 180 s list in this same change. A probe spec spinning its child forever, run through the real runner at load 10 on 12 CPUs, ended "DEADLINE ... stalled after 0 completed case(s); idle 50000ms" with no method named, so Done-when clause 2 fails whenever load_factor is below about 1.2. Instances: helper comments :1-4 ("180 s") and :9-10, atlas/infra/test_harness.md:296-297, and the Plan''s REQUEST_MS rationale. Fix: derive REQUEST_MS from the runner''s idle budget (for example, the runner exports it to the spec child and the helper uses about half), pin it below that budget with a test, add a spec_runner.execute test where a spinning child''s failure names nvim_exec_lua rather than DEADLINE, and correct the comments, atlas and plan.'
          family: inner-deadline-derives-from-outer
          round: 2
        - kind: defect
          id: BR-7
          severity: Minor
          title: Helper comments restate harness values (180 s, at most 4) instead of naming their source
          detail: 'This is the 2nd finding in family comment-restates-constant. Rule: a comment names the source of a value (field, function, runner option), never the value itself. Instances in this window: embedded_nvim.lua:3 "(180 s)", already wrong for every helper user, and embedded_nvim.lua:9 "(at most 4)", which restates the Deadline.load_factor cap. Checked and fine: the dated "(nine specs on 2026-10-19)" in embedded_rpc_spec.lua.'
          family: comment-restates-constant
          round: 2
      recipe: small-diff-review
      isolation: checkout
      blocked: true
---

# Gate ledger — parley.nvim#401 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T18:25:00-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `helper-owns-shared-setup` (kind: defect) embedded_nvim.start does not set the runtimepath as the Plan claims; nine call sites still restate it
  The Plan says start() "appends the repo to the child's runtimepath", but M.start (tests/helpers/embedded_nvim.lua:54-62) never touches it (ARCH-DRY, plan drift). Instances: document_fold_retirement_spec.lua:7, document_fold_uncertainty_retirement_spec.lua:7, document_presentation_reentrant_spec.lua:8, document_move_spec.lua:423, document_lease_spec.lua:16, entity_navigation_native_spec.lua:28, session_sync_native_spec.lua:100 and :683, stream_view_spec.lua:11 (prepend). Fix: add a runtime option to start and delete the per-spec lines, or add a Revisions entry.
- **BR-2** [Minor] `spawned-child-ownership` (kind: defect) Embedded.start leaks the spawned child if nvim_ui_attach raises
  The child is spawned before the attach, but start never returns it on failure, so the caller's after_each cannot stop it. Before this change the spec held the job id before attaching. Fix: pcall the attach, stop the child, then re-raise.
- **BR-3** [Minor] `arch-guard-coverage` (kind: defect) Arch guard misses pcall(vim.rpcrequest, ...) and rpcnotify; its user floor counts itself and the helper spec
  RAW only matches "rpcrequest(" and quoted "--embed". The users floor of 9 currently counts 11 files, including tests/arch/embedded_rpc_spec.lua and tests/integration/embedded_nvim_spec.lua, so two real users could disappear unnoticed.
- **BR-4** [Minor] `done-when-both-states` (kind: defect) Done-when asks for a margin measured under suite load; only run-alone times were logged
  The log records 1-2 s per spec run alone on both runtimes. No timing under parallel suite load was recorded, though the margin against the 50 s budget is plainly large.
- **BR-5** [Minor] `comment-restates-constant` (kind: defect) tool_folds comments still hardcode 50k instead of naming INTERACTIVE_ROWS
  lua/parley/tool_folds.lua:19 and :263 restate the field's default value as a fixed number now that a spec can change it.

## Round 2 — 2026-10-19T18:38:17-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — M.start appends (or prepends) cwd at embedded_nvim.lua:67; grep finds no rtp restatement left in the nine specs; their existing require('parley...') behavior is the evidence.
- BR-2 — not-addressed — The pcall/stop in M.start (embedded_nvim.lua:62-71) is plausible, but no test drives a failed setup and asserts the child is reaped, so there is no regression evidence.
- BR-3 — addressed — Red-checked: appending pcall(vim.rpcrequest, 0, "x") to stream_view_spec fails the guard naming the line; NOT_USERS excludes both non-users, so the floor counts exactly 9.
- BR-4 — addressed — Log records 1 s and 2 s in the recorded parallel suite on c676e97; I reproduced 2 s each at load 11 on 12 CPUs.
- BR-5 — addressed — tool_folds.lua:19 and :263-264 now name M.INTERACTIVE_ROWS; prose-only.

### Raised

- **BR-6** [Critical] `inner-deadline-derives-from-outer` (kind: defect) REQUEST_MS (60 s) exceeds the runner's 50 s quiet-machine idle budget, so a wedged child still dies by an unnamed harness kill
  embedded_nvim.lua:12 sets 4*arrival.MS = 60 s, but every helper user runs on spec_runner DEFAULT_TIMEOUT 50 s times load_factor (1 to 4). The retirement specs left the 180 s list in this same change. A probe spec spinning its child forever, run through the real runner at load 10 on 12 CPUs, ended "DEADLINE ... stalled after 0 completed case(s); idle 50000ms" with no method named, so Done-when clause 2 fails whenever load_factor is below about 1.2. Instances: helper comments :1-4 ("180 s") and :9-10, atlas/infra/test_harness.md:296-297, and the Plan's REQUEST_MS rationale. Fix: derive REQUEST_MS from the runner's idle budget (for example, the runner exports it to the spec child and the helper uses about half), pin it below that budget with a test, add a spec_runner.execute test where a spinning child's failure names nvim_exec_lua rather than DEADLINE, and correct the comments, atlas and plan.
- **BR-7** [Minor] `comment-restates-constant` (kind: defect) Helper comments restate harness values (180 s, at most 4) instead of naming their source
  This is the 2nd finding in family comment-restates-constant. Rule: a comment names the source of a value (field, function, runner option), never the value itself. Instances in this window: embedded_nvim.lua:3 "(180 s)", already wrong for every helper user, and embedded_nvim.lua:9 "(at most 4)", which restates the Deadline.load_factor cap. Checked and fine: the dated "(nine specs on 2026-10-19)" in embedded_rpc_spec.lua.

## Open findings

- **BR-2** [Minor] `spawned-child-ownership` (kind: defect) Embedded.start leaks the spawned child if nvim_ui_attach raises
- **BR-6** [Critical] `inner-deadline-derives-from-outer` (kind: defect) REQUEST_MS (60 s) exceeds the runner's 50 s quiet-machine idle budget, so a wedged child still dies by an unnamed harness kill
- **BR-7** [Minor] `comment-restates-constant` (kind: defect) Helper comments restate harness values (180 s, at most 4) instead of naming their source
