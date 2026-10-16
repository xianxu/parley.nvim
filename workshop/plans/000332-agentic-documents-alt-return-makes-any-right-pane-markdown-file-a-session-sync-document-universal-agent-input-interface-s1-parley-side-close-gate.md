---
gate: boundary-review
issue: 332
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d005ac77-a86e-4347-b2ad-c31155e637f7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000332"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/62e82e6231b05a0c
            reviewed_head: c3b815092d3044a516fb0914f69a95614cdc069e
            slot: parley.nvim:2
            requested_at: "2026-10-16T01:14:21.24309Z"
          phase: finished
          pid: 37967
          started_at: "2026-10-16T01:14:21.619261Z"
          finished_at: "2026-10-16T01:17:38.290309Z"
          session_id: 01a14246-3e92-7491-ac90-0ed30b7f1e45
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: c3b815092d3044a516fb0914f69a95614cdc069e
        tracker_head: 16b5bc00e4d2b91b82830a72f16c7ca9c4736d0a
        branch_point: e23163d1bb9f42765fdd899f18951b6f32c6208e
        since: "2026-10-15T13:07:57-07:00"
        until: "2026-10-15T18:13:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T13:07:57-07:00"
              end: "2026-10-15T18:13:55-07:00"
              began: "2026-10-15T13:07:57-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d088e5fd2ac4bfb59de9994bec60961722ad2924cfba09f6afaedb0f6a148883
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 41536415
              windows:
                - start: "2026-10-15T13:07:57-07:00"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1412e-8523-7fa2-9e8c-d8873b1348df
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 55d32eabe6849de7420d62370c1ee8cbdffa559d7544e690fbb279d03bf6fcb1
              started: "2026-10-15T20:08:50.417Z"
              spawned: true
              bytes: 562266
              windows:
                - start: "2026-10-15T20:08:50.417Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1412e-a904-7710-88fe-3f3326bacbcc
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e19cce2151caca3c6a35df764819278eb98007792e2be7960f124d75267c2922
              started: "2026-10-15T20:08:59.629Z"
              spawned: true
              bytes: 1012259
              windows:
                - start: "2026-10-15T20:08:59.629Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1413f-64e8-7932-b32b-744dfcf3fea1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 0a52ac8e8d17b31dddcd9fa12c53d6c59414c4f769fdd84edbbe32e78c039069
              started: "2026-10-15T20:27:17Z"
              spawned: false
              bytes: 662693
              windows:
                - start: "2026-10-15T20:27:17Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a14146-2a57-7681-bcb7-c9aa20efd9d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 863c26a3a60d78138d7d4d9e026dc076d3dcd52ebf4d6fd91eb39cd79f6e26f5
              started: "2026-10-15T20:34:40.952Z"
              spawned: false
              bytes: 443654
              windows:
                - start: "2026-10-15T20:34:40.952Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a14148-4d6b-7bc1-a650-2ac9c3c9c103
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: e408e478d4696e1747739db1fb465c979f69c4b263451e6ada34ac2395ff57eb
              started: "2026-10-15T20:37:00.683Z"
              spawned: false
              bytes: 431233
              windows:
                - start: "2026-10-15T20:37:00.683Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a14148-d1e2-7301-9d8e-167ed3bc3b48
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d706bfd9766ca0500d3ad296a41a7ee61746e7dfe1db8060b2344292e176d0d9
              started: "2026-10-15T20:37:34.757Z"
              spawned: false
              bytes: 458095
              windows:
                - start: "2026-10-15T20:37:34.757Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1414a-f880-7dc2-b5fa-55ab37d93fa5
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: ae49424b7bd974ded7aec0df4f02ae4f7afd12b097cdf0a5cb6f7f4f0030350e
              started: "2026-10-15T20:39:54.868Z"
              spawned: true
              bytes: 3585300
              windows:
                - start: "2026-10-15T20:39:54.868Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1414b-1aae-7ea1-955b-65ac06abf8d8
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: f79fa3e5773c745bd6d37cb14c93d6c8f372f5ebf53fedb94e32ec3998d41764
              started: "2026-10-15T20:40:03.611Z"
              spawned: true
              bytes: 1814060
              windows:
                - start: "2026-10-15T20:40:03.611Z"
                  end: "2026-10-15T18:13:55-07:00"
            - harness: codex
              id: 01a1414b-3f7d-78f1-8ff5-cf30539ca92f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 0519dff3151393e2d0153286ae2fdf7c3cc9d04a55fe2727949a88e4a4634fc0
              started: "2026-10-15T20:40:13.046Z"
              spawned: true
              bytes: 3670814
              windows:
                - start: "2026-10-15T20:40:13.046Z"
                  end: "2026-10-15T18:13:55-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.029516666666666667
      "n": 1
      timestamp: "2026-10-15T18:17:38-07:00"
      dispatched: "2026-10-15T18:14:21-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Native rename treats unresolved membership as plain and strands registration
          detail: 'lua/parley/agentic_document.lua:554-557 returns from BufFilePre when neither coordinator nor legacy identity is attached, including while initial lookup is pending or unavailable. Reproduced with an existing registration and delayed initial lookup: native :saveas succeeded, NEW became plain with no identity or edit lock, and independent registry queries reported OLD registered / NEW absent. ARCH-PURPOSE and ARCH-ORDER: require confirmed absence before allowing the plain rename path; resolve membership or refuse only the migration when membership is unknown. Add controlled-order regressions for native rename during probing and unavailable admission.'
          family: membership-before-migration
          round: 1
        - kind: defect
          id: BR-2
          severity: Critical
          title: Lookup completion during buffer unload permanently strands the operation on reopen
          detail: 'lua/parley/agentic_document.lua:185 discards callbacks when the buffer is unloaded, but line 315 detaches only on BufWipeout. Reproduced by holding initial lookup, running :bdelete, completing lookup while unloaded, then reopening: the controller remained probing with its completed lookup still recorded, and subsequent submit could neither requery nor submit. ARCH-ORDER and ARCH-FUNERAL: invalidate the buffer incarnation and close owned requests/leases on unload, or explicitly model suspended completion and restart admission on reload; preserve uncertain mutation/journal recovery. Add delayed-completion unload/reopen tests across lookup, mutation and migration.'
          family: async-buffer-lifetime
          round: 1
        - kind: defect
          id: BR-3
          severity: Critical
          title: Core concepts declares not_chat PURE despite editor and filesystem dependencies
          detail: workshop/plans/000332-agentic-documents-plan.md:38 labels not_chat PURE, but lua/parley/init.lua:1845 resolves configured chat roots and line 1856 reads buffer contents when supplied_lines is omitted. Its existing tests/integration/not_chat_spec.lua creates directories, writes files and constructs buffers. This contradicts the required Core concepts classification and ARCH-PURE. Promote this wrapper to INTEGRATION, or extract a value-only classifier and classify/test that separately; record the correction under Revisions.
          family: core-concept-purity-contract
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#332 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T18:17:38-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `membership-before-migration` (kind: defect) Native rename treats unresolved membership as plain and strands registration
  lua/parley/agentic_document.lua:554-557 returns from BufFilePre when neither coordinator nor legacy identity is attached, including while initial lookup is pending or unavailable. Reproduced with an existing registration and delayed initial lookup: native :saveas succeeded, NEW became plain with no identity or edit lock, and independent registry queries reported OLD registered / NEW absent. ARCH-PURPOSE and ARCH-ORDER: require confirmed absence before allowing the plain rename path; resolve membership or refuse only the migration when membership is unknown. Add controlled-order regressions for native rename during probing and unavailable admission.
- **BR-2** [Critical] `async-buffer-lifetime` (kind: defect) Lookup completion during buffer unload permanently strands the operation on reopen
  lua/parley/agentic_document.lua:185 discards callbacks when the buffer is unloaded, but line 315 detaches only on BufWipeout. Reproduced by holding initial lookup, running :bdelete, completing lookup while unloaded, then reopening: the controller remained probing with its completed lookup still recorded, and subsequent submit could neither requery nor submit. ARCH-ORDER and ARCH-FUNERAL: invalidate the buffer incarnation and close owned requests/leases on unload, or explicitly model suspended completion and restart admission on reload; preserve uncertain mutation/journal recovery. Add delayed-completion unload/reopen tests across lookup, mutation and migration.
- **BR-3** [Critical] `core-concept-purity-contract` (kind: defect) Core concepts declares not_chat PURE despite editor and filesystem dependencies
  workshop/plans/000332-agentic-documents-plan.md:38 labels not_chat PURE, but lua/parley/init.lua:1845 resolves configured chat roots and line 1856 reads buffer contents when supplied_lines is omitted. Its existing tests/integration/not_chat_spec.lua creates directories, writes files and constructs buffers. This contradicts the required Core concepts classification and ARCH-PURE. Promote this wrapper to INTEGRATION, or extract a value-only classifier and classify/test that separately; record the correction under Revisions.

## Open findings

- **BR-1** [Critical] `membership-before-migration` (kind: defect) Native rename treats unresolved membership as plain and strands registration
- **BR-2** [Critical] `async-buffer-lifetime` (kind: defect) Lookup completion during buffer unload permanently strands the operation on reopen
- **BR-3** [Critical] `core-concept-purity-contract` (kind: defect) Core concepts declares not_chat PURE despite editor and filesystem dependencies
