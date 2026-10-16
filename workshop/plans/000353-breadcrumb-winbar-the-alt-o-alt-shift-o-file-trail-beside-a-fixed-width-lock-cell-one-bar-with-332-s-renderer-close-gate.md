---
gate: boundary-review
issue: 353
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a06ca659-ff8e-4b07-b086-0ceeb0aa0668
            repository: github.com/xianxu/parley.nvim
            issue_id: "000353"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/a2d870833d0ea36d
            reviewed_head: 38ddd35b4e21b84e3e65a836210bf04508a7ab70
            slot: parley.nvim:2
            requested_at: "2026-10-16T22:20:43.483905Z"
          phase: finished
          pid: 86178
          started_at: "2026-10-16T22:20:43.628485Z"
          finished_at: "2026-10-16T22:24:43.347588Z"
          session_id: 01a146cd-a2b1-7ab2-842f-a24b3edd345b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 38ddd35b4e21b84e3e65a836210bf04508a7ab70
        tracker_head: 2801e703c3e3925fe8a0dc3eea7c60fa95e4c3f3
        branch_point: 800e0d3e0ce074eb79f69c3de246822cfd893cd0
        since: "2026-10-16T09:59:46-07:00"
        until: "2026-10-16T15:20:19-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T09:59:46-07:00"
              end: "2026-10-16T15:20:19-07:00"
              began: "2026-10-16T09:59:46-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: ab18aaa79042a0bcc6a68754f25e5151340fcb4ed817f1176f590234314bf572
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 52266480
              windows:
                - start: "2026-10-16T09:59:46-07:00"
                  end: "2026-10-16T15:20:19-07:00"
            - harness: codex
              id: 01a146a5-88d1-7b70-b972-10b8f28c5a48
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 560e1fb31ddd612358b1698af125e50c5e8e97dc2aadfdb7884ef31527486857
              started: "2026-10-16T21:36:56.857Z"
              spawned: false
              bytes: 555852
              windows:
                - start: "2026-10-16T21:36:56.857Z"
                  end: "2026-10-16T15:20:19-07:00"
            - harness: codex
              id: 01a146a6-e49e-74f2-9a15-f853d20aaa03
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: d1620ebcd8d2533f8e715de0c011dfc9a1212174e8126a8a0a6b6d6145ad8605
              started: "2026-10-16T21:38:25.486Z"
              spawned: false
              bytes: 510623
              windows:
                - start: "2026-10-16T21:38:25.486Z"
                  end: "2026-10-16T15:20:19-07:00"
            - harness: codex
              id: 01a146a8-2fcb-70a1-be84-67e9861da666
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: f51af7da5a4f287a78be0264433e2c085d691a9963b3b9921101500e7bf9cc5f
              started: "2026-10-16T21:39:50.393Z"
              spawned: false
              bytes: 424923
              windows:
                - start: "2026-10-16T21:39:50.393Z"
                  end: "2026-10-16T15:20:19-07:00"
            - harness: codex
              id: 01a146a8-8ea9-7da2-8c99-990e5095f411
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: cb5a08c9740f9f139036c6d4ad9bfda49ca73d9b9a52f92e599a160d6f88fba0
              started: "2026-10-16T21:40:14.818Z"
              spawned: false
              bytes: 430738
              windows:
                - start: "2026-10-16T21:40:14.818Z"
                  end: "2026-10-16T15:20:19-07:00"
            - harness: codex
              id: 01a146a9-49c7-7060-9eef-bfac83c79893
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 35eccd624c7a12bdcbc061910549ce18271986a76a26c3881a33decd76701d80
              started: "2026-10-16T21:41:02.122Z"
              spawned: true
              bytes: 825278
              windows:
                - start: "2026-10-16T21:41:02.122Z"
                  end: "2026-10-16T15:20:19-07:00"
            - harness: codex
              id: 01a146a9-74e1-7b21-a78b-636fc9f4570e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 62bff0f3ae1d28837ab23ad8828be3e9260e8d6a4b24e8a74f41cbc48f8e185f
              started: "2026-10-16T21:41:13.136Z"
              spawned: true
              bytes: 1289224
              windows:
                - start: "2026-10-16T21:41:13.136Z"
                  end: "2026-10-16T15:20:19-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.0931
      "n": 1
      timestamp: "2026-10-16T15:24:44-07:00"
      dispatched: "2026-10-16T15:20:43-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Rendering a plain root crashes and leaves a poisoned ownership record
          detail: lua/parley/document_band.lua:132 retires a newly created record when compose returns no bar, but restore at line 57 dereferences its unset installed field. Calling new(current_buf).render({state="plain", hl="WinBar"}) raises "attempt to index field 'installed'"; subsequent BufWinLeave cleanup raises again. Handle never-installed records safely, or publish ownership only after installation, and add an adapter regression. ARCH-ORDER.
          family: renderer-ownership-state
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Resize repaint overwrites user window-option overrides
          detail: lua/parley/document_band.lua:133-141 replaces the ownership proof and writes both options unconditionally. On an ordinary README→TOOLING trail, setting custom winbar and winhighlight values and firing WinResized replaces both; later cleanup loses the custom bar. Preserve per-option overrides during refresh and test resize followed by cleanup for breadcrumb-only and state-owned views. ARCH-ORDER.
          family: window-option-ownership
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Width fallback drops the immediate parent before trying shortened labels
          detail: lua/parley/breadcrumb_model.lua:140-145 always falls back to root, ellipsis and leaf once the compact trail is too wide. For root→extra-long-middle→verylongparent→leaf with budget 24, it emits "root › … › leaf" although "root › … › very… › leaf" fits in 23 columns. Allocate shortened labels across the protected root and final two segments before dropping the parent, as the rendering plan requires. ARCH-PURPOSE.
          family: protected-breadcrumb-segments
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#353 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T15:24:44-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `renderer-ownership-state` (kind: defect) Rendering a plain root crashes and leaves a poisoned ownership record
  lua/parley/document_band.lua:132 retires a newly created record when compose returns no bar, but restore at line 57 dereferences its unset installed field. Calling new(current_buf).render({state="plain", hl="WinBar"}) raises "attempt to index field 'installed'"; subsequent BufWinLeave cleanup raises again. Handle never-installed records safely, or publish ownership only after installation, and add an adapter regression. ARCH-ORDER.
- **BR-2** [Important] `window-option-ownership` (kind: defect) Resize repaint overwrites user window-option overrides
  lua/parley/document_band.lua:133-141 replaces the ownership proof and writes both options unconditionally. On an ordinary README→TOOLING trail, setting custom winbar and winhighlight values and firing WinResized replaces both; later cleanup loses the custom bar. Preserve per-option overrides during refresh and test resize followed by cleanup for breadcrumb-only and state-owned views. ARCH-ORDER.
- **BR-3** [Important] `protected-breadcrumb-segments` (kind: defect) Width fallback drops the immediate parent before trying shortened labels
  lua/parley/breadcrumb_model.lua:140-145 always falls back to root, ellipsis and leaf once the compact trail is too wide. For root→extra-long-middle→verylongparent→leaf with budget 24, it emits "root › … › leaf" although "root › … › very… › leaf" fits in 23 columns. Allocate shortened labels across the protected root and final two segments before dropping the parent, as the rendering plan requires. ARCH-PURPOSE.

## Open findings

- **BR-1** [Critical] `renderer-ownership-state` (kind: defect) Rendering a plain root crashes and leaves a poisoned ownership record
- **BR-2** [Important] `window-option-ownership` (kind: defect) Resize repaint overwrites user window-option overrides
- **BR-3** [Important] `protected-breadcrumb-segments` (kind: defect) Width fallback drops the immediate parent before trying shortened labels
