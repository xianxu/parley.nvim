---
gate: boundary-review
issue: 226
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2e5badc5-4976-4e4d-ad9e-66047a42dc6a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000226"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/9dd0efd76a2952c0
            reviewed_head: 5478f45fc9db5e3ae6e41fbbca41a81af60581c8
            slot: parley.nvim:3
            requested_at: "2026-10-16T07:29:39.209437Z"
          phase: finished
          pid: 13381
          started_at: "2026-10-16T07:29:39.389455Z"
          finished_at: "2026-10-16T07:32:53.631175Z"
          session_id: e983eb5b-bbb3-4bb9-9fe7-d11076bc5d48
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5478f45fc9db5e3ae6e41fbbca41a81af60581c8
        tracker_head: 654d4ef599059b3e8c8600ebd18e30fd284f0997
        branch_point: 90c6262c54b10fc220d9c0c170d633105dca7053
        since: "2026-10-16T00:18:48-07:00"
        until: "2026-10-16T00:29:06-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T00:18:48-07:00"
              end: "2026-10-16T00:29:06-07:00"
              began: "2026-10-16T00:18:48-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 6cac54858953d50ec86a3a64dae326d8861687eafd10931cfdfcc3b163c6966a
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 7336474
              windows:
                - start: "2026-10-16T00:18:48-07:00"
                  end: "2026-10-16T00:29:06-07:00"
      "n": 1
      timestamp: "2026-10-16T00:33:07-07:00"
      dispatched: "2026-10-16T00:29:39-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Same-ref press from another buffer/window is a no-op, and the in-flight result is then dropped as stale; nothing opens
          detail: 'artifact_ref.lua:230 keys in-flight on ref+kind+cwd only, but is_current (:244) delivers only to the origin buf/win. A probe spec (press #327 in buf A, press #327 in buf B, complete) gave 1 spawn, 0 opens. Fix: add origin_buf/origin_win to the key (a press from a new place supersedes), add a regression test asserting one open, and update the Spec Key bullet, atlas bullet and doc comment. The family-picker selection uses the same origin check but can only open while at the origin, so it is not affected.'
          family: inflight-key-vs-delivery-origin
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: local inflight and _reset_inflight inserted between goto_ref_at_cursor's doc block and the function
          detail: artifact_ref.lua:206-210 sits between the doc block ending at :205 and the function at :212; move the two declarations above the doc block.
          family: hoist-separates-doc-comment
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Atlas ties "a double-pressed M-o opens once" to the different-ref supersede sentence
          detail: atlas/context/artifact_refs.md:53; the double-press guarantee comes from the same-key no-op in the sentence before.
          family: doc-claim-misattributed
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Default origin check on a family-picker selection (no opts.is_current) has no test
          detail: 'The new describe only covers single-file dispatch; the #327 picker cases pass is_current.'
          family: test-both-modes
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#226 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T00:33:07-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `inflight-key-vs-delivery-origin` (kind: defect) Same-ref press from another buffer/window is a no-op, and the in-flight result is then dropped as stale; nothing opens
  artifact_ref.lua:230 keys in-flight on ref+kind+cwd only, but is_current (:244) delivers only to the origin buf/win. A probe spec (press #327 in buf A, press #327 in buf B, complete) gave 1 spawn, 0 opens. Fix: add origin_buf/origin_win to the key (a press from a new place supersedes), add a regression test asserting one open, and update the Spec Key bullet, atlas bullet and doc comment. The family-picker selection uses the same origin check but can only open while at the origin, so it is not affected.
- **BR-2** [Minor] `hoist-separates-doc-comment` (kind: defect) local inflight and _reset_inflight inserted between goto_ref_at_cursor's doc block and the function
  artifact_ref.lua:206-210 sits between the doc block ending at :205 and the function at :212; move the two declarations above the doc block.
- **BR-3** [Minor] `doc-claim-misattributed` (kind: defect) Atlas ties "a double-pressed M-o opens once" to the different-ref supersede sentence
  atlas/context/artifact_refs.md:53; the double-press guarantee comes from the same-key no-op in the sentence before.
- **BR-4** [Minor] `test-both-modes` (kind: defect) Default origin check on a family-picker selection (no opts.is_current) has no test
  The new describe only covers single-file dispatch; the #327 picker cases pass is_current.

## Open findings

- **BR-1** [Important] `inflight-key-vs-delivery-origin` (kind: defect) Same-ref press from another buffer/window is a no-op, and the in-flight result is then dropped as stale; nothing opens
- **BR-2** [Minor] `hoist-separates-doc-comment` (kind: defect) local inflight and _reset_inflight inserted between goto_ref_at_cursor's doc block and the function
- **BR-3** [Minor] `doc-claim-misattributed` (kind: defect) Atlas ties "a double-pressed M-o opens once" to the different-ref supersede sentence
- **BR-4** [Minor] `test-both-modes` (kind: defect) Default origin check on a family-picker selection (no opts.is_current) has no test
