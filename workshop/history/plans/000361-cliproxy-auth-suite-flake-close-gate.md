---
gate: boundary-review
issue: 361
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 988648ae-313b-4042-be57-0f9d45d37fdd
            repository: github.com/xianxu/parley.nvim
            issue_id: "000361"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/ce176c11e9286153
            reviewed_head: 15f3948fe88ef9ba9f1799abb9e34b555b9f5d5c
            slot: parley.nvim:4
            requested_at: "2026-10-17T10:23:20.627625Z"
          phase: finished
          pid: 70933
          started_at: "2026-10-17T10:23:20.832415Z"
          finished_at: "2026-10-17T10:26:00.296046Z"
          session_id: d9d98c43-d1e0-45f6-b06b-4ddd49339a3f
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 15f3948fe88ef9ba9f1799abb9e34b555b9f5d5c
        tracker_head: 2eaff915f79d9b18d8ca93562a985ac13ce3666f
        branch_point: 6759ce28d37377959224580f2118f0fdac4985b5
        since: "2026-10-17T02:19:20-07:00"
        until: "2026-10-17T03:22:46-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T02:19:20-07:00"
              end: "2026-10-17T03:22:46-07:00"
              began: "2026-10-17T02:19:20-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 5a72659902afef03f0ca46f20aea6050cd1a936a66e98a5dd35f0be357a60b67
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 30774468
              windows:
                - start: "2026-10-17T02:19:20-07:00"
                  end: "2026-10-17T03:22:46-07:00"
      "n": 1
      timestamp: "2026-10-17T03:26:01-07:00"
      dispatched: "2026-10-17T03:23:20-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Forced-window regression stubs _connect but lacks the lsof-absent pending guard
          detail: 'tests/integration/cliproxy_auth_login_spec.lua:141 replaces ready_port._connect with a stub that always succeeds. Where lsof is absent, is_listening returns not _lsof_present() (true), so readiness passes at once against a fake that is not yet bound, and the test fails deterministically. Add the same guard tests/unit/ready_port_spec.lua:85 uses: if not ready_port._lsof_present() then return pending("needs lsof to confirm the listener") end. This is the only unguarded test in the window that stubs _connect.'
          family: lsof-dependent-test-guard
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Plan and Log say 37 converted calls; the listed parts and the code give 38
          detail: Plan item and Log both say 37 (lifecycle 26, update 9, recovery_e2e, auth_login, fake_releases), which adds up to 38. The head has 38 require_listening call sites outside ready_port.lua and its unit spec. Fix both mentions.
          family: doc-count-claims
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: 12 existing sites still hand-write assert(ready_port.wait_listening(port), msg), repeating require_listening
          detail: 'ARCH-DRY. Sites: openai_tool_loop_spec:37, cliproxy_catalog_spec:22,141,155,214,350,430, fixture_reaping_spec:147, cliproxy_caller_teardown_spec:46, cliproxy_dispatch_spec:29, stream_integrity_spec:37, tests/helpers/provider_scenarios.lua:20. They are correct; converting them is optional cleanup.'
          family: ready-wait-assert-restated
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 747aede9-29d0-49ff-8453-5084834f0d78
            repository: github.com/xianxu/parley.nvim
            issue_id: "000361"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/070d05f3053a4a95
            reviewed_head: 12105c271e036569b9a917a5ca3da1c1860116ba
            slot: parley.nvim:4
            requested_at: "2026-10-17T11:25:44.919802Z"
          phase: finished
          pid: 94646
          started_at: "2026-10-17T11:25:45.01347Z"
          finished_at: "2026-10-17T11:29:10.8586Z"
          session_id: 220b9b12-b9d0-4d30-8c25-83078094c504
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 12105c271e036569b9a917a5ca3da1c1860116ba
        tracker_head: c584234f618d12f52e779caf2b8b3aed35c1e911
        branch_point: 6759ce28d37377959224580f2118f0fdac4985b5
        since: "2026-10-17T02:19:20-07:00"
        until: "2026-10-17T03:28:22-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T02:19:20-07:00"
              end: "2026-10-17T03:28:22-07:00"
              began: "2026-10-17T02:19:20-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 7fd684f24628d7fb3c66d01d9e01565a944365baf9c739c13a1712f10d8ed80a
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 31001120
              windows:
                - start: "2026-10-17T02:19:20-07:00"
                  end: "2026-10-17T03:28:22-07:00"
        cuts:
            - dispatched: "2026-10-17T03:23:20-07:00"
              finalized: "2026-10-17T03:26:01-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T04:29:12-07:00"
      dispatched: "2026-10-17T04:25:44-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: cliproxy_auth_login_spec.lua:148-150 now returns pending when lsof is absent (same guard as ready_port_spec.lua:85); the other _connect stubs either guard or stub _lsof_present; the spec passes 23/23 at head.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Plan item and Log now say 38, which matches the listed parts (26+9+1+1+1) and the original call sites.
          round: 2
        - id: BR-3
          disposition: addressed
          note: All 12 sites now call require_listening; no bare or asserted wait_listening is left outside ready_port and its unit spec; the affected specs all pass.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 12105c271e036569b9a917a5ca3da1c1860116ba
      blocked: false
---

# Gate ledger — parley.nvim#361 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T03:26:01-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `lsof-dependent-test-guard` (kind: defect) Forced-window regression stubs _connect but lacks the lsof-absent pending guard
  tests/integration/cliproxy_auth_login_spec.lua:141 replaces ready_port._connect with a stub that always succeeds. Where lsof is absent, is_listening returns not _lsof_present() (true), so readiness passes at once against a fake that is not yet bound, and the test fails deterministically. Add the same guard tests/unit/ready_port_spec.lua:85 uses: if not ready_port._lsof_present() then return pending("needs lsof to confirm the listener") end. This is the only unguarded test in the window that stubs _connect.
- **BR-2** [Minor] `doc-count-claims` (kind: defect) Plan and Log say 37 converted calls; the listed parts and the code give 38
  Plan item and Log both say 37 (lifecycle 26, update 9, recovery_e2e, auth_login, fake_releases), which adds up to 38. The head has 38 require_listening call sites outside ready_port.lua and its unit spec. Fix both mentions.
- **BR-3** [Minor] `ready-wait-assert-restated` (kind: defect) 12 existing sites still hand-write assert(ready_port.wait_listening(port), msg), repeating require_listening
  ARCH-DRY. Sites: openai_tool_loop_spec:37, cliproxy_catalog_spec:22,141,155,214,350,430, fixture_reaping_spec:147, cliproxy_caller_teardown_spec:46, cliproxy_dispatch_spec:29, stream_integrity_spec:37, tests/helpers/provider_scenarios.lua:20. They are correct; converting them is optional cleanup.

## Round 2 — 2026-10-17T04:29:12-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — cliproxy_auth_login_spec.lua:148-150 now returns pending when lsof is absent (same guard as ready_port_spec.lua:85); the other _connect stubs either guard or stub _lsof_present; the spec passes 23/23 at head.
- BR-2 — addressed — Plan item and Log now say 38, which matches the listed parts (26+9+1+1+1) and the original call sites.
- BR-3 — addressed — All 12 sites now call require_listening; no bare or asserted wait_listening is left outside ready_port and its unit spec; the affected specs all pass.

## Open findings

(none — every finding has been disposed)
