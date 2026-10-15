---
gate: boundary-review
issue: 330
id_prefix: BR
rounds:
    - actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4d1788796dd9147a790eba2c1f7c1bf5d0fb2199
        tracker_head: 827f490ea047e2b673c9e3be050d6450a9d5a590
        branch_point: 874ccbaa9c1693ee56477ec39052765b043ba18b
        since: "2026-10-14T21:25:39-07:00"
        until: "2026-10-14T22:20:32-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-14T21:25:39-07:00"
              end: "2026-10-14T22:20:32-07:00"
              began: "2026-10-14T21:25:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 6cb44f5af97ea02f40fa242309b11be13a21d80b82abdd7490f2654a67130540
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 12397756
              windows:
                - start: "2026-10-14T21:25:39-07:00"
                  end: "2026-10-14T22:20:32-07:00"
      "n": 1
      timestamp: "2026-10-14T22:22:29-07:00"
      dispatched: "2026-10-14T22:20:45-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: README still documents the replaced saved-text release rule
          detail: README.md:54-55 says undo releases when unmodified and redo retakes ownership away from saved text. Under auto-save, saved changed text remains locked, while undo to the acquisition baseline releases even when it initially makes the buffer modified. Both stale clauses are the complete instance family in this window. Update them to match lua/parley/session_sync.lua:531-549 and atlas/modes/session_sync.md; README has no change in the pinned range.
          family: user-docs-match-behavior
          round: 1
        - id: BR-2
          severity: Minor
          title: Both Core concepts rows omit kind and change status
          detail: The issue file's Core concepts table at lines 59-62 lists Lock baseline and Release reconciliation without PURE/INTEGRATION classifications or new/modified/deleted status. These are both instances. Identify their implementing entities, classify the buffer/lock coordination as INTEGRATION, and record status so the required cross-check is explicit.
          family: core-concept-classification
          round: 1
        - id: BR-3
          severity: Minor
          title: The plan understates the maximum hashes per edit
          detail: The issue's Design notes at line 66 promise at most two SHA-256 hashes per edit. A successful baseline restoration requiring a write hashes at session_sync.lua:508, :531 and :547. This is the sole inaccurate work-bound claim found in the window. Document the three-hash path or reduce it while retaining the post-write content check.
          family: documented-work-bounds
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#330 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-14T22:22:29-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `user-docs-match-behavior` README still documents the replaced saved-text release rule
  README.md:54-55 says undo releases when unmodified and redo retakes ownership away from saved text. Under auto-save, saved changed text remains locked, while undo to the acquisition baseline releases even when it initially makes the buffer modified. Both stale clauses are the complete instance family in this window. Update them to match lua/parley/session_sync.lua:531-549 and atlas/modes/session_sync.md; README has no change in the pinned range.
- **BR-2** [Minor] `core-concept-classification` Both Core concepts rows omit kind and change status
  The issue file's Core concepts table at lines 59-62 lists Lock baseline and Release reconciliation without PURE/INTEGRATION classifications or new/modified/deleted status. These are both instances. Identify their implementing entities, classify the buffer/lock coordination as INTEGRATION, and record status so the required cross-check is explicit.
- **BR-3** [Minor] `documented-work-bounds` The plan understates the maximum hashes per edit
  The issue's Design notes at line 66 promise at most two SHA-256 hashes per edit. A successful baseline restoration requiring a write hashes at session_sync.lua:508, :531 and :547. This is the sole inaccurate work-bound claim found in the window. Document the three-hash path or reduce it while retaining the post-write content check.

## Open findings

- **BR-1** [Important] `user-docs-match-behavior` README still documents the replaced saved-text release rule
- **BR-2** [Minor] `core-concept-classification` Both Core concepts rows omit kind and change status
- **BR-3** [Minor] `documented-work-bounds` The plan understates the maximum hashes per edit
