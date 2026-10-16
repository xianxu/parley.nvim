---
gate: boundary-review
issue: 265
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a1e8a057-d788-4577-bfdc-cc8186a37e4b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000265"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/190e3beb23d42074
            reviewed_head: aa4b87224ba44fa88733bebd9026194270561e84
            slot: parley.nvim:4
            requested_at: "2026-10-16T11:24:28.8718Z"
          phase: finished
          pid: 2065
          started_at: "2026-10-16T11:24:29.084713Z"
          finished_at: "2026-10-16T11:29:20.028412Z"
          session_id: 57a4984c-d787-4343-a5a7-bdfe2b1ca9e5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: aa4b87224ba44fa88733bebd9026194270561e84
        tracker_head: 263399187169f3beb975a3612daf13690ae57be0
        branch_point: 99d396d5510868bf63e983b28d43c27b931492f9
        since: "2026-10-16T04:02:56-07:00"
        until: "2026-10-16T04:20:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T04:02:56-07:00"
              end: "2026-10-16T04:20:53-07:00"
              began: "2026-10-16T04:02:56-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 576d05fa91812c0da03217669d809c627cb48990d2aab2d1dc97350ba0c12165
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 7328478
              windows:
                - start: "2026-10-16T04:02:56-07:00"
                  end: "2026-10-16T04:20:53-07:00"
      "n": 1
      timestamp: "2026-10-16T04:29:20-07:00"
      dispatched: "2026-10-16T04:24:28-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: _replace_user_lines drops result.error, so an editor error is reported as "unexpected (error)" with no details anywhere
          detail: 'buffer_edit.lua:121 returns result.reason or result.status; the old raise included result.error. For status=''error'' (editor.lua:299, a write that mutated then errored, possibly partial) the warning points at the Parley log, but nothing writes the error text there. Fix: carry result.error through as detail.notice or log it, and add a unit case.'
          family: refusal-drops-cause
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: The arch spec bans only replace_user_lines; direct capture_user/apply_user command sites keep their own wordings, and spell_source still raises
          detail: init.lua:2042 (Define), :2241/:2248 (Marker), :2575 (Branch planned path) and interview.lua:284 each word refusals outside refusal.lua. spell_source.lua:63/:66 raise error() on a keystroke path, and Source:execute re-raises it. Route them through the policy's words, or name them in the plan as exceptions or a follow-up, and widen the arch spec to match.
          family: edit-policy-enforced-by-name-only
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: ChatReview gives two warnings on a refused back-reference
          detail: edit_user_lines warns, then init.lua:4155 warns again. Pass quiet=true and send one combined message.
          family: one-warning-per-refusal
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Slug rename header restore and ChatPrune write-failure ordering leave edge-case partial state
          detail: If the restore edit after a failed rename is refused, the new header stays while the file keeps its old name. ChatPrune now prunes the parent before writefile, so a writefile error leaves the parent pruned but unsaved.
          family: partial-state-on-refusal
          round: 1
      recipe: milestone-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4ec49ada-2203-4ed2-8bcd-88a5cee637da
            repository: github.com/xianxu/parley.nvim
            issue_id: "000265"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/4524b214f87b624c
            reviewed_head: b7bcc8ee649f2002e7543c76bc4e09cf3dfe5448
            slot: parley.nvim:4
            requested_at: "2026-10-16T11:41:57.60677Z"
          phase: finished
          pid: 32131
          started_at: "2026-10-16T11:41:57.79695Z"
          finished_at: "2026-10-16T11:46:00.518111Z"
          session_id: acf3963f-32b8-483d-ae22-671db538f6ad
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: b7bcc8ee649f2002e7543c76bc4e09cf3dfe5448
        tracker_head: 263399187169f3beb975a3612daf13690ae57be0
        branch_point: 99d396d5510868bf63e983b28d43c27b931492f9
        since: "2026-10-16T04:02:56-07:00"
        until: "2026-10-16T04:38:35-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T04:02:56-07:00"
              end: "2026-10-16T04:38:35-07:00"
              began: "2026-10-16T04:02:56-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: ac3b73a53882daad8b9bcc090a08888214e14af36b925dcee96ba39be87b146f
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 7918867
              windows:
                - start: "2026-10-16T04:02:56-07:00"
                  end: "2026-10-16T04:38:35-07:00"
        cuts:
            - dispatched: "2026-10-16T04:24:28-07:00"
              finalized: "2026-10-16T04:29:20-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T04:46:01-07:00"
      dispatched: "2026-10-16T04:41:57-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: 'The words path is fixed, but no test protects the passthrough at buffer_edit.lua:134. Removing result.error there leaves every spec green, because the unit case swaps out _replace_user_lines. A modifiable=false buffer is a real oracle: probed, it returns ''error'' with "Buffer is not ''modifiable''".'
          round: 2
        - id: BR-2
          disposition: addressed
          note: Define, Marker, Branch, PruneTopic, InsertChatReference, InterviewTimestamp, SpellCorrection and PasteImage now report through report_refusal or refusal.edit, and spell_source no longer raises. The arch spec lists every direct caller (checked both ways) and rejects hand-worded refusals in the keystroke files. It passes on the head.
          round: 2
        - id: BR-3
          disposition: addressed
          note: ChatReview makes a quiet edit and gives one combined warning. user_edit_refusal_spec.lua:104 asserts exactly one warning.
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: 'The slug half is done: a failed header restore is now reported. The ChatPrune half is not: the rollback checks writefile ~= 0, but a real Neovim write failure raises E482 (probed), so the rollback never runs. The edit-first reorder now leaves the parent pruned, no child file, and a raw error. Catch the raise as well.'
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Important
          title: ChatPrune's write-failure test fakes writefile returning -1, which the real function never does, so the broken production path passes
          detail: 'This is the 2nd finding in family partial-state-on-refusal. The rule: a command that edits first and then does fallible IO must treat a raise and an error return from that IO as the same failure and roll back, and its test must fail the IO the way the real dependency does (ARCH-MOCK). Here the fake at user_edit_refusal_spec.lua:113 returns -1, but real vim.fn.writefile raises Vim:E482 (probed for a missing directory and permission denied), so init.lua:4548''s rollback never runs in production. Fix: pcall the write, and have the test raise E482 or use a read-only directory. Sweep: of this diff''s edit-first sites, only ChatPrune''s write can raise. Slug rename''s vim.fn.rename returns a status, and ExchangeCut''s setreg comes after the edit and changes no file.'
          family: partial-state-on-refusal
          round: 2
        - kind: defect
          id: BR-6
          severity: Important
          title: Done-when bullets 1 and 3 no longer describe what was built after the Revisions entry
          detail: Bullet 3 still asks for a helper that puts a buffer under a live generation; the Revisions entry measured that as impossible and replaced it with the capacity helper. Bullet 1 covers only replace_user_lines refusals, but close round 1 also brought the hand-capture keystroke commands under the policy. Rewrite both bullets in place and state the empty list of sites that deliberately raise.
          family: done-when-tracks-revisions
          round: 2
      recipe: milestone-review
      isolation: checkout
      blocked: true
---

# Gate ledger — parley.nvim#265 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T04:29:20-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `refusal-drops-cause` (kind: defect) _replace_user_lines drops result.error, so an editor error is reported as "unexpected (error)" with no details anywhere
  buffer_edit.lua:121 returns result.reason or result.status; the old raise included result.error. For status='error' (editor.lua:299, a write that mutated then errored, possibly partial) the warning points at the Parley log, but nothing writes the error text there. Fix: carry result.error through as detail.notice or log it, and add a unit case.
- **BR-2** [Important] `edit-policy-enforced-by-name-only` (kind: defect) The arch spec bans only replace_user_lines; direct capture_user/apply_user command sites keep their own wordings, and spell_source still raises
  init.lua:2042 (Define), :2241/:2248 (Marker), :2575 (Branch planned path) and interview.lua:284 each word refusals outside refusal.lua. spell_source.lua:63/:66 raise error() on a keystroke path, and Source:execute re-raises it. Route them through the policy's words, or name them in the plan as exceptions or a follow-up, and widen the arch spec to match.
- **BR-3** [Minor] `one-warning-per-refusal` (kind: defect) ChatReview gives two warnings on a refused back-reference
  edit_user_lines warns, then init.lua:4155 warns again. Pass quiet=true and send one combined message.
- **BR-4** [Minor] `partial-state-on-refusal` (kind: defect) Slug rename header restore and ChatPrune write-failure ordering leave edge-case partial state
  If the restore edit after a failed rename is refused, the new header stays while the file keeps its old name. ChatPrune now prunes the parent before writefile, so a writefile error leaves the parent pruned but unsaved.

## Round 2 — 2026-10-16T04:46:01-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — not-addressed — The words path is fixed, but no test protects the passthrough at buffer_edit.lua:134. Removing result.error there leaves every spec green, because the unit case swaps out _replace_user_lines. A modifiable=false buffer is a real oracle: probed, it returns 'error' with "Buffer is not 'modifiable'".
- BR-2 — addressed — Define, Marker, Branch, PruneTopic, InsertChatReference, InterviewTimestamp, SpellCorrection and PasteImage now report through report_refusal or refusal.edit, and spell_source no longer raises. The arch spec lists every direct caller (checked both ways) and rejects hand-worded refusals in the keystroke files. It passes on the head.
- BR-3 — addressed — ChatReview makes a quiet edit and gives one combined warning. user_edit_refusal_spec.lua:104 asserts exactly one warning.
- BR-4 — not-addressed — The slug half is done: a failed header restore is now reported. The ChatPrune half is not: the rollback checks writefile ~= 0, but a real Neovim write failure raises E482 (probed), so the rollback never runs. The edit-first reorder now leaves the parent pruned, no child file, and a raw error. Catch the raise as well.

### Raised

- **BR-5** [Important] `partial-state-on-refusal` (kind: defect) ChatPrune's write-failure test fakes writefile returning -1, which the real function never does, so the broken production path passes
  This is the 2nd finding in family partial-state-on-refusal. The rule: a command that edits first and then does fallible IO must treat a raise and an error return from that IO as the same failure and roll back, and its test must fail the IO the way the real dependency does (ARCH-MOCK). Here the fake at user_edit_refusal_spec.lua:113 returns -1, but real vim.fn.writefile raises Vim:E482 (probed for a missing directory and permission denied), so init.lua:4548's rollback never runs in production. Fix: pcall the write, and have the test raise E482 or use a read-only directory. Sweep: of this diff's edit-first sites, only ChatPrune's write can raise. Slug rename's vim.fn.rename returns a status, and ExchangeCut's setreg comes after the edit and changes no file.
- **BR-6** [Important] `done-when-tracks-revisions` (kind: defect) Done-when bullets 1 and 3 no longer describe what was built after the Revisions entry
  Bullet 3 still asks for a helper that puts a buffer under a live generation; the Revisions entry measured that as impossible and replaced it with the capacity helper. Bullet 1 covers only replace_user_lines refusals, but close round 1 also brought the hand-capture keystroke commands under the policy. Rewrite both bullets in place and state the empty list of sites that deliberately raise.

## Open findings

- **BR-1** [Important] `refusal-drops-cause` (kind: defect) _replace_user_lines drops result.error, so an editor error is reported as "unexpected (error)" with no details anywhere
- **BR-4** [Minor] `partial-state-on-refusal` (kind: defect) Slug rename header restore and ChatPrune write-failure ordering leave edge-case partial state
- **BR-5** [Important] `partial-state-on-refusal` (kind: defect) ChatPrune's write-failure test fakes writefile returning -1, which the real function never does, so the broken production path passes
- **BR-6** [Important] `done-when-tracks-revisions` (kind: defect) Done-when bullets 1 and 3 no longer describe what was built after the Revisions entry
