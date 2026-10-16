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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 18d12083-adc4-4acd-84d7-ed1bd02d704c
            repository: github.com/xianxu/parley.nvim
            issue_id: "000226"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/4ee6fa566e4e74c6
            reviewed_head: 2f49f51bddfecf8a72586f4550fa40d0ceda761b
            slot: parley.nvim:3
            requested_at: "2026-10-16T07:34:31.141842Z"
          phase: finished
          pid: 77381
          started_at: "2026-10-16T07:34:31.376917Z"
          finished_at: "2026-10-16T07:37:12.473655Z"
          session_id: 5f4d0389-b029-491a-9e4a-0d33a66c743f
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2f49f51bddfecf8a72586f4550fa40d0ceda761b
        tracker_head: 654d4ef599059b3e8c8600ebd18e30fd284f0997
        branch_point: 90c6262c54b10fc220d9c0c170d633105dca7053
        since: "2026-10-16T00:18:48-07:00"
        until: "2026-10-16T00:33:47-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T00:18:48-07:00"
              end: "2026-10-16T00:33:47-07:00"
              began: "2026-10-16T00:18:48-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 68dc29852213d8e28bf2d12d5cb700a7e47049f182634d841fa276112bc08c2b
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 7420862
              windows:
                - start: "2026-10-16T00:18:48-07:00"
                  end: "2026-10-16T00:33:47-07:00"
        cuts:
            - dispatched: "2026-10-16T00:29:39-07:00"
              finalized: "2026-10-16T00:33:07-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T00:37:15-07:00"
      dispatched: "2026-10-16T00:34:31-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Key includes origin_buf/origin_win (artifact_ref.lua:234); the supersede-from-another-window test fails when the origin is removed from the key (verified 39/1), passes at head 40/40; Spec, atlas and doc comment updated.
          round: 2
        - id: BR-2
          disposition: addressed
          note: inflight and _reset_inflight now at artifact_ref.lua:182-186, above the goto_ref_at_cursor doc block, which runs contiguously into the function.
          round: 2
        - id: BR-3
          disposition: addressed
          note: atlas/context/artifact_refs.md:51-53 now ties the double-press guarantee to the same-key no-op sentence; supersede is its own sentence.
          round: 2
        - id: BR-4
          disposition: addressed
          note: New test "drops a family selection made after the user left the window" calls press() without is_current; it fails when the window check is removed from is_current (verified).
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Minor
          title: Issue Plan bullet and Core concepts row still restate the record as it was before BR-1
          detail: 'The issue''s Plan item at line 81 says the record is keyed on "the ref, kind and cwd" (origin buf/win is missing), and the Core concepts row at line 68 lists a "token" the record does not have (it is { key, handle, done }). The rule: when a contract changes, update every restatement of it. Enumerating this window''s restatements of the key and record: Spec Key bullet (updated), atlas artifact_refs.md:50 (updated), artifact_ref.lua:182 and :204 comments (updated), Plan line 81 (stale), Core concepts line 68 (stale). Fix the two stale ones.'
          family: contract-restatement-sweep
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 2f49f51bddfecf8a72586f4550fa40d0ceda761b
      blocked: false
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

## Round 2 — 2026-10-16T00:37:15-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Key includes origin_buf/origin_win (artifact_ref.lua:234); the supersede-from-another-window test fails when the origin is removed from the key (verified 39/1), passes at head 40/40; Spec, atlas and doc comment updated.
- BR-2 — addressed — inflight and _reset_inflight now at artifact_ref.lua:182-186, above the goto_ref_at_cursor doc block, which runs contiguously into the function.
- BR-3 — addressed — atlas/context/artifact_refs.md:51-53 now ties the double-press guarantee to the same-key no-op sentence; supersede is its own sentence.
- BR-4 — addressed — New test "drops a family selection made after the user left the window" calls press() without is_current; it fails when the window check is removed from is_current (verified).

### Raised

- **BR-5** [Minor] `contract-restatement-sweep` (kind: defect) Issue Plan bullet and Core concepts row still restate the record as it was before BR-1
  The issue's Plan item at line 81 says the record is keyed on "the ref, kind and cwd" (origin buf/win is missing), and the Core concepts row at line 68 lists a "token" the record does not have (it is { key, handle, done }). The rule: when a contract changes, update every restatement of it. Enumerating this window's restatements of the key and record: Spec Key bullet (updated), atlas artifact_refs.md:50 (updated), artifact_ref.lua:182 and :204 comments (updated), Plan line 81 (stale), Core concepts line 68 (stale). Fix the two stale ones.

## Open findings

- **BR-5** [Minor] `contract-restatement-sweep` (kind: defect) Issue Plan bullet and Core concepts row still restate the record as it was before BR-1
