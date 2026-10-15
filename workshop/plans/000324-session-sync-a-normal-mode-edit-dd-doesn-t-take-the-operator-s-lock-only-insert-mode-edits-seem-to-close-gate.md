---
gate: boundary-review
issue: 324
id_prefix: BR
rounds:
    - actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4de5e880e7b94de94b0c0916417938a0675c9390
        tracker_head: 31c6a5c2f1f2a59b17f8eb555f8820c42b9f0a8d
        branch_point: dc5ac559cac017645cebce541af8e04625cd7b79
        since: "2026-10-14T16:45:23-07:00"
        until: "2026-10-14T17:02:26-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-14T16:45:23-07:00"
              end: "2026-10-14T17:02:26-07:00"
              began: "2026-10-14T16:45:23-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: fb2e63312282d3ca876963b94e60212ea33dbc84477f5c57a9271a6faeaf7310
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 7563724
              windows:
                - start: "2026-10-14T16:45:23-07:00"
                  end: "2026-10-14T17:02:26-07:00"
      "n": 1
      timestamp: "2026-10-14T17:06:40-07:00"
      dispatched: "2026-10-14T17:03:03-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Clean undo bypasses outstanding foreign-write violation handling
          detail: 'lua/parley/session_sync.lua:522–524 checks whether disk mtime changed since on_lines, but does not establish that the buffer''s saved baseline matches disk. Reproduction: open without auto-save, dd acquires the lock, then write different disk contents and execute normal! u in one child-Neovim request. The scheduled reconciliation deletes the lock; the watcher reloads the foreign contents without preserving .clobbered. The same sequence with a disk deletion leaves the file unrestored. Both probes fail at pinned head; the overwrite probe passes with the base implementation. Family enumeration: the sole new release site at lines 522–524 bypasses both foreign overwrite and foreign deletion handling. Resolve pending foreign changes through the existing disk_changed/violation protocol before permitting release, and add regressions for both cases. ARCH-PURPOSE: the plan promises preservation of existing violation behavior.'
          family: reconcile-foreign-changes-before-release
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: The new lock assertion races the child process's sidecar write
          detail: 'tests/integration/session_sync_native_spec.lua:15–17 waits only for file existence, then immediately reads its holder. The pinned mapped test run failed p after open with nil instead of holder: operator; subsequent runs passed. File creation precedes completion of write_lock''s contents. Family enumeration: this single helper serves acquisition after open/watch/checktime, header edits, undo/redo, multi-step undo, submit/reload, and explicit-save cases. Poll for the complete holder value inside the shared helper.'
          family: await-complete-observable-state
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Done-when omits the newly introduced turn-release contract
          detail: 'workshop/issues/000324-session-sync-a-normal-mode-edit-dd-doesn-t-take-the-operator-s-lock-only-insert-mode-edits-seem-to.md:33 retains only first-edit acquisition and Couch exit 3 despite the expanded Revisions and implementation. Family enumeration: missing acceptance criteria cover acquisition before auto-save, attached identity through damaged YAML, silent clean-undo and multi-step release, redo acquisition, explicit/automatic save retention, and preservation of foreign-write/deletion handling. Add these criteria so completion measures the full revised contract.'
          family: acceptance-criteria-track-contract
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#324 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-14T17:06:40-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `reconcile-foreign-changes-before-release` (kind: defect) Clean undo bypasses outstanding foreign-write violation handling
  lua/parley/session_sync.lua:522–524 checks whether disk mtime changed since on_lines, but does not establish that the buffer's saved baseline matches disk. Reproduction: open without auto-save, dd acquires the lock, then write different disk contents and execute normal! u in one child-Neovim request. The scheduled reconciliation deletes the lock; the watcher reloads the foreign contents without preserving .clobbered. The same sequence with a disk deletion leaves the file unrestored. Both probes fail at pinned head; the overwrite probe passes with the base implementation. Family enumeration: the sole new release site at lines 522–524 bypasses both foreign overwrite and foreign deletion handling. Resolve pending foreign changes through the existing disk_changed/violation protocol before permitting release, and add regressions for both cases. ARCH-PURPOSE: the plan promises preservation of existing violation behavior.
- **BR-2** [Important] `await-complete-observable-state` (kind: defect) The new lock assertion races the child process's sidecar write
  tests/integration/session_sync_native_spec.lua:15–17 waits only for file existence, then immediately reads its holder. The pinned mapped test run failed p after open with nil instead of holder: operator; subsequent runs passed. File creation precedes completion of write_lock's contents. Family enumeration: this single helper serves acquisition after open/watch/checktime, header edits, undo/redo, multi-step undo, submit/reload, and explicit-save cases. Poll for the complete holder value inside the shared helper.
- **BR-3** [Important] `acceptance-criteria-track-contract` (kind: defect) Done-when omits the newly introduced turn-release contract
  workshop/issues/000324-session-sync-a-normal-mode-edit-dd-doesn-t-take-the-operator-s-lock-only-insert-mode-edits-seem-to.md:33 retains only first-edit acquisition and Couch exit 3 despite the expanded Revisions and implementation. Family enumeration: missing acceptance criteria cover acquisition before auto-save, attached identity through damaged YAML, silent clean-undo and multi-step release, redo acquisition, explicit/automatic save retention, and preservation of foreign-write/deletion handling. Add these criteria so completion measures the full revised contract.

## Open findings

- **BR-1** [Critical] `reconcile-foreign-changes-before-release` (kind: defect) Clean undo bypasses outstanding foreign-write violation handling
- **BR-2** [Important] `await-complete-observable-state` (kind: defect) The new lock assertion races the child process's sidecar write
- **BR-3** [Important] `acceptance-criteria-track-contract` (kind: defect) Done-when omits the newly introduced turn-release contract
