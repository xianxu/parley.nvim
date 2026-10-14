---
gate: boundary-review
issue: 329
id_prefix: BR
rounds:
    - actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 10ba8720a5a71cd38cbb6a8276b762d69c6fe8cc
        tracker_head: 04f623b7c6ac83674b70fd85f7bb9fb12b26494c
        branch_point: bb2ce85c3a4afb83efbfc97ca6f2420045eeb1aa
        since: "2026-10-14T15:05:29-07:00"
        until: "2026-10-14T16:21:44-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-14T15:05:29-07:00"
              end: "2026-10-14T16:21:44-07:00"
              began: "2026-10-14T15:05:29-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: bd30bf4b288ad4b85ac448cff0e127c5f013fe2ec8dbc8870e4f51aeb7058b01
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 5137931
              windows:
                - start: "2026-10-14T15:05:29-07:00"
                  end: "2026-10-14T16:21:44-07:00"
      "n": 1
      timestamp: "2026-10-14T16:23:25-07:00"
      dispatched: "2026-10-14T16:22:22-07:00"
      agent: codex
      findings:
        - kind: unverifiable
          id: BR-1
          severity: Important
          title: Compile cleanliness cannot be verified without the declared substrate.
          detail: 'The Done-when contract requires weave compile to leave the committed tree clean. `weave compile --dry-run` exits 1 because /Users/xianxu/Library/Caches/sdlc/review-checkouts/ariadne is missing. This affects the entire four-entry family: .agents/skills/xx-tl-lead, .agents/skills/xx-tl-worker, .claude/skills/xx-tl-lead, and .claude/skills/xx-tl-worker. Provide measured host evidence from the pinned head with the intended substrate revision: successful compile, byte-identical .gitignore before/after, and clean git status.'
          family: generated-output-verification
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#329 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-14T16:23:25-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `generated-output-verification` (kind: unverifiable) Compile cleanliness cannot be verified without the declared substrate.
  The Done-when contract requires weave compile to leave the committed tree clean. `weave compile --dry-run` exits 1 because /Users/xianxu/Library/Caches/sdlc/review-checkouts/ariadne is missing. This affects the entire four-entry family: .agents/skills/xx-tl-lead, .agents/skills/xx-tl-worker, .claude/skills/xx-tl-lead, and .claude/skills/xx-tl-worker. Provide measured host evidence from the pinned head with the intended substrate revision: successful compile, byte-identical .gitignore before/after, and clean git status.

## Open findings

- **BR-1** [Important] `generated-output-verification` (kind: unverifiable) Compile cleanliness cannot be verified without the declared substrate.
