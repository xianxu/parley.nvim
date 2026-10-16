---
gate: boundary-review
issue: 357
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e246a391-1e00-4f78-b99d-45a0198180c0
            repository: github.com/xianxu/parley.nvim
            issue_id: "000357"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/27c54d2b2c0b7e6c
            reviewed_head: 0654d0bf54f697534fb29782b55f47117ef708d0
            slot: parley.nvim:4
            requested_at: "2026-10-16T19:18:03.140912Z"
          phase: finished
          pid: 26671
          started_at: "2026-10-16T19:18:03.375885Z"
          finished_at: "2026-10-16T19:24:52.984734Z"
          session_id: 1b603c97-e2b9-44cd-8a73-76054c77f4ce
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0654d0bf54f697534fb29782b55f47117ef708d0
        tracker_head: 5adea0e62ad62ae0197697e716a4b138e4eac0f1
        branch_point: a936c96ce50bc9034e175915f691b0eebc690b33
        since: "2026-10-16T11:11:49-07:00"
        until: "2026-10-16T12:17:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:11:49-07:00"
              end: "2026-10-16T12:17:30-07:00"
              began: "2026-10-16T11:11:49-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: e98747deb828a7685ccf2d12bf98c58971db2005d643052cd881157e615d2dc2
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 18887730
              windows:
                - start: "2026-10-16T11:11:49-07:00"
                  end: "2026-10-16T12:17:30-07:00"
      "n": 1
      timestamp: "2026-10-16T12:24:56-07:00"
      dispatched: "2026-10-16T12:18:03-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: queued_submit set on any pending-phase press is never cleared when the pending op is rename/move or retry reconciles
          detail: 'agentic_document.lua:440 sets queued_submit and begin_submit for every pending phase, but only the lookup/register callback (:241) clears it. A pending rename (rename reply timeout -> pending), a pending move, or retry returning pending() on a context mismatch (document_session.lua:189) leave it set. The effects are a false "not confirmed ... did not answer within 15 s" after a successful rename, migration_busy (:498) refusing moves, and a later unrelated lookup completion (recheck/retry_loaded) firing M.submit with no press, which can send edited content to the agent. Fix: queue the replay only for lookup/register pending ops, and clear queued_submit on every outcome. Better, move the "confirm then submit" intent into document_session as a pure retry{submit=true} transition with unit tests (ARCH-PURE).'
          family: submit-intent-cleared-on-every-outcome
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Move rename registry request still uses the old 2500 ms default deadline
          detail: agentic_document.lua:263 calls registry.request("rename", ...) without timeout_ms, so under load the rename stage still times out at 2.5 s and goes pending, even though Spec point 4 asks for the same generous treatment and the surrounding move wait is now 5 s. This is the only registry call site in the window left at the default (lookup/register :248 and bounded_request :486 were updated).
          family: generous-deadline-every-couch-wait
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: BufFilePost lookup discards the "move not confirmed ... Run the move again" error; the atlas claim is false there
          detail: At :753-754 a timed-out destination lookup reports "destination membership is occupied or unknown", and recovery requires returning to OLD, because Neovim already renamed the buffer at BufFilePost. move_path (:562) propagates target.unconfirmed correctly; BufFilePost does not. atlas/modes/session_sync.md says "Every one runs before anything moved, so their recovery is ... Run the move again", which is untrue for BufFilePost. Fix the site, the atlas sentence, or both.
          family: move-unconfirmed-recovery-message
          round: 1
        - kind: defect
          id: BR-4
          severity: Important
          title: Send-stage deadline does not return the lock to the operator as the Revisions require
          detail: Revisions (operator amendment) and Plan item 2 say that on the deadline parley returns the lock to the operator, re-acquiring the session-sync turn if the send had released it. release_and_send releases the lock before sending, and the overdue timer (agentic_document.lua:213-216) only changes the band. No test asserts the lock after an overdue send. Implement and test the re-acquire, or record a Revision that deliberately drops it.
          family: revision-contract-delivered
          round: 1
        - kind: defect
          id: BR-5
          severity: Important
          title: Done-when "move wait under the same slow fake" is only tested for move_path's preflight lookup
          detail: The new move test exercises bounded_request's timeout in move_path. The former 3000 ms post-rename wait (agentic_document.lua:597, now agentic_move_timeout_ms) and the BufFilePre/BufFilePost preflights are never run under FAKE_COUCH_REGISTRY_DELAY, so the rename-stage and BufFilePost defects above go uncaught.
          family: done-when-clause-tested
          round: 1
        - kind: defect
          id: BR-6
          severity: Important
          title: README not updated for the new config keys and Alt+Return states
          detail: 'README.md:50-63 documents the neighbouring session_sync_* keys and Alt+Return winbar feedback. It lacks agentic_submit_timeout_ms, agentic_move_timeout_ms, the "submitting…" and "not confirmed: submit again" states, and the fact that a press on a pending registration now submits.'
          family: readme-user-surface
          round: 1
        - kind: defect
          id: BR-7
          severity: Minor
          title: Timeout defaults 15000/5000 restated in config.lua and at four config_ms call sites (ARCH-DRY)
          detail: agentic_document.lua:82 and :212 repeat 15000; :484 and :596 repeat 5000, alongside config.lua. Use one named constant or read the config default.
          family: single-source-defaults
          round: 1
        - kind: defect
          id: BR-8
          severity: Minor
          title: Plan's pure document_session_spec tests were not written; the behaviour lives in the shell
          detail: 'The Plan''s Tests section lists pure document_session_spec cases (deadline, join, late receipt, registry timeout then a single send). None were added. Either add a Revision or move the logic into the model and test it there. Also: begin_submit uses math.floor seconds (shows "0 s" for sub-second settings) while bounded_request uses math.ceil, and lookup/register now take 15 s for background probes too, which is undocumented.'
          family: plan-tests-delivered
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#357 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T12:24:56-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `submit-intent-cleared-on-every-outcome` (kind: defect) queued_submit set on any pending-phase press is never cleared when the pending op is rename/move or retry reconciles
  agentic_document.lua:440 sets queued_submit and begin_submit for every pending phase, but only the lookup/register callback (:241) clears it. A pending rename (rename reply timeout -> pending), a pending move, or retry returning pending() on a context mismatch (document_session.lua:189) leave it set. The effects are a false "not confirmed ... did not answer within 15 s" after a successful rename, migration_busy (:498) refusing moves, and a later unrelated lookup completion (recheck/retry_loaded) firing M.submit with no press, which can send edited content to the agent. Fix: queue the replay only for lookup/register pending ops, and clear queued_submit on every outcome. Better, move the "confirm then submit" intent into document_session as a pure retry{submit=true} transition with unit tests (ARCH-PURE).
- **BR-2** [Important] `generous-deadline-every-couch-wait` (kind: defect) Move rename registry request still uses the old 2500 ms default deadline
  agentic_document.lua:263 calls registry.request("rename", ...) without timeout_ms, so under load the rename stage still times out at 2.5 s and goes pending, even though Spec point 4 asks for the same generous treatment and the surrounding move wait is now 5 s. This is the only registry call site in the window left at the default (lookup/register :248 and bounded_request :486 were updated).
- **BR-3** [Important] `move-unconfirmed-recovery-message` (kind: defect) BufFilePost lookup discards the "move not confirmed ... Run the move again" error; the atlas claim is false there
  At :753-754 a timed-out destination lookup reports "destination membership is occupied or unknown", and recovery requires returning to OLD, because Neovim already renamed the buffer at BufFilePost. move_path (:562) propagates target.unconfirmed correctly; BufFilePost does not. atlas/modes/session_sync.md says "Every one runs before anything moved, so their recovery is ... Run the move again", which is untrue for BufFilePost. Fix the site, the atlas sentence, or both.
- **BR-4** [Important] `revision-contract-delivered` (kind: defect) Send-stage deadline does not return the lock to the operator as the Revisions require
  Revisions (operator amendment) and Plan item 2 say that on the deadline parley returns the lock to the operator, re-acquiring the session-sync turn if the send had released it. release_and_send releases the lock before sending, and the overdue timer (agentic_document.lua:213-216) only changes the band. No test asserts the lock after an overdue send. Implement and test the re-acquire, or record a Revision that deliberately drops it.
- **BR-5** [Important] `done-when-clause-tested` (kind: defect) Done-when "move wait under the same slow fake" is only tested for move_path's preflight lookup
  The new move test exercises bounded_request's timeout in move_path. The former 3000 ms post-rename wait (agentic_document.lua:597, now agentic_move_timeout_ms) and the BufFilePre/BufFilePost preflights are never run under FAKE_COUCH_REGISTRY_DELAY, so the rename-stage and BufFilePost defects above go uncaught.
- **BR-6** [Important] `readme-user-surface` (kind: defect) README not updated for the new config keys and Alt+Return states
  README.md:50-63 documents the neighbouring session_sync_* keys and Alt+Return winbar feedback. It lacks agentic_submit_timeout_ms, agentic_move_timeout_ms, the "submitting…" and "not confirmed: submit again" states, and the fact that a press on a pending registration now submits.
- **BR-7** [Minor] `single-source-defaults` (kind: defect) Timeout defaults 15000/5000 restated in config.lua and at four config_ms call sites (ARCH-DRY)
  agentic_document.lua:82 and :212 repeat 15000; :484 and :596 repeat 5000, alongside config.lua. Use one named constant or read the config default.
- **BR-8** [Minor] `plan-tests-delivered` (kind: defect) Plan's pure document_session_spec tests were not written; the behaviour lives in the shell
  The Plan's Tests section lists pure document_session_spec cases (deadline, join, late receipt, registry timeout then a single send). None were added. Either add a Revision or move the logic into the model and test it there. Also: begin_submit uses math.floor seconds (shows "0 s" for sub-second settings) while bounded_request uses math.ceil, and lookup/register now take 15 s for background probes too, which is undocumented.

## Open findings

- **BR-1** [Critical] `submit-intent-cleared-on-every-outcome` (kind: defect) queued_submit set on any pending-phase press is never cleared when the pending op is rename/move or retry reconciles
- **BR-2** [Important] `generous-deadline-every-couch-wait` (kind: defect) Move rename registry request still uses the old 2500 ms default deadline
- **BR-3** [Important] `move-unconfirmed-recovery-message` (kind: defect) BufFilePost lookup discards the "move not confirmed ... Run the move again" error; the atlas claim is false there
- **BR-4** [Important] `revision-contract-delivered` (kind: defect) Send-stage deadline does not return the lock to the operator as the Revisions require
- **BR-5** [Important] `done-when-clause-tested` (kind: defect) Done-when "move wait under the same slow fake" is only tested for move_path's preflight lookup
- **BR-6** [Important] `readme-user-surface` (kind: defect) README not updated for the new config keys and Alt+Return states
- **BR-7** [Minor] `single-source-defaults` (kind: defect) Timeout defaults 15000/5000 restated in config.lua and at four config_ms call sites (ARCH-DRY)
- **BR-8** [Minor] `plan-tests-delivered` (kind: defect) Plan's pure document_session_spec tests were not written; the behaviour lives in the shell
