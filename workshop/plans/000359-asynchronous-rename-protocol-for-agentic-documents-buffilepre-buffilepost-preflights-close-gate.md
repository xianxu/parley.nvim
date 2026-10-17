---
gate: boundary-review
issue: 359
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 62e0c8d7-2c3d-4d2d-8e66-f3856493f966
            repository: github.com/xianxu/parley.nvim
            issue_id: "000359"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/c3e2593110710224
            reviewed_head: 656611a6c5a13a9e734f1a47ab9e94fdd7257dbc
            slot: parley.nvim:4
            requested_at: "2026-10-17T02:15:02.623955Z"
          phase: finished
          pid: 1014
          started_at: "2026-10-17T02:15:03.40328Z"
          finished_at: "2026-10-17T02:22:58.638647Z"
          session_id: 9bfea3df-1218-46aa-853e-93b7039b594e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 656611a6c5a13a9e734f1a47ab9e94fdd7257dbc
        tracker_head: cd510dea6c4cbba24ac0713db0b22403fad138ad
        branch_point: 630f6aac732056d390a4a21d77f4c668abda8900
        since: "2026-10-16T12:52:47-07:00"
        until: "2026-10-16T19:14:09-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T12:52:47-07:00"
              end: "2026-10-16T19:14:09-07:00"
              began: "2026-10-16T12:52:47-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 59800edbc98f515c6ac8af9437508ddffef7342e0b1e944f3cc250726012499b
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 27097886
              windows:
                - start: "2026-10-16T12:52:47-07:00"
                  end: "2026-10-16T19:14:09-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 55.30478333333333
      "n": 1
      timestamp: "2026-10-16T19:22:59-07:00"
      dispatched: "2026-10-16T19:15:02-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Tree move pre-pass stops at the first unknown identity, so N unknown documents need N+1 reruns
          detail: 'init.lua:3887-3890 returns on the first nil from move_membership, so only that file''s background lookup starts. The issue promises one recovery action. Fix: call move_membership on every file first, then return the first refusal, and add a two-file tree test.'
          family: one-recovery-action
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: The background "absent" memo (answered) never expires and authorizes plain moves indefinitely
          detail: 'agentic_document.lua:127/139/160 is only cleared when that slot later registers. An agent registering the file later is never seen for unloaded files (no recheck), so a plain move orphans the registration. Fix: use the answer once, or expire it at a deadline.'
          family: stale-observation-authority
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: BufFilePost decides the :saveas! overwrite inline; move_preflight's wait_destination branch is dead in production
          detail: The plan says all three entry points decide through move_preflight. BufFilePost (agentic_document.lua:829-843) checks filereadable and calls bounded_request itself, and no caller passes new_exists or overwrite. Route the check through move_preflight, or remove the branch and add a plan Revision.
          family: single-decision-table
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: BufWritePost ignores record_write's failure, leaving a stale journal witness silently
          detail: agentic_document.lua:873. If persist fails, the later reopen recovery fails with no earlier warning. It should notify.
          family: silent-error-swallowing
          round: 1
        - kind: defect
          id: BR-5
          severity: Minor
          title: Background requests are not cancelled on detach as the plan's ARCH-FUNERAL claims; answered/asking grow per path
          detail: The callbacks are guarded, so this is safe, but the plan's statement is wrong and the memo has no bound.
          family: lifecycle-claim-drift
          round: 1
        - kind: defect
          id: BR-6
          severity: Minor
          title: The move's state is spread across flags on moving (answered, overdue, pending_error, error, journal_pending) with no transition function
          detail: move_outcome projects views from these flags, but their legal combinations are unwritten (ARCH-ORDER).
          family: implicit-state-flags
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 72e49f77-f526-4571-97fb-de633e074377
            repository: github.com/xianxu/parley.nvim
            issue_id: "000359"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/0c104a8eca5f175a
            reviewed_head: aae97db73b9403cb42264d9f7e39a5e40d877513
            slot: parley.nvim:4
            requested_at: "2026-10-17T02:28:14.719194Z"
          phase: finished
          pid: 49800
          started_at: "2026-10-17T02:28:14.835028Z"
          finished_at: "2026-10-17T02:32:17.837824Z"
          session_id: ed65899a-889b-4725-8501-94c09333129f
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: aae97db73b9403cb42264d9f7e39a5e40d877513
        tracker_head: cd510dea6c4cbba24ac0713db0b22403fad138ad
        branch_point: 630f6aac732056d390a4a21d77f4c668abda8900
        since: "2026-10-16T12:52:47-07:00"
        until: "2026-10-16T19:27:36-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T12:52:47-07:00"
              end: "2026-10-16T19:27:36-07:00"
              began: "2026-10-16T12:52:47-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 336349d03d502f6d8208bee18c0cc028d1c0cdd2f654e375ee55690e2e992f4a
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 27333574
              windows:
                - start: "2026-10-16T12:52:47-07:00"
                  end: "2026-10-16T19:27:36-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 55.30478333333333
        cuts:
            - dispatched: "2026-10-16T19:15:02-07:00"
              finalized: "2026-10-16T19:22:59-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T19:32:21-07:00"
      dispatched: "2026-10-16T19:28:14-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: init.lua:3887-3894 collects the first refusal after asking about every file; reverting to the early return fails the new two-child tree test (verified).
          round: 2
        - id: BR-2
          disposition: addressed
          note: answered now stores an expiry checked in known_identity (agentic_document.lua:599-600); dropping the expiry check fails "lets a background absent answer expire" (verified).
          round: 2
        - id: BR-3
          disposition: addressed
          note: BufFilePost decides through move_preflight.wait_destination (agentic_document.lua:872-874); replacing it with false fails row 9 in agentic_document_spec (verified).
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: A notify was added at agentic_document.lua:903-908, but no test reaches the record_write-failure branch; Minor, non-blocking.
          round: 2
        - id: BR-5
          disposition: addressed
          note: The plan's ARCH-FUNERAL paragraph now says requests are not cancelled and callbacks are guarded; answered expires and asking dedupes per path, matching the code.
          round: 2
        - id: BR-6
          disposition: not-addressed
          note: The fields are documented in order (agentic_document.lua:134-145), but there is still no transition function, so ARCH-ORDER is unmet; Minor, non-blocking.
          round: 2
      findings:
        - kind: defect
          id: BR-7
          severity: Minor
          title: The 60 s absent-answer expiry quietly bounds the one-rerun promise, and the docs do not say so
          detail: 'This is the 2nd finding in family one-recovery-action. Rule: every refusal that tells the operator to run the move again must state how long its answer stays valid, in the plan, atlas and README. A rerun more than ANSWER_TTL_MS after the refusal refuses again (agentic_document.lua:599-600), but atlas session_sync.md:152-161 and README.md:58-60 describe "an earlier background answer" with no bound. Separately, BufFilePost passes filereadable(NEW) as both new_exists and overwrite, so :file onto an existing path also waits inline, contrary to "only :saveas!".'
          family: one-recovery-action
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: aae97db73b9403cb42264d9f7e39a5e40d877513
      blocked: false
---

# Gate ledger — parley.nvim#359 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T19:22:59-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `one-recovery-action` (kind: defect) Tree move pre-pass stops at the first unknown identity, so N unknown documents need N+1 reruns
  init.lua:3887-3890 returns on the first nil from move_membership, so only that file's background lookup starts. The issue promises one recovery action. Fix: call move_membership on every file first, then return the first refusal, and add a two-file tree test.
- **BR-2** [Important] `stale-observation-authority` (kind: defect) The background "absent" memo (answered) never expires and authorizes plain moves indefinitely
  agentic_document.lua:127/139/160 is only cleared when that slot later registers. An agent registering the file later is never seen for unloaded files (no recheck), so a plain move orphans the registration. Fix: use the answer once, or expire it at a deadline.
- **BR-3** [Important] `single-decision-table` (kind: defect) BufFilePost decides the :saveas! overwrite inline; move_preflight's wait_destination branch is dead in production
  The plan says all three entry points decide through move_preflight. BufFilePost (agentic_document.lua:829-843) checks filereadable and calls bounded_request itself, and no caller passes new_exists or overwrite. Route the check through move_preflight, or remove the branch and add a plan Revision.
- **BR-4** [Minor] `silent-error-swallowing` (kind: defect) BufWritePost ignores record_write's failure, leaving a stale journal witness silently
  agentic_document.lua:873. If persist fails, the later reopen recovery fails with no earlier warning. It should notify.
- **BR-5** [Minor] `lifecycle-claim-drift` (kind: defect) Background requests are not cancelled on detach as the plan's ARCH-FUNERAL claims; answered/asking grow per path
  The callbacks are guarded, so this is safe, but the plan's statement is wrong and the memo has no bound.
- **BR-6** [Minor] `implicit-state-flags` (kind: defect) The move's state is spread across flags on moving (answered, overdue, pending_error, error, journal_pending) with no transition function
  move_outcome projects views from these flags, but their legal combinations are unwritten (ARCH-ORDER).

## Round 2 — 2026-10-16T19:32:21-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — init.lua:3887-3894 collects the first refusal after asking about every file; reverting to the early return fails the new two-child tree test (verified).
- BR-2 — addressed — answered now stores an expiry checked in known_identity (agentic_document.lua:599-600); dropping the expiry check fails "lets a background absent answer expire" (verified).
- BR-3 — addressed — BufFilePost decides through move_preflight.wait_destination (agentic_document.lua:872-874); replacing it with false fails row 9 in agentic_document_spec (verified).
- BR-4 — not-addressed — A notify was added at agentic_document.lua:903-908, but no test reaches the record_write-failure branch; Minor, non-blocking.
- BR-5 — addressed — The plan's ARCH-FUNERAL paragraph now says requests are not cancelled and callbacks are guarded; answered expires and asking dedupes per path, matching the code.
- BR-6 — not-addressed — The fields are documented in order (agentic_document.lua:134-145), but there is still no transition function, so ARCH-ORDER is unmet; Minor, non-blocking.

### Raised

- **BR-7** [Minor] `one-recovery-action` (kind: defect) The 60 s absent-answer expiry quietly bounds the one-rerun promise, and the docs do not say so
  This is the 2nd finding in family one-recovery-action. Rule: every refusal that tells the operator to run the move again must state how long its answer stays valid, in the plan, atlas and README. A rerun more than ANSWER_TTL_MS after the refusal refuses again (agentic_document.lua:599-600), but atlas session_sync.md:152-161 and README.md:58-60 describe "an earlier background answer" with no bound. Separately, BufFilePost passes filereadable(NEW) as both new_exists and overwrite, so :file onto an existing path also waits inline, contrary to "only :saveas!".

## Open findings

- **BR-4** [Minor] `silent-error-swallowing` (kind: defect) BufWritePost ignores record_write's failure, leaving a stale journal witness silently
- **BR-6** [Minor] `implicit-state-flags` (kind: defect) The move's state is spread across flags on moving (answered, overdue, pending_error, error, journal_pending) with no transition function
- **BR-7** [Minor] `one-recovery-action` (kind: defect) The 60 s absent-answer expiry quietly bounds the one-rerun promise, and the docs do not say so
