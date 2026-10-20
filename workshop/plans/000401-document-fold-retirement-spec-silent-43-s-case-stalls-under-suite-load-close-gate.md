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

## Open findings

- **BR-1** [Important] `helper-owns-shared-setup` (kind: defect) embedded_nvim.start does not set the runtimepath as the Plan claims; nine call sites still restate it
- **BR-2** [Minor] `spawned-child-ownership` (kind: defect) Embedded.start leaks the spawned child if nvim_ui_attach raises
- **BR-3** [Minor] `arch-guard-coverage` (kind: defect) Arch guard misses pcall(vim.rpcrequest, ...) and rpcnotify; its user floor counts itself and the helper spec
- **BR-4** [Minor] `done-when-both-states` (kind: defect) Done-when asks for a margin measured under suite load; only run-alone times were logged
- **BR-5** [Minor] `comment-restates-constant` (kind: defect) tool_folds comments still hardcode 50k instead of naming INTERACTIVE_ROWS
