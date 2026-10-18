---
gate: boundary-review
issue: 387
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: c966caaf-8e54-47d3-b6d2-de653c386df8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000387"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/210aaf5863e9e92b
            reviewed_head: 2842873c3b0e939612c75a5088fe77221a1712c4
            slot: parley.nvim:3
            requested_at: "2026-10-18T19:25:49.434981Z"
          phase: finished
          pid: 53786
          started_at: "2026-10-18T19:25:49.53626Z"
          finished_at: "2026-10-18T19:32:54.00303Z"
          session_id: a3e13219-be7b-4ec8-9b8a-b89035191986
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2842873c3b0e939612c75a5088fe77221a1712c4
        tracker_head: 0c808096f54a10cc89eb1099755340e4efebade3
        branch_point: a67ec3d7773f36787e8f51fb6afbf13a02c5ca78
        since: "2026-10-18T11:13:01-07:00"
        until: "2026-10-18T11:36:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T11:13:01-07:00"
              end: "2026-10-18T11:36:30-07:00"
              began: "2026-10-18T11:13:01-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: e15c94a3e5d02c3a904dca11d22156fc1422a08aec2f403a12a2603a23641a8a
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 38050570
              windows:
                - start: "2026-10-18T11:13:01-07:00"
                  end: "2026-10-18T11:36:30-07:00"
        queue_waits:
            - attempt_id: 0cb0c7f21728bb2cd806cf64a7445e79
              slot: parley.nvim:3
              record_digest: 81f5365a39b6004b18f2d6d3ca3c0f92a4d9954066cbe9b68488b3f1a36c49f0
              start: "2026-10-18T18:19:46.247835Z"
              end: "2026-10-18T18:32:45.301936Z"
              queue_seconds: 779.054101
              raw_seconds: 779.054101
              exact: true
      "n": 1
      timestamp: "2026-10-18T12:32:54-07:00"
      dispatched: "2026-10-18T12:25:49-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Two comments still describe the old deletion and footnote-reload behaviour
          detail: atlas/chat/inline_define.md:152 (edited in this window) says reloaded footnotes don't recreate the ParleyEditAdd highlight, but publish_footnotes -> highlight_footnote_span does (skill_render.lua:101-126; tested in highlighting_spec.lua:753/775/797). lua/parley/skills/review/mode.lua:8 describes apply-with-gutter-why as "explain in the gutter", but pure deletions no longer get a gutter diagnostic (round.md:49 already puts the why in the reply or a note). Fix both comments.
          family: doc-claim-drift
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: attach_diagnostics doc line sits between two @param tags
          detail: 'skill_render.lua:224: move "A pure deletion ... leaves no trace" above the @param block. No other instance in this window.'
          family: doc-comment-placement
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: 'ARCH-DRY: delete rule re-checked next to the kind field'
          detail: attach_diagnostics (skill_render.lua:230) and highlight_edits (skill_render.lua:271) test new_string ~= "" on top of kind ~= "delete", repeating part of presentation.kind; decorations (presentation.lua) also calls M.kind twice per span. Rely on the kind (or call presentation.kind once) so the rule has one source.
          family: kind-rule-restated
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 2842873c3b0e939612c75a5088fe77221a1712c4
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a4b6ce80-1915-487b-9e48-9227a02f9ff1
            repository: github.com/xianxu/parley.nvim
            issue_id: "000387"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/532beda65f31019c
            reviewed_head: 6a3660d606f4b8ec358e602192d7776ae7520a28
            slot: parley.nvim:3
            requested_at: "2026-10-18T20:33:02.017498Z"
          phase: finished
          pid: 36902
          started_at: "2026-10-18T20:33:02.141187Z"
          finished_at: "2026-10-18T20:46:59.054308Z"
          session_id: 083bd6ac-146a-45e4-9a2c-d738d8f98fbe
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 6a3660d606f4b8ec358e602192d7776ae7520a28
        tracker_head: e90ef708739e50f983c5e8649aebd0bbfde574c1
        branch_point: a67ec3d7773f36787e8f51fb6afbf13a02c5ca78
        since: "2026-10-18T11:13:01-07:00"
        until: "2026-10-18T12:34:09-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T11:13:01-07:00"
              end: "2026-10-18T12:34:09-07:00"
              began: "2026-10-18T11:13:01-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: f2d4c466d7b79056adf08a2efa657ec00bbfd1146fd42bf95eedadd59ff3d547
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 38612543
              windows:
                - start: "2026-10-18T11:13:01-07:00"
                  end: "2026-10-18T12:34:09-07:00"
        queue_waits:
            - attempt_id: 0cb0c7f21728bb2cd806cf64a7445e79
              slot: parley.nvim:3
              record_digest: 81f5365a39b6004b18f2d6d3ca3c0f92a4d9954066cbe9b68488b3f1a36c49f0
              start: "2026-10-18T18:19:46.247835Z"
              end: "2026-10-18T18:32:45.301936Z"
              queue_seconds: 779.054101
              raw_seconds: 779.054101
              exact: true
            - attempt_id: 002707c244ee6f7fbe3f28e981d862c6
              slot: parley.nvim:3
              record_digest: 0faace3b0a91ef2f75cfe85011b441cb97c61ee16466ff13bcce1bcf0b4ee7a9
              start: "2026-10-18T18:36:36.612131Z"
              end: "2026-10-18T19:18:54.468203Z"
              queue_seconds: 2537.856072
              raw_seconds: 2537.856072
              exact: true
        cuts:
            - dispatched: "2026-10-18T12:25:49-07:00"
              finalized: "2026-10-18T12:32:54-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-18T13:46:59-07:00"
      dispatched: "2026-10-18T13:33:02-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: atlas/chat/inline_define.md:152 now says publish_footnotes redraws the ParleyEditAdd span (matches highlight_footnote_span, skill_render.lua:106, EDIT_HL.add). mode.lua:8-10 now puts the why in the agent's reply, consistent with round.md:49 and SKILL.md:53. I grepped the tree for other stale deletion/gutter claims and found none.
          round: 2
        - id: BR-2
          disposition: addressed
          note: skill_render.lua:223 deletion line now sits in the description above the @param block.
          round: 2
        - id: BR-3
          disposition: addressed
          note: attach_diagnostics (skill_render.lua:230) and highlight_edits (:269) test only kind ~= "delete"; decorations calls M.kind once per span (presentation.lua:101-102). The change is structural only; the existing deletion specs (skill_render_spec.lua:80, presentation_spec) still pin the behaviour and pass under make test-spec.
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 6a3660d606f4b8ec358e602192d7776ae7520a28
      blocked: false
---

# Gate ledger — parley.nvim#387 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T12:32:54-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `doc-claim-drift` (kind: defect) Two comments still describe the old deletion and footnote-reload behaviour
  atlas/chat/inline_define.md:152 (edited in this window) says reloaded footnotes don't recreate the ParleyEditAdd highlight, but publish_footnotes -> highlight_footnote_span does (skill_render.lua:101-126; tested in highlighting_spec.lua:753/775/797). lua/parley/skills/review/mode.lua:8 describes apply-with-gutter-why as "explain in the gutter", but pure deletions no longer get a gutter diagnostic (round.md:49 already puts the why in the reply or a note). Fix both comments.
- **BR-2** [Minor] `doc-comment-placement` (kind: defect) attach_diagnostics doc line sits between two @param tags
  skill_render.lua:224: move "A pure deletion ... leaves no trace" above the @param block. No other instance in this window.
- **BR-3** [Minor] `kind-rule-restated` (kind: defect) ARCH-DRY: delete rule re-checked next to the kind field
  attach_diagnostics (skill_render.lua:230) and highlight_edits (skill_render.lua:271) test new_string ~= "" on top of kind ~= "delete", repeating part of presentation.kind; decorations (presentation.lua) also calls M.kind twice per span. Rely on the kind (or call presentation.kind once) so the rule has one source.

## Round 2 — 2026-10-18T13:46:59-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — atlas/chat/inline_define.md:152 now says publish_footnotes redraws the ParleyEditAdd span (matches highlight_footnote_span, skill_render.lua:106, EDIT_HL.add). mode.lua:8-10 now puts the why in the agent's reply, consistent with round.md:49 and SKILL.md:53. I grepped the tree for other stale deletion/gutter claims and found none.
- BR-2 — addressed — skill_render.lua:223 deletion line now sits in the description above the @param block.
- BR-3 — addressed — attach_diagnostics (skill_render.lua:230) and highlight_edits (:269) test only kind ~= "delete"; decorations calls M.kind once per span (presentation.lua:101-102). The change is structural only; the existing deletion specs (skill_render_spec.lua:80, presentation_spec) still pin the behaviour and pass under make test-spec.

## Open findings

(none — every finding has been disposed)
