---
gate: boundary-review
issue: 372
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: be9bacbf-42d3-4be6-816c-436af64209a8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000372"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/ecbf88d537ac35f5
            reviewed_head: 88acb8bd3ffde461022b14314f9dda8e0f9ccac2
            slot: parley.nvim:4
            requested_at: "2026-10-17T12:47:42.721518Z"
          phase: finished
          pid: 91446
          started_at: "2026-10-17T12:47:42.826213Z"
          finished_at: "2026-10-17T12:49:44.168042Z"
          session_id: 06b12fde-9d32-416c-85d3-00d4190c2e8c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 88acb8bd3ffde461022b14314f9dda8e0f9ccac2
        tracker_head: d233ae6e5b20e0bfa2513606f49a3d5548650088
        branch_point: 198a473f2bbbe90f0e804c2f847581aa2c783c91
        since: "2026-10-17T05:19:56-07:00"
        until: "2026-10-17T05:47:12-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T05:19:56-07:00"
              end: "2026-10-17T05:47:12-07:00"
              began: "2026-10-17T05:19:56-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: e9924873e2151c994c2d2de6a41ac6a709683936c101e5b249e219987e83fc99
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 31374681
              windows:
                - start: "2026-10-17T05:19:56-07:00"
                  end: "2026-10-17T05:47:12-07:00"
      "n": 1
      timestamp: "2026-10-17T05:49:50-07:00"
      dispatched: "2026-10-17T05:47:42-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Fake reply-delay comment says the _OPS list defaults to all ops, but several paths return before the delay
          detail: tests/fixtures/fake_couch_registry.py:165-174. The status op, --owe/--fold and the unsupported/malformed/missing modes all return before the delay code, so they never get it. The new 10 s cap is also silent, while the existing FAKE_COUCH_REGISTRY_DELAY knob has no cap. These are the two instances of this family in the window.
          family: doc-claim-unchecked
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: 'ARCH-DRY: two near-identical comma-list op filter + sleep blocks in the fake registry'
          detail: The mode=delay block (fake_couch_registry.py:79-84) and the new reply-delay block (:170-174) both parse an _OPS comma list, work out the op on their own, and sleep. A shared _maybe_sleep(prefix, op) helper could serve both. These two blocks are the only instances in the window.
          family: duplicated-helper-logic
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 88acb8bd3ffde461022b14314f9dda8e0f9ccac2
      blocked: false
---

# Gate ledger — parley.nvim#372 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T05:49:50-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `doc-claim-unchecked` (kind: defect) Fake reply-delay comment says the _OPS list defaults to all ops, but several paths return before the delay
  tests/fixtures/fake_couch_registry.py:165-174. The status op, --owe/--fold and the unsupported/malformed/missing modes all return before the delay code, so they never get it. The new 10 s cap is also silent, while the existing FAKE_COUCH_REGISTRY_DELAY knob has no cap. These are the two instances of this family in the window.
- **BR-2** [Minor] `duplicated-helper-logic` (kind: defect) ARCH-DRY: two near-identical comma-list op filter + sleep blocks in the fake registry
  The mode=delay block (fake_couch_registry.py:79-84) and the new reply-delay block (:170-174) both parse an _OPS comma list, work out the op on their own, and sleep. A shared _maybe_sleep(prefix, op) helper could serve both. These two blocks are the only instances in the window.

## Open findings

- **BR-1** [Minor] `doc-claim-unchecked` (kind: defect) Fake reply-delay comment says the _OPS list defaults to all ops, but several paths return before the delay
- **BR-2** [Minor] `duplicated-helper-logic` (kind: defect) ARCH-DRY: two near-identical comma-list op filter + sleep blocks in the fake registry
