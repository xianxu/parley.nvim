---
gate: boundary-review
issue: 417
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 5ab14ae6-65ba-448f-bf86-eb592a911513
            repository: github.com/xianxu/parley.nvim
            issue_id: "000417"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/768a9b9e436ceb93
            reviewed_head: ff795ebb314708b3901ef07ded0dba2b8826b571
            slot: parley.nvim:1
            requested_at: "2026-10-23T01:11:02.410636Z"
          phase: finished
          pid: 45127
          started_at: "2026-10-23T01:11:02.505382Z"
          finished_at: "2026-10-23T01:13:22.994027Z"
          session_id: 01a1664f-b77f-7430-a67e-b456ed618103
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: ff795ebb314708b3901ef07ded0dba2b8826b571
        tracker_head: c092c40a52ff5bc7f1bf6e0d7dc871b0514a7da0
        branch_point: 6fd47fd82f6aeab218ff8cd0c6c989c6ffb7b412
        since: "2026-10-22T18:01:39-07:00"
        until: "2026-10-22T18:10:25-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T18:01:39-07:00"
              end: "2026-10-22T18:10:25-07:00"
              began: "2026-10-22T18:01:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 07429da6c524a41b09fff7427049418b6c2ab258fd0ae1d877dbd4ac94170b42
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 110671031
              windows:
                - start: "2026-10-22T18:01:39-07:00"
                  end: "2026-10-22T18:10:25-07:00"
            - harness: codex
              id: 01a16649-595c-70b2-bd6d-e97dbdcbb200
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 78facb0c1be6a5ca52dc01de6da66a68791f2e3b9e30d7af464a2a1ca578f067
              started: "2026-10-23T01:04:05.56Z"
              spawned: true
              bytes: 952959
              windows:
                - start: "2026-10-23T01:04:05.56Z"
                  end: "2026-10-22T18:10:25-07:00"
      "n": 1
      timestamp: "2026-10-22T18:13:23-07:00"
      dispatched: "2026-10-22T18:11:02-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Shrink diagnostics still make successful image pastes require Enter
          detail: 'lua/parley/paste_image.lua:164-167 appends an unbounded outcome suffix to the shortened success message. On pinned HEAD, an attached 80×24 UI on Neovim 0.11.7 entered mode "r" after Alt+i in both Normal and Insert modes with either fake_sips returning garbage or no shrink tool available; the attachment and link had already landed. ARCH-PURPOSE: shortening only the no-diagnostic outcome leaves the reported prompt unresolved for other successful pastes. The family has one emission site in this window, fed by all three note-producing paths in image_shrink.lua:240,245,258: conversion-limit refusal, tool/configuration resolution failure, and converter execution/output failure. Preserve diagnostics through a nonblocking presentation and add native UI regression cases for these outcomes. The changed recording-notifier assertions at paste_image_spec.lua:520,535 cannot detect hit-enter; atlas/chat/attachments.md:17-18 also overstates the resulting guarantee.'
          family: paste-completion-must-not-block-input
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#417 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T18:13:23-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `paste-completion-must-not-block-input` (kind: defect) Shrink diagnostics still make successful image pastes require Enter
  lua/parley/paste_image.lua:164-167 appends an unbounded outcome suffix to the shortened success message. On pinned HEAD, an attached 80×24 UI on Neovim 0.11.7 entered mode "r" after Alt+i in both Normal and Insert modes with either fake_sips returning garbage or no shrink tool available; the attachment and link had already landed. ARCH-PURPOSE: shortening only the no-diagnostic outcome leaves the reported prompt unresolved for other successful pastes. The family has one emission site in this window, fed by all three note-producing paths in image_shrink.lua:240,245,258: conversion-limit refusal, tool/configuration resolution failure, and converter execution/output failure. Preserve diagnostics through a nonblocking presentation and add native UI regression cases for these outcomes. The changed recording-notifier assertions at paste_image_spec.lua:520,535 cannot detect hit-enter; atlas/chat/attachments.md:17-18 also overstates the resulting guarantee.

## Open findings

- **BR-1** [Critical] `paste-completion-must-not-block-input` (kind: defect) Shrink diagnostics still make successful image pastes require Enter
