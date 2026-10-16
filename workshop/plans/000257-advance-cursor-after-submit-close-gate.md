---
gate: boundary-review
issue: 257
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2fd79742-b523-4252-8b0b-90d491214d60
            repository: github.com/xianxu/parley.nvim
            issue_id: "000257"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/e9d81bb657f94a7f
            reviewed_head: 00acc2daa8a288fede4d2670b6a4c7908085b393
            slot: parley.nvim:3
            requested_at: "2026-10-16T16:57:01.347265Z"
          phase: finished
          pid: 30975
          started_at: "2026-10-16T16:57:01.716646Z"
          finished_at: "2026-10-16T16:58:59.667685Z"
          session_id: cdee0a18-2be4-441e-976a-ef36fc27d3af
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 00acc2daa8a288fede4d2670b6a4c7908085b393
        tracker_head: 42373d34413f9e3f3c5cb5bf922c919303c7c969
        branch_point: 0b5a2a2af2bfde1cbe9b6b52bdfd22bcbcb8b227
        since: "2026-10-16T09:10:43-07:00"
        until: "2026-10-16T09:41:13-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T09:10:43-07:00"
              end: "2026-10-16T09:41:13-07:00"
              began: "2026-10-16T09:10:43-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a884bc1cebaaf0c71aae15091b41aa1cf7b26c1f4de1547200815ed591260ef2
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 13806954
              windows:
                - start: "2026-10-16T09:10:43-07:00"
                  end: "2026-10-16T09:41:13-07:00"
      "n": 1
      timestamp: "2026-10-16T09:59:13-07:00"
      dispatched: "2026-10-16T09:57:01-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: 'Cursor outside any exchange: submit answers the last exchange but the cursor jumps to question 1'
          detail: "chat_respond.lua:2196 passes `exchange_idx or 0` to advance_after_submit, but start_scoped_response (line 1552) submits `frame.exchange_idx or #parsed.exchanges`. Reproduced: body {'\U0001F4AC: first','','\U0001F916: a1','answer one','','\U0001F4AC: second',''}, cursor {1,0}, submit leaves the cursor on row 5 ('\U0001F4AC: first') instead of row 1. Fix: pass the index start_scoped_response resolved and add this case as a regression test. This is the only instance in the window."
          family: advance-target-diverges-from-submitted
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Done-when does not cover the Stop rule change from Revisions
          detail: 'Revisions 2026-10-16 changes stop_at_cursor (chat_respond.lua:1498-1501): with the cursor on no running response, one running response is stopped without a picker, and two or more still open it. No Done-when clause covers this user-visible behavior. Add one.'
          family: done-when-covers-revisions
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: advance_after_submit repeats the lines, header, parse sequence owned by chat_context.resolve
          detail: 'chat_respond.lua:1990-1994 repeats chat_respond.lua:1611-1615 and parley.chat_context.resolve. The Plan''s claim of one parse per submit (ARCH-CONSTRAINTS) is also wrong: the advance always adds a full parse.'
          family: arch-dry-chat-parse-sequence
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Insert-mode submission path has no test
          detail: Done-when names normal, insert and visual paths, but only normal and visual are tested. Because stopinsert takes effect after the command, leaving insert mode may shift the cursor one column left onto the space after the prefix.
          family: done-when-clause-both-modes
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 26998e50-f281-449b-beaf-6df38f45e6f7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000257"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/73dd6a9a8d0e683f
            reviewed_head: d4f4a10f3ed14a1719e822cb26ef28d40ad8e3c1
            slot: parley.nvim:3
            requested_at: "2026-10-16T17:23:15.520438Z"
          phase: finished
          pid: 18145
          started_at: "2026-10-16T17:23:15.882689Z"
          finished_at: "2026-10-16T17:26:35.292932Z"
          session_id: 75e428af-cdd3-4c65-8c60-5a2a5d77986b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d4f4a10f3ed14a1719e822cb26ef28d40ad8e3c1
        tracker_head: 881a5bdb1750916d2051cfb1d7dd05fe54f681a9
        branch_point: 0b5a2a2af2bfde1cbe9b6b52bdfd22bcbcb8b227
        since: "2026-10-16T09:10:43-07:00"
        until: "2026-10-16T10:01:33-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T09:10:43-07:00"
              end: "2026-10-16T10:01:33-07:00"
              began: "2026-10-16T09:10:43-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 64f3ff4a3114264e227b55be3dcb7e4bc5bcfbf1722d94eaafad859b3994fbd3
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 13955816
              windows:
                - start: "2026-10-16T09:10:43-07:00"
                  end: "2026-10-16T10:01:33-07:00"
        cuts:
            - dispatched: "2026-10-16T09:57:01-07:00"
              finalized: "2026-10-16T09:59:13-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T10:26:39-07:00"
      dispatched: "2026-10-16T10:23:15-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: chat_respond.lua:2197 one `submitted` index feeds both; reverting to `exchange_idx or 0` turns the new regression test red.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Done-when gained the Stop clause; tested both ways (direct stop with one running, picker with 2 items in the stale-picker case).
          round: 2
        - id: BR-3
          disposition: addressed
          note: advance_after_submit now parses via chat_context.parse; Revisions corrects the one-parse claim.
          round: 2
        - id: BR-4
          disposition: addressed
          note: Insert-mode test added and fails when the adjustment is removed; a temporary copy of the real keymap handler also landed after the prefix.
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Minor
          title: Drill-in submissions move the cursor off the new turn, against that path's stated intent; untested
          detail: 'chat_respond.lua:2111 puts the cursor on the inserted turn so post-stream moves land there; the advance then moves it to an older exchange below and follow stops. Decide: skip the advance when branch_handled is set, or pin it with a test. Only instance in this window.'
          family: advance-target-diverges-from-submitted
          round: 2
        - kind: defect
          id: BR-6
          severity: Minor
          title: Plan gives next_question_cursor(parsed, index, config); code is (parsed, index, lines, prefix)
          detail: chat_respond.lua:1971. Add a Revisions entry. Only instance in this window.
          family: plan-signature-drift
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: d4f4a10f3ed14a1719e822cb26ef28d40ad8e3c1
      blocked: false
---

# Gate ledger — parley.nvim#257 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T09:59:13-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `advance-target-diverges-from-submitted` (kind: defect) Cursor outside any exchange: submit answers the last exchange but the cursor jumps to question 1
  chat_respond.lua:2196 passes `exchange_idx or 0` to advance_after_submit, but start_scoped_response (line 1552) submits `frame.exchange_idx or #parsed.exchanges`. Reproduced: body {'💬: first','','🤖: a1','answer one','','💬: second',''}, cursor {1,0}, submit leaves the cursor on row 5 ('💬: first') instead of row 1. Fix: pass the index start_scoped_response resolved and add this case as a regression test. This is the only instance in the window.
- **BR-2** [Important] `done-when-covers-revisions` (kind: defect) Done-when does not cover the Stop rule change from Revisions
  Revisions 2026-10-16 changes stop_at_cursor (chat_respond.lua:1498-1501): with the cursor on no running response, one running response is stopped without a picker, and two or more still open it. No Done-when clause covers this user-visible behavior. Add one.
- **BR-3** [Minor] `arch-dry-chat-parse-sequence` (kind: defect) advance_after_submit repeats the lines, header, parse sequence owned by chat_context.resolve
  chat_respond.lua:1990-1994 repeats chat_respond.lua:1611-1615 and parley.chat_context.resolve. The Plan's claim of one parse per submit (ARCH-CONSTRAINTS) is also wrong: the advance always adds a full parse.
- **BR-4** [Minor] `done-when-clause-both-modes` (kind: defect) Insert-mode submission path has no test
  Done-when names normal, insert and visual paths, but only normal and visual are tested. Because stopinsert takes effect after the command, leaving insert mode may shift the cursor one column left onto the space after the prefix.

## Round 2 — 2026-10-16T10:26:39-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — chat_respond.lua:2197 one `submitted` index feeds both; reverting to `exchange_idx or 0` turns the new regression test red.
- BR-2 — addressed — Done-when gained the Stop clause; tested both ways (direct stop with one running, picker with 2 items in the stale-picker case).
- BR-3 — addressed — advance_after_submit now parses via chat_context.parse; Revisions corrects the one-parse claim.
- BR-4 — addressed — Insert-mode test added and fails when the adjustment is removed; a temporary copy of the real keymap handler also landed after the prefix.

### Raised

- **BR-5** [Minor] `advance-target-diverges-from-submitted` (kind: defect) Drill-in submissions move the cursor off the new turn, against that path's stated intent; untested
  chat_respond.lua:2111 puts the cursor on the inserted turn so post-stream moves land there; the advance then moves it to an older exchange below and follow stops. Decide: skip the advance when branch_handled is set, or pin it with a test. Only instance in this window.
- **BR-6** [Minor] `plan-signature-drift` (kind: defect) Plan gives next_question_cursor(parsed, index, config); code is (parsed, index, lines, prefix)
  chat_respond.lua:1971. Add a Revisions entry. Only instance in this window.

## Open findings

- **BR-5** [Minor] `advance-target-diverges-from-submitted` (kind: defect) Drill-in submissions move the cursor off the new turn, against that path's stated intent; untested
- **BR-6** [Minor] `plan-signature-drift` (kind: defect) Plan gives next_question_cursor(parsed, index, config); code is (parsed, index, lines, prefix)
