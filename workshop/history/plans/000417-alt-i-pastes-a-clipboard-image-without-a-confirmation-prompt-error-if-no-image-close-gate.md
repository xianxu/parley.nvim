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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 1adb542a-91a2-4ade-befa-5a1efa04622c
            repository: github.com/xianxu/parley.nvim
            issue_id: "000417"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/511a606f6340ce3b
            reviewed_head: 0761a9dcdd134c023fcdedb09e0d763e2c95c36f
            slot: parley.nvim:1
            requested_at: "2026-10-23T01:26:07.54984Z"
          phase: finished
          pid: 42433
          started_at: "2026-10-23T01:26:07.645826Z"
          finished_at: "2026-10-23T01:28:14.404591Z"
          session_id: 01a1665d-8734-7b70-8aaf-99240af719e9
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0761a9dcdd134c023fcdedb09e0d763e2c95c36f
        tracker_head: c092c40a52ff5bc7f1bf6e0d7dc871b0514a7da0
        branch_point: 6fd47fd82f6aeab218ff8cd0c6c989c6ffb7b412
        since: "2026-10-22T18:01:39-07:00"
        until: "2026-10-22T18:25:05-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T18:01:39-07:00"
              end: "2026-10-22T18:25:05-07:00"
              began: "2026-10-22T18:01:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 417b15481789ed3b868456d26e46a50f808e0700726b2abfd6e6a43b4a9ad883
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 111499043
              windows:
                - start: "2026-10-22T18:01:39-07:00"
                  end: "2026-10-22T18:25:05-07:00"
            - harness: codex
              id: 01a16649-595c-70b2-bd6d-e97dbdcbb200
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 6d87a9d185ef47706aeb28b5d35edac147272b9e913ad46c31c0e9ce2dcae996
              started: "2026-10-23T01:04:05.56Z"
              spawned: true
              bytes: 1319040
              windows:
                - start: "2026-10-23T01:04:05.56Z"
                  end: "2026-10-22T18:25:05-07:00"
        cuts:
            - dispatched: "2026-10-22T18:11:02-07:00"
              finalized: "2026-10-22T18:13:23-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-22T18:28:15-07:00"
      dispatched: "2026-10-22T18:26:07-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: paste_image.lua:164-168 separates diagnostic logging from the fixed success notice. The permanent native tests pass on Neovim 0.12.5 and 0.11.7. Restoring the diagnostic-bearing notice in a disposable archive causes eight native mode assertions to fail on each version, covering every diagnostic producer in both modes. The archive was removed.
          round: 2
      findings:
        - kind: defect
          id: BR-2
          severity: Important
          title: No-image refusal lacks Normal and Insert mapping coverage
          detail: 'tests/integration/paste_image_native_spec.lua:37-46 exercises only image-present cases. The sole no-image assertion at tests/integration/paste_image_spec.lua:154-165 calls parley.paste_image directly with a recording notifier. The complete missing family is no-image Alt+i in Normal mode and Insert mode: neither verifies the builtin one-line error, unchanged buffer/assets, and retained input mode. Add both native cases on the supported versions to fulfill the checked Plan item at the issue''s line 45.'
          family: mode-specific-contract-coverage
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b6c2418d-3b14-4382-a1a6-106fb69c1654
            repository: github.com/xianxu/parley.nvim
            issue_id: "000417"
            recipe: small-diff-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/b5c4c9ae196247fc
            reviewed_head: f405d52460d1cf18c8699a9a98c951f2d0208e47
            slot: parley.nvim:1
            requested_at: "2026-10-23T01:35:18.594725Z"
          phase: finished
          pid: 68567
          started_at: "2026-10-23T01:35:18.696849Z"
          finished_at: "2026-10-23T01:37:41.701141Z"
          session_id: 01a16665-efcd-7771-be0b-d2dab2e20f6b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f405d52460d1cf18c8699a9a98c951f2d0208e47
        tracker_head: c092c40a52ff5bc7f1bf6e0d7dc871b0514a7da0
        branch_point: 6fd47fd82f6aeab218ff8cd0c6c989c6ffb7b412
        since: "2026-10-22T18:01:39-07:00"
        until: "2026-10-22T18:34:42-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T18:01:39-07:00"
              end: "2026-10-22T18:34:42-07:00"
              began: "2026-10-22T18:01:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 3d6f5a18ee8acf342742b61d0d8f3bc9c4588fedbdfec91a31212ed529fc38c8
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 112450861
              windows:
                - start: "2026-10-22T18:01:39-07:00"
                  end: "2026-10-22T18:34:42-07:00"
            - harness: codex
              id: 01a16649-595c-70b2-bd6d-e97dbdcbb200
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 6d87a9d185ef47706aeb28b5d35edac147272b9e913ad46c31c0e9ce2dcae996
              started: "2026-10-23T01:04:05.56Z"
              spawned: true
              bytes: 1319040
              windows:
                - start: "2026-10-23T01:04:05.56Z"
                  end: "2026-10-22T18:34:42-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 3.6366833333333335
        cuts:
            - dispatched: "2026-10-22T18:11:02-07:00"
              finalized: "2026-10-22T18:13:23-07:00"
              finalizing: false
            - dispatched: "2026-10-22T18:26:07-07:00"
              finalized: "2026-10-22T18:28:15-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-22T18:37:43-07:00"
      dispatched: "2026-10-22T18:35:18-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: lua/parley/paste_image.lua:164-168 retains one fixed success notice and logs diagnostic details separately. All twelve image-present native scenarios pass on both supported versions.
          round: 3
        - id: BR-2
          disposition: addressed
          note: tests/integration/paste_image_native_spec.lua:45-95 exercises no-image Alt+i in Normal and Insert modes, checking builtin error text/severity, unchanged buffer/modified state, absent assets, retained mode and subsequent typing. Both pass on Neovim 0.12.5 and 0.11.7. Restoring the old no-image behavior in a disposable archive produces exactly two native failures on each version; the archive was removed.
          round: 3
      recipe: small-diff-review
      isolation: fenced
      reviewed: f405d52460d1cf18c8699a9a98c951f2d0208e47
      blocked: false
---

# Gate ledger — parley.nvim#417 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T18:13:23-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `paste-completion-must-not-block-input` (kind: defect) Shrink diagnostics still make successful image pastes require Enter
  lua/parley/paste_image.lua:164-167 appends an unbounded outcome suffix to the shortened success message. On pinned HEAD, an attached 80×24 UI on Neovim 0.11.7 entered mode "r" after Alt+i in both Normal and Insert modes with either fake_sips returning garbage or no shrink tool available; the attachment and link had already landed. ARCH-PURPOSE: shortening only the no-diagnostic outcome leaves the reported prompt unresolved for other successful pastes. The family has one emission site in this window, fed by all three note-producing paths in image_shrink.lua:240,245,258: conversion-limit refusal, tool/configuration resolution failure, and converter execution/output failure. Preserve diagnostics through a nonblocking presentation and add native UI regression cases for these outcomes. The changed recording-notifier assertions at paste_image_spec.lua:520,535 cannot detect hit-enter; atlas/chat/attachments.md:17-18 also overstates the resulting guarantee.

## Round 2 — 2026-10-22T18:28:15-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — paste_image.lua:164-168 separates diagnostic logging from the fixed success notice. The permanent native tests pass on Neovim 0.12.5 and 0.11.7. Restoring the diagnostic-bearing notice in a disposable archive causes eight native mode assertions to fail on each version, covering every diagnostic producer in both modes. The archive was removed.

### Raised

- **BR-2** [Important] `mode-specific-contract-coverage` (kind: defect) No-image refusal lacks Normal and Insert mapping coverage
  tests/integration/paste_image_native_spec.lua:37-46 exercises only image-present cases. The sole no-image assertion at tests/integration/paste_image_spec.lua:154-165 calls parley.paste_image directly with a recording notifier. The complete missing family is no-image Alt+i in Normal mode and Insert mode: neither verifies the builtin one-line error, unchanged buffer/assets, and retained input mode. Add both native cases on the supported versions to fulfill the checked Plan item at the issue's line 45.

## Round 3 — 2026-10-22T18:37:43-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — lua/parley/paste_image.lua:164-168 retains one fixed success notice and logs diagnostic details separately. All twelve image-present native scenarios pass on both supported versions.
- BR-2 — addressed — tests/integration/paste_image_native_spec.lua:45-95 exercises no-image Alt+i in Normal and Insert modes, checking builtin error text/severity, unchanged buffer/modified state, absent assets, retained mode and subsequent typing. Both pass on Neovim 0.12.5 and 0.11.7. Restoring the old no-image behavior in a disposable archive produces exactly two native failures on each version; the archive was removed.

## Open findings

(none — every finding has been disposed)
