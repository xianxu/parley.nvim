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

## Open findings

- **BR-1** [Important] `refusal-drops-cause` (kind: defect) _replace_user_lines drops result.error, so an editor error is reported as "unexpected (error)" with no details anywhere
- **BR-2** [Important] `edit-policy-enforced-by-name-only` (kind: defect) The arch spec bans only replace_user_lines; direct capture_user/apply_user command sites keep their own wordings, and spell_source still raises
- **BR-3** [Minor] `one-warning-per-refusal` (kind: defect) ChatReview gives two warnings on a refused back-reference
- **BR-4** [Minor] `partial-state-on-refusal` (kind: defect) Slug rename header restore and ChatPrune write-failure ordering leave edge-case partial state
