---
gate: boundary-review
issue: 356
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b0e41b29-678e-493a-be81-f1f494ead2f2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000356"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/5e43d11734c4c356
            reviewed_head: 58023dd807a67782915211579177363542b767df
            slot: parley.nvim:4
            requested_at: "2026-10-16T18:46:09.443071Z"
          phase: finished
          pid: 13356
          started_at: "2026-10-16T18:46:09.703271Z"
          finished_at: "2026-10-16T18:52:24.128449Z"
          session_id: 4066e585-2f16-4213-b249-86a391cc0ab7
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 58023dd807a67782915211579177363542b767df
        tracker_head: 5ab6a77aaa09d5c23f8d1edeccc06ae4422a5342
        branch_point: 4c7e3dc94ec78cbae5fd05cad4715abc58e4a342
        since: "2026-10-16T11:10:23-07:00"
        until: "2026-10-16T11:39:06-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T11:10:23-07:00"
              end: "2026-10-16T11:39:06-07:00"
              began: "2026-10-16T11:10:23-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: dee397ff0213ac7ca377f6eea8aa71402a03cf52463339e2bcf236917bd76cf0
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 17430630
              windows:
                - start: "2026-10-16T11:10:23-07:00"
                  end: "2026-10-16T11:39:06-07:00"
      "n": 1
      timestamp: "2026-10-16T11:52:24-07:00"
      dispatched: "2026-10-16T11:46:09-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: restore_views overwrites curswant with the byte column on every reload
          detail: session_sync.lua:328 sets view.curswant = pos[2] even when the cursor line is outside every hunk, so $-stickiness (MAXCOL) is lost and lines with tabs or multibyte characters get the wrong virtual column for the next j/k. Keep the original curswant when the column is unchanged, or recompute it via virtcol after winrestview.
          family: view-restore-fidelity
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: view_map computes the full-buffer diff twice per window on each reload (ARCH-DRY)
          detail: map and map_line each call hunks(old, new), so restoring N windows runs 2N vim.diff calls on the poll path. Compute the hunks once in restore_views and pass them in, or expose a variant of map/map_line that takes hunks.
          family: repeated-derived-computation
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: at-cursor integration test comment says the cursor sat on "02"; it is on the "1" of "12"
          detail: 'tests/integration/session_sync_spec.lua:381: the header has 8 lines, so doc line 20 is body line 12 ("line 12 of the body"), and column 5 is the "1" of "12".'
          family: test-comment-accuracy
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Other agent-rewrite reload paths (file_refresh, review-skill edit!) do not map cursor/view (ARCH-PURPOSE)
          detail: 'tools/file_refresh.lua replaces buffer lines, and skills/review/init.lua:636 runs an :edit! round reload, without view_map. Both are outside #356''s stated session_sync scope; they are a candidate follow-up that can reuse view_map.'
          family: rewrite-paths-map-views
          round: 1
      recipe: milestone-review
      isolation: fenced
      reviewed: 58023dd807a67782915211579177363542b767df
      blocked: false
---

# Gate ledger — parley.nvim#356 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T11:52:24-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `view-restore-fidelity` (kind: defect) restore_views overwrites curswant with the byte column on every reload
  session_sync.lua:328 sets view.curswant = pos[2] even when the cursor line is outside every hunk, so $-stickiness (MAXCOL) is lost and lines with tabs or multibyte characters get the wrong virtual column for the next j/k. Keep the original curswant when the column is unchanged, or recompute it via virtcol after winrestview.
- **BR-2** [Minor] `repeated-derived-computation` (kind: defect) view_map computes the full-buffer diff twice per window on each reload (ARCH-DRY)
  map and map_line each call hunks(old, new), so restoring N windows runs 2N vim.diff calls on the poll path. Compute the hunks once in restore_views and pass them in, or expose a variant of map/map_line that takes hunks.
- **BR-3** [Minor] `test-comment-accuracy` (kind: defect) at-cursor integration test comment says the cursor sat on "02"; it is on the "1" of "12"
  tests/integration/session_sync_spec.lua:381: the header has 8 lines, so doc line 20 is body line 12 ("line 12 of the body"), and column 5 is the "1" of "12".
- **BR-4** [Minor] `rewrite-paths-map-views` (kind: defect) Other agent-rewrite reload paths (file_refresh, review-skill edit!) do not map cursor/view (ARCH-PURPOSE)
  tools/file_refresh.lua replaces buffer lines, and skills/review/init.lua:636 runs an :edit! round reload, without view_map. Both are outside #356's stated session_sync scope; they are a candidate follow-up that can reuse view_map.

## Open findings

- **BR-1** [Minor] `view-restore-fidelity` (kind: defect) restore_views overwrites curswant with the byte column on every reload
- **BR-2** [Minor] `repeated-derived-computation` (kind: defect) view_map computes the full-buffer diff twice per window on each reload (ARCH-DRY)
- **BR-3** [Minor] `test-comment-accuracy` (kind: defect) at-cursor integration test comment says the cursor sat on "02"; it is on the "1" of "12"
- **BR-4** [Minor] `rewrite-paths-map-views` (kind: defect) Other agent-rewrite reload paths (file_refresh, review-skill edit!) do not map cursor/view (ARCH-PURPOSE)
