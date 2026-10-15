---
gate: plan-quality
issue: 332
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: d26ea34e-4874-4c94-bcd7-e9095db8ccba
            repository: github.com/xianxu/parley.nvim
            issue_id: "000332"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
            reviewed_head: aa7884c73a6860311cb296604cd982df8bef71d3
            slot: parley.nvim:2
            requested_at: "2026-10-15T20:27:15.445697Z"
          phase: finished
          pid: 6339
          started_at: "2026-10-15T20:27:15.666694Z"
          finished_at: "2026-10-15T20:28:29.814124Z"
          session_id: 01a1413f-64e8-7932-b32b-744dfcf3fea1
          outcome: returned
      "n": 1
      timestamp: "2026-10-15T13:28:30-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Define exclusive ownership for migration execution and recovery
          detail: 'ARCH-ORDER: Journals are shared by namespace and registry ID, but serialization is only per buffer and setup may recover another editor''s live migration. Specify ownership across execution/recovery, stale-owner takeover, and conflicting-tuple rejection before filesystem effects; verify these invariants with controllable two-editor ordering.'
          family: durable-operation-ownership
          round: 1
        - id: PQ-2
          severity: Important
          title: Compress test inventories into named function strategies
          detail: The verification section enumerates test cases, especially at plan lines 134–146, instead of providing the required function-specific strategies. Name each risky function, including classify_reply, the lifecycle transition, project, rewrite_parent and recover, with one line identifying its adversarial input class and mechanical guard; retain concise production-trigger acceptance checks.
          family: function-level-test-strategy
          round: 1
        - id: PQ-3
          severity: Minor
          title: Extend temporary-file lifecycle coverage to the new write locations
          detail: 'ARCH-FUNERAL: Existing startup cleanup scans only immediate state_dir children, whereas atomic temporary files are created beside each target. Name ownership-safe cleanup for nested journal/cache locations and backlink directories, including how cleanup avoids removing another live editor''s temporary files.'
          family: artifact-cleanup-coverage
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: adbfc0ee-46d3-4ad5-abfb-994a5aa7d5e4
            repository: github.com/xianxu/parley.nvim
            issue_id: "000332"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
            reviewed_head: 3e4d19dcc531b4078d4b769067546f4b3cafe002
            slot: parley.nvim:2
            requested_at: "2026-10-15T20:34:39.43555Z"
          phase: finished
          pid: 71518
          started_at: "2026-10-15T20:34:39.583063Z"
          finished_at: "2026-10-15T20:35:05.336908Z"
          session_id: 01a14146-2a57-7681-bcb7-c9aa20efd9d8
          outcome: returned
      "n": 2
      timestamp: "2026-10-15T13:35:05-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Execution and recovery share a kernel-owned lease, reject conflicting tuples before effects, and verify owner-death takeover and inode races through controlled two-editor ordering.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Verification now names risky functions, including classify_reply, dispatch, project, rewrite_parent and recover, with adversarial input classes and mechanical guards.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Nested journal/backlink temporaries use lease-owned manifests; cache temporaries use a separate lease and managed bucket, with cleanup forbidden from deleting another live writer's files.
          round: 2
      blocked: false
content_hash: c0f1a403fc8d8bc11edd2fd3dcfe399500bdc3b133cf006457acad29a56e3797
---

# Gate ledger — parley.nvim#332 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T13:28:30-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `durable-operation-ownership` Define exclusive ownership for migration execution and recovery
  ARCH-ORDER: Journals are shared by namespace and registry ID, but serialization is only per buffer and setup may recover another editor's live migration. Specify ownership across execution/recovery, stale-owner takeover, and conflicting-tuple rejection before filesystem effects; verify these invariants with controllable two-editor ordering.
- **PQ-2** [Important] `function-level-test-strategy` Compress test inventories into named function strategies
  The verification section enumerates test cases, especially at plan lines 134–146, instead of providing the required function-specific strategies. Name each risky function, including classify_reply, the lifecycle transition, project, rewrite_parent and recover, with one line identifying its adversarial input class and mechanical guard; retain concise production-trigger acceptance checks.
- **PQ-3** [Minor] `artifact-cleanup-coverage` Extend temporary-file lifecycle coverage to the new write locations
  ARCH-FUNERAL: Existing startup cleanup scans only immediate state_dir children, whereas atomic temporary files are created beside each target. Name ownership-safe cleanup for nested journal/cache locations and backlink directories, including how cleanup avoids removing another live editor's temporary files.

## Round 2 — 2026-10-15T13:35:05-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Execution and recovery share a kernel-owned lease, reject conflicting tuples before effects, and verify owner-death takeover and inode races through controlled two-editor ordering.
- PQ-2 — addressed — Verification now names risky functions, including classify_reply, dispatch, project, rewrite_parent and recover, with adversarial input classes and mechanical guards.
- PQ-3 — addressed — Nested journal/backlink temporaries use lease-owned manifests; cache temporaries use a separate lease and managed bucket, with cleanup forbidden from deleting another live writer's files.

## Open findings

(none — every finding has been disposed)
