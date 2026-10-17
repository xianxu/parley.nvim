---
gate: boundary-review
issue: 360
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 315fc00c-3bd6-4d17-9cdf-0019733e54cc
            repository: github.com/xianxu/parley.nvim
            issue_id: "000360"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/bbce154f729b785d
            reviewed_head: 139ef2b9570dc37907fe167492022c627091c527
            slot: parley.nvim:4
            requested_at: "2026-10-17T07:58:08.194916Z"
          phase: finished
          pid: 97771
          started_at: "2026-10-17T07:58:08.30167Z"
          finished_at: "2026-10-17T08:01:44.194036Z"
          session_id: 98c87d59-c137-4c32-afa6-b3e450fe4734
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 139ef2b9570dc37907fe167492022c627091c527
        tracker_head: 6933408bb7d8a31114c711c3d1795e63ba09d6a9
        branch_point: f7808490a40dfed64017cb6b183e042c80fa8bf0
        since: "2026-10-16T22:33:58-07:00"
        until: "2026-10-17T00:57:48-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T22:33:58-07:00"
              end: "2026-10-17T00:57:48-07:00"
              began: "2026-10-16T22:33:58-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: af55d55c70adfae2e716464a5cc6352a85236db450f22699eb379490c5698fa2
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 29799027
              windows:
                - start: "2026-10-16T22:33:58-07:00"
                  end: "2026-10-17T00:57:48-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 84.59756666666667
      "n": 1
      timestamp: "2026-10-17T01:01:44-07:00"
      dispatched: "2026-10-17T00:58:08-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: The 2 s lsof cutoff inside the 5 s wait_listening budget can fail readiness on a fake that is up
          detail: 'tests/helpers/ready_port.lua:100 cuts lsof off at 2 s and counts a timeout as not listening, but #345 measured real lsof past 2 s under the 8-way suite (cliproxy.lua:35 uses a 10 s guard; see cliproxy_lifecycle_spec.lua:442 and :595). Two or three slow answers use up wait_listening''s 5 s default, which is a new false-negative flake. Every site in the family: wait_listening''s default at ready_port.lua:150, the 4 rewritten start_fake helpers, and cliproxy_catalog_spec.lua:96 (a 300 ms wait where every poll now runs an lsof while the port is still up). Fix: size the wait budget to the lsof cutoff, or retry an lsof timeout after a successful connect before counting it against the budget.'
          family: probe-cost-exceeds-wait-budget
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: The lsof-absent fallback and _has_listener's exit-code handling are untested
          detail: The is_listening doc says the connect alone decides when lsof is absent, but no test covers that path, and the rejects case would fail on a host without lsof. Codes 124, 1 and other failures in _has_listener are also unpinned. Stub _has_listener to return nil, with lsof present and absent.
          family: documented-mode-untested
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: The never-runs-lsof case restores _has_listener only when it passes
          detail: tests/unit/ready_port_spec.lua:99-105 restores _has_listener inline, and after_each restores only _connect, so a failure leaves the wrapper installed. Restore both seams in after_each.
          family: test-seam-restore
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: bfb6ca48-48cf-498c-83fe-c44a2edaa3ee
            repository: github.com/xianxu/parley.nvim
            issue_id: "000360"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/934231eb1ee0e91e
            reviewed_head: 5d00733614cc0c18ca1135f4549b3e5440cb1b09
            slot: parley.nvim:4
            requested_at: "2026-10-17T08:42:00.957491Z"
          phase: finished
          pid: 38800
          started_at: "2026-10-17T08:42:01.172451Z"
          finished_at: "2026-10-17T08:46:27.418282Z"
          session_id: 0a118491-dd53-4ccb-8266-a4b673081247
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5d00733614cc0c18ca1135f4549b3e5440cb1b09
        tracker_head: f9bd1cb3bdd0c9eb989bef786bfc99bc70e4dc31
        branch_point: f7808490a40dfed64017cb6b183e042c80fa8bf0
        since: "2026-10-16T22:33:58-07:00"
        until: "2026-10-17T01:04:22-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T22:33:58-07:00"
              end: "2026-10-17T01:04:22-07:00"
              began: "2026-10-16T22:33:58-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 96cb74fd2073d774fca7a47606dc99ebd7b96d64d01334b0ad710d820581ed2c
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 30016389
              windows:
                - start: "2026-10-16T22:33:58-07:00"
                  end: "2026-10-17T01:04:22-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 90.75753333333333
        cuts:
            - dispatched: "2026-10-17T00:58:08-07:00"
              finalized: "2026-10-17T01:01:44-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T01:46:27-07:00"
      dispatched: "2026-10-17T01:42:00-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Guard raised to 10 s, matching cliproxy LSOF_GUARD_MS. Headless test: vim.wait(100) with a callback that blocks 400 ms then returns true gives true, so a slow but answering lsof does not use up the budget.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: New cases cover lsof absent, lsof present but silent, and exit codes 0, 1, 124, 2 and nil. Putting back the old exit-1 line fails case 3 (spec line 136).
          round: 2
        - id: BR-3
          disposition: addressed
          note: after_each restores all four seams from the SEAMS list (ready_port_spec.lua:76-82). The inline restore is gone.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: Issue Plan item 2 still says the lsof confirm is bounded at 2 s, but the code uses 10 s
          detail: 'The Plan checklist in workshop/issues/000360 says "bounded at 2 s"; ready_port.lua:104 sets LSOF_TIMEOUT_MS = 10000. Other places in the window: the atlas says only "bounded" (correct), the code comments say 10 s (correct), and the 2026-10-16 Log entry is historical (leave it). Fix: update the Plan line.'
          family: doc-claim-drifts-from-code
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 5d00733614cc0c18ca1135f4549b3e5440cb1b09
      blocked: false
---

# Gate ledger — parley.nvim#360 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T01:01:44-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `probe-cost-exceeds-wait-budget` (kind: defect) The 2 s lsof cutoff inside the 5 s wait_listening budget can fail readiness on a fake that is up
  tests/helpers/ready_port.lua:100 cuts lsof off at 2 s and counts a timeout as not listening, but #345 measured real lsof past 2 s under the 8-way suite (cliproxy.lua:35 uses a 10 s guard; see cliproxy_lifecycle_spec.lua:442 and :595). Two or three slow answers use up wait_listening's 5 s default, which is a new false-negative flake. Every site in the family: wait_listening's default at ready_port.lua:150, the 4 rewritten start_fake helpers, and cliproxy_catalog_spec.lua:96 (a 300 ms wait where every poll now runs an lsof while the port is still up). Fix: size the wait budget to the lsof cutoff, or retry an lsof timeout after a successful connect before counting it against the budget.
- **BR-2** [Minor] `documented-mode-untested` (kind: defect) The lsof-absent fallback and _has_listener's exit-code handling are untested
  The is_listening doc says the connect alone decides when lsof is absent, but no test covers that path, and the rejects case would fail on a host without lsof. Codes 124, 1 and other failures in _has_listener are also unpinned. Stub _has_listener to return nil, with lsof present and absent.
- **BR-3** [Minor] `test-seam-restore` (kind: defect) The never-runs-lsof case restores _has_listener only when it passes
  tests/unit/ready_port_spec.lua:99-105 restores _has_listener inline, and after_each restores only _connect, so a failure leaves the wrapper installed. Restore both seams in after_each.

## Round 2 — 2026-10-17T01:46:27-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Guard raised to 10 s, matching cliproxy LSOF_GUARD_MS. Headless test: vim.wait(100) with a callback that blocks 400 ms then returns true gives true, so a slow but answering lsof does not use up the budget.
- BR-2 — addressed — New cases cover lsof absent, lsof present but silent, and exit codes 0, 1, 124, 2 and nil. Putting back the old exit-1 line fails case 3 (spec line 136).
- BR-3 — addressed — after_each restores all four seams from the SEAMS list (ready_port_spec.lua:76-82). The inline restore is gone.

### Raised

- **BR-4** [Minor] `doc-claim-drifts-from-code` (kind: defect) Issue Plan item 2 still says the lsof confirm is bounded at 2 s, but the code uses 10 s
  The Plan checklist in workshop/issues/000360 says "bounded at 2 s"; ready_port.lua:104 sets LSOF_TIMEOUT_MS = 10000. Other places in the window: the atlas says only "bounded" (correct), the code comments say 10 s (correct), and the 2026-10-16 Log entry is historical (leave it). Fix: update the Plan line.

## Open findings

- **BR-4** [Minor] `doc-claim-drifts-from-code` (kind: defect) Issue Plan item 2 still says the lsof confirm is bounded at 2 s, but the code uses 10 s
