---
gate: boundary-review
issue: 386
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 949630c7-4702-4875-acb5-5819e1c4591b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000386"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f504c4f5485847b2
            reviewed_head: 248e11d528ccc8ea5f7c95405bcbe819e2c49355
            slot: parley.nvim:3
            requested_at: "2026-10-18T16:56:55.994632Z"
          phase: finished
          pid: 72299
          started_at: "2026-10-18T16:56:56.088222Z"
          finished_at: "2026-10-18T17:08:59.135896Z"
          session_id: 0e8e8fb0-5cab-4066-90eb-9a979136c9af
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 248e11d528ccc8ea5f7c95405bcbe819e2c49355
        tracker_head: cd1bb98b97de1e154aafa6e90d4d0b292159794c
        branch_point: 998cde19c99d8d15d45b98e6edee98229ca3e637
        since: "2026-10-18T09:40:29-07:00"
        until: "2026-10-18T09:51:15-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T09:40:29-07:00"
              end: "2026-10-18T09:51:15-07:00"
              began: "2026-10-18T09:40:29-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ba9e3a22ba53eaef92982483a50832917bdba94825845ba6687025942f1ce95c
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 36641412
              windows:
                - start: "2026-10-18T09:40:29-07:00"
                  end: "2026-10-18T09:51:15-07:00"
      "n": 1
      timestamp: "2026-10-18T10:09:00-07:00"
      dispatched: "2026-10-18T09:56:55-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Atlas and Log claim every Parley group is re-applied on ColorScheme, but only setup_highlights groups are
          detail: 'highlighter.lua:1070 re-runs only setup_highlights. Groups defined elsewhere are still lost after :hi clear: ParleySessionSync* (session_sync.lua:536, defined once on first attach, so attached buffers lose their turn band), ParleyAttention* (attention.lua:230), ParleyTagOn/Off/Action (float_picker.lua:811), the issue_tracker.lua:71 card highlight (re-ensured lazily), and the diag_display groups (re-set per ensure_display). atlas/ui/highlights.md says "Every group is re-applied on ColorScheme". Fix: call those modules'' define functions from the ColorScheme callback, or narrow the atlas and Log wording to setup_highlights groups.'
          family: highlight-groups-survive-colorscheme
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: position_of is a third byte-offset to (row, col) converter (ARCH-DRY)
          detail: skill_render.lua:251 position_of duplicates init.lua:2107 byte_offset_to_rowcol and skills/review/init.lua:258 offset_to_pos. All three are local; they could become one shared pure helper.
          family: offset-to-rowcol-helper
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e51952ae-19db-4cd6-aa1f-e6a59386e434
            repository: github.com/xianxu/parley.nvim
            issue_id: "000386"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/05d9485f170113c2
            reviewed_head: 0b8c2fa14d28084ae98bc18d93956c8f5a58ba97
            slot: parley.nvim:3
            requested_at: "2026-10-18T17:22:38.991115Z"
          phase: finished
          pid: 92085
          started_at: "2026-10-18T17:22:39.087806Z"
          finished_at: "2026-10-18T17:42:36.283883Z"
          session_id: 242c8302-de3c-40f2-a032-2dd0edaf5ce3
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0b8c2fa14d28084ae98bc18d93956c8f5a58ba97
        tracker_head: cd1bb98b97de1e154aafa6e90d4d0b292159794c
        branch_point: 998cde19c99d8d15d45b98e6edee98229ca3e637
        since: "2026-10-18T09:40:29-07:00"
        until: "2026-10-18T10:14:31-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T09:40:29-07:00"
              end: "2026-10-18T10:14:31-07:00"
              began: "2026-10-18T09:40:29-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d4a50a7177cd94c661f5c413e83cafa54ef2afe1d3eef831ed6a888cd6aa45c9
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 37076797
              windows:
                - start: "2026-10-18T09:40:29-07:00"
                  end: "2026-10-18T10:14:31-07:00"
        queue_waits:
            - attempt_id: 10a6feafee9522ddb3c20acc0f5321ec
              slot: parley.nvim:3
              record_digest: c9cfaa5d9fedda1e8f42539767a67efeb440fe91eeb4a6e200d971f16dec7c27
              start: "2026-10-18T16:51:26.152903Z"
              end: "2026-10-18T16:51:26.209718Z"
              queue_seconds: 0.056815
              raw_seconds: 0.056815
              exact: true
        cuts:
            - dispatched: "2026-10-18T09:56:55-07:00"
              finalized: "2026-10-18T10:09:00-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-18T10:42:37-07:00"
      dispatched: "2026-10-18T10:22:38-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: highlight_groups.keep is registered by all six group-defining modules (grep of nvim_set_hl in lua/ confirms); the guard spec in highlight_groups_spec fails for any unregistered module; the atlas text matches.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: position_of (skill_render.lua:251) is still a third local offset-to-(row, col) converter; the deferral is reasonable for a Minor and does not block.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Minor
          title: README says restyle via the ParleyEditChange group, but setup_highlights overwrites it on every ColorScheme
          detail: highlighter.lua:677 sets ParleyEditChange without default=true and re-runs it on ColorScheme through highlight_groups.keep, so a user's direct :hi ParleyEditChange is lost at the next :colorscheme. README.md:112 should point to highlight.edit_change only, which is what the Log already says.
          family: override-through-config
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 0b8c2fa14d28084ae98bc18d93956c8f5a58ba97
      blocked: false
---

# Gate ledger — parley.nvim#386 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T10:09:00-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `highlight-groups-survive-colorscheme` (kind: defect) Atlas and Log claim every Parley group is re-applied on ColorScheme, but only setup_highlights groups are
  highlighter.lua:1070 re-runs only setup_highlights. Groups defined elsewhere are still lost after :hi clear: ParleySessionSync* (session_sync.lua:536, defined once on first attach, so attached buffers lose their turn band), ParleyAttention* (attention.lua:230), ParleyTagOn/Off/Action (float_picker.lua:811), the issue_tracker.lua:71 card highlight (re-ensured lazily), and the diag_display groups (re-set per ensure_display). atlas/ui/highlights.md says "Every group is re-applied on ColorScheme". Fix: call those modules' define functions from the ColorScheme callback, or narrow the atlas and Log wording to setup_highlights groups.
- **BR-2** [Minor] `offset-to-rowcol-helper` (kind: defect) position_of is a third byte-offset to (row, col) converter (ARCH-DRY)
  skill_render.lua:251 position_of duplicates init.lua:2107 byte_offset_to_rowcol and skills/review/init.lua:258 offset_to_pos. All three are local; they could become one shared pure helper.

## Round 2 — 2026-10-18T10:42:37-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — highlight_groups.keep is registered by all six group-defining modules (grep of nvim_set_hl in lua/ confirms); the guard spec in highlight_groups_spec fails for any unregistered module; the atlas text matches.
- BR-2 — not-addressed — position_of (skill_render.lua:251) is still a third local offset-to-(row, col) converter; the deferral is reasonable for a Minor and does not block.

### Raised

- **BR-3** [Minor] `override-through-config` (kind: defect) README says restyle via the ParleyEditChange group, but setup_highlights overwrites it on every ColorScheme
  highlighter.lua:677 sets ParleyEditChange without default=true and re-runs it on ColorScheme through highlight_groups.keep, so a user's direct :hi ParleyEditChange is lost at the next :colorscheme. README.md:112 should point to highlight.edit_change only, which is what the Log already says.

## Open findings

- **BR-2** [Minor] `offset-to-rowcol-helper` (kind: defect) position_of is a third byte-offset to (row, col) converter (ARCH-DRY)
- **BR-3** [Minor] `override-through-config` (kind: defect) README says restyle via the ParleyEditChange group, but setup_highlights overwrites it on every ColorScheme
