---
gate: boundary-review
issue: 338
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 070cc84f-f11d-4c7c-9d00-87c73d9a45c1
            repository: github.com/xianxu/parley.nvim
            issue_id: "000338"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f847ba6be2d997df
            reviewed_head: 9092ea24ef63454cc83d16ce61524c7fcbde11e4
            slot: parley.nvim:3
            requested_at: "2026-10-16T00:18:45.481Z"
          phase: finished
          pid: 92257
          started_at: "2026-10-16T00:18:45.700001Z"
          finished_at: "2026-10-16T00:20:26.386328Z"
          session_id: 6561c8df-53b1-4a60-ae7d-11198e60261b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9092ea24ef63454cc83d16ce61524c7fcbde11e4
        tracker_head: 4c8e1aa4a0fd33ec3e174c0493398c756249be97
        branch_point: e23163d1bb9f42765fdd899f18951b6f32c6208e
        since: "2026-10-15T17:04:18-07:00"
        until: "2026-10-15T17:17:59-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T17:04:18-07:00"
              end: "2026-10-15T17:17:59-07:00"
              began: "2026-10-15T17:04:18-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: e8af55449e647294275fdc892dba5cf34a100f809e95d4a2849a2eb1381f08db
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 1705599
              windows:
                - start: "2026-10-15T17:04:18-07:00"
                  end: "2026-10-15T17:17:59-07:00"
      "n": 1
      timestamp: "2026-10-15T17:20:26-07:00"
      dispatched: "2026-10-15T17:18:45-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: starter_project_spec no-marker case fails when TMPDIR is inside a .parley-marked checkout
          detail: 'tests/integration/starter_project_spec.lua:93 "keeps the global app profile without a marker" builds scratch via tempname(); with TMPDIR inside this checkout (the exact sandbox condition from issue 338) detect_root climbs to the checkout''s .parley and the case fails 5/1 with "wrong primary chat dir: <checkout>/workshop/parley" (reproduced with TMPDIR=$PWD/.rvtmp and TMPDIR=""). Family instances in this window: packaging_vm_spec guest (fixed via PARLEY_REPO_MODE=0) and starter_project_spec no-marker case (open). Fix: place that case''s scratch under a dir with no marked ancestor, or assert/pending on repo_mode.detect_root(scratch) == nil; do not set PARLEY_REPO_MODE=0 there since the case tests discovery. Add starter_project_spec to the Verify step''s TMPDIR-inside run.'
          family: spec-hermetic-to-marked-ancestor
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a0ce1e5e-338c-4e01-8d94-1d3a29e162ab
            repository: github.com/xianxu/parley.nvim
            issue_id: "000338"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/4d99f9c643e9ef42
            reviewed_head: 57a01cb7a5314ab43df667f38e7d2adab55f994a
            slot: parley.nvim:3
            requested_at: "2026-10-16T00:57:52.282735Z"
          phase: finished
          pid: 37408
          started_at: "2026-10-16T00:57:52.564789Z"
          finished_at: "2026-10-16T01:08:36.137352Z"
          session_id: 887339a4-b56e-470e-80e5-783b2738c49e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 57a01cb7a5314ab43df667f38e7d2adab55f994a
        tracker_head: 982337278226f56f31dc8c4d3dc804ae9a762d90
        branch_point: e23163d1bb9f42765fdd899f18951b6f32c6208e
        since: "2026-10-15T17:04:18-07:00"
        until: "2026-10-15T17:57:02-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T17:04:18-07:00"
              end: "2026-10-15T17:57:02-07:00"
              began: "2026-10-15T17:04:18-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 9b2f2245c2b1bf0b39826969e4ffbd6aa829f0185f6f70e78f982e31b6144f1b
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 1900559
              windows:
                - start: "2026-10-15T17:04:18-07:00"
                  end: "2026-10-15T17:57:02-07:00"
        cuts:
            - dispatched: "2026-10-15T17:18:45-07:00"
              finalized: "2026-10-15T17:20:26-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T18:08:46-07:00"
      dispatched: "2026-10-15T17:57:52-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Class fix at the harness: the new guard (scratch_placement_spec.lua:52) fails for a marked ancestor outside the repo (verified 6/1, the reason names $HOME under the marked dir) and passes under the normal harness (7/0). With TMPDIR inside the checkout, the pre-existing #202 guards already fail, so that setup is declared unsupported. starter_project passes 6/0 with TMPDIR outside and 5/1 inside (expected, explained by the guard). The no-marker case correctly keeps discovery on, without PARLEY_REPO_MODE=0.'
          round: 2
      findings:
        - kind: defect
          id: BR-2
          severity: Minor
          title: Ancestor guard checks the parent of $HOME, so a marker in $HOME itself is missed
          detail: scratch_placement_spec.lua:59 applies :h to both paths. That is right for tempname() (a file) but skips $HOME itself (a directory). Check detect_root on $HOME directly. Only this one site in the window.
          family: spec-hermetic-to-marked-ancestor
          round: 2
      recipe: small-diff-review
      isolation: checkout
      reviewed: 57a01cb7a5314ab43df667f38e7d2adab55f994a
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 129ff7b3-230f-41dd-a8ce-c988021afdba
            repository: github.com/xianxu/parley.nvim
            issue_id: "000338"
            recipe: small-diff-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/97873e164baa1a7c
            reviewed_head: 9b518f2d19e311e84bc8dbeeaee1a8c4c95d26de
            slot: parley.nvim:3
            requested_at: "2026-10-16T01:11:30.67895Z"
          phase: finished
          pid: 80254
          started_at: "2026-10-16T01:11:30.822849Z"
          finished_at: "2026-10-16T01:13:07.784153Z"
          session_id: 997ba0fe-bddb-462d-a3e7-4f5a6efee9bb
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9b518f2d19e311e84bc8dbeeaee1a8c4c95d26de
        tracker_head: 0a27a3119e5340de30aaca5a5099bcb77d5812ad
        branch_point: 36e79af6c737cc323a957f64f128345c5a35940b
        since: "2026-10-15T17:04:18-07:00"
        until: "2026-10-15T18:10:52-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T17:04:18-07:00"
              end: "2026-10-15T18:10:52-07:00"
              began: "2026-10-15T17:04:18-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 6844d2e56dd0c920683a0f3b1a7c03ba25298193ba8d10ab525afabe269c07aa
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 2002131
              windows:
                - start: "2026-10-15T17:04:18-07:00"
                  end: "2026-10-15T18:10:52-07:00"
        cuts:
            - dispatched: "2026-10-15T17:18:45-07:00"
              finalized: "2026-10-15T17:20:26-07:00"
              finalizing: false
            - dispatched: "2026-10-15T17:57:52-07:00"
              finalized: "2026-10-15T18:08:46-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-15T18:13:08-07:00"
      dispatched: "2026-10-15T18:11:30-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: addressed
          note: marked_scratch passes $HOME to detect_root without :h (scratch_placement_spec.lua:60); the new case at :73 goes red (7/1) when :h on $HOME is reinstated and green (8/0) at head, with TMPDIR outside the checkout.
          round: 3
      recipe: small-diff-review
      isolation: checkout
      reviewed: 9b518f2d19e311e84bc8dbeeaee1a8c4c95d26de
      blocked: false
---

# Gate ledger — parley.nvim#338 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T17:20:26-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `spec-hermetic-to-marked-ancestor` (kind: defect) starter_project_spec no-marker case fails when TMPDIR is inside a .parley-marked checkout
  tests/integration/starter_project_spec.lua:93 "keeps the global app profile without a marker" builds scratch via tempname(); with TMPDIR inside this checkout (the exact sandbox condition from issue 338) detect_root climbs to the checkout's .parley and the case fails 5/1 with "wrong primary chat dir: <checkout>/workshop/parley" (reproduced with TMPDIR=$PWD/.rvtmp and TMPDIR=""). Family instances in this window: packaging_vm_spec guest (fixed via PARLEY_REPO_MODE=0) and starter_project_spec no-marker case (open). Fix: place that case's scratch under a dir with no marked ancestor, or assert/pending on repo_mode.detect_root(scratch) == nil; do not set PARLEY_REPO_MODE=0 there since the case tests discovery. Add starter_project_spec to the Verify step's TMPDIR-inside run.

## Round 2 — 2026-10-15T18:08:46-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Class fix at the harness: the new guard (scratch_placement_spec.lua:52) fails for a marked ancestor outside the repo (verified 6/1, the reason names $HOME under the marked dir) and passes under the normal harness (7/0). With TMPDIR inside the checkout, the pre-existing #202 guards already fail, so that setup is declared unsupported. starter_project passes 6/0 with TMPDIR outside and 5/1 inside (expected, explained by the guard). The no-marker case correctly keeps discovery on, without PARLEY_REPO_MODE=0.

### Raised

- **BR-2** [Minor] `spec-hermetic-to-marked-ancestor` (kind: defect) Ancestor guard checks the parent of $HOME, so a marker in $HOME itself is missed
  scratch_placement_spec.lua:59 applies :h to both paths. That is right for tempname() (a file) but skips $HOME itself (a directory). Check detect_root on $HOME directly. Only this one site in the window.

## Round 3 — 2026-10-15T18:13:08-07:00 (claude) — passed

### Disposed

- BR-2 — addressed — marked_scratch passes $HOME to detect_root without :h (scratch_placement_spec.lua:60); the new case at :73 goes red (7/1) when :h on $HOME is reinstated and green (8/0) at head, with TMPDIR outside the checkout.

## Open findings

(none — every finding has been disposed)
