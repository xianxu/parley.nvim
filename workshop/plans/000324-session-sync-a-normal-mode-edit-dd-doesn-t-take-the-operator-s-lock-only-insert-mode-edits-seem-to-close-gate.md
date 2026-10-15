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
    - actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: bce3f188c7da771e2a7beac3e499e1ab4dcf7a2c
        tracker_head: 31c6a5c2f1f2a59b17f8eb555f8820c42b9f0a8d
        branch_point: dc5ac559cac017645cebce541af8e04625cd7b79
        since: "2026-10-14T16:45:23-07:00"
        until: "2026-10-14T20:00:23-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-14T16:45:23-07:00"
              end: "2026-10-14T20:00:23-07:00"
              began: "2026-10-14T16:45:23-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 7ce43b42ebe01aaec8adf85003ae5f60bd6c2199827a6899e387c0c91b10be7c
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 8273686
              windows:
                - start: "2026-10-14T16:45:23-07:00"
                  end: "2026-10-14T20:00:23-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.03128333333333334
        cuts:
            - dispatched: "2026-10-14T17:03:03-07:00"
              finalized: "2026-10-14T17:06:40-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-14T20:04:57-07:00"
      dispatched: "2026-10-14T20:00:58-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: session_sync.lua:526–531 reconciles foreign changes before release. Removing this guard made all five new overwrite, deletion, preservation-failure, and undecided-check regressions fail; pinned head passes them.
          round: 2
        - id: BR-2
          disposition: addressed
          note: 'session_sync_native_spec.lua:15–20 polls for holder: operator. Delaying sidecar contents reproduced nil-holder failures with the old helper; the corrected helper waits for the contents.'
          round: 2
        - id: BR-3
          disposition: addressed
          note: The issue's Done when now explicitly covers acquisition before auto-save, reloads, damaged YAML, undo/redo, save retention, and foreign-change preservation. These criteria match the implementation and mapped tests.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Important
          title: Native violation assertions still race notification-log contents
          detail: 'tests/integration/session_sync_native_spec.lua:201–202 waits for sent_file existence and immediately matches its first line. Creating the fake sender''s empty log and delaying its append by 100 ms makes all three violation cases fail with nil at line 202. This is the 2nd finding in family await-complete-observable-state. Earlier rounds fixed instances; state and enforce the rule that cross-process assertions await the complete expected payload. Enumeration: sent_file existence-only waits at lines 160, 197, and 201; line 201 serves overwrite, deletion, and unkeepable-overwrite cases. Use one shared notification-readiness helper throughout. ARCH-PURPOSE: sweep the family rather than only the lock helper.'
          family: await-complete-observable-state
          round: 2
        - kind: defect
          id: BR-5
          severity: Important
          title: README update appears missing for clean-undo and redo turn handling
          detail: atlas/modes/session_sync.md:29–32 introduces silent release on clean undo, reacquisition on redo, and save retention, but README.md has no change in the pinned range. The sole affected README entry is its Couch/session-sync paragraph at README.md:48–52. Add a concise explanation of these changed editing interactions, linking to the updated atlas.
          family: document-changed-user-interactions
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 1297e8d4ce147ffc6d477eed499d210353c35d8c
        tracker_head: 31c6a5c2f1f2a59b17f8eb555f8820c42b9f0a8d
        branch_point: dc5ac559cac017645cebce541af8e04625cd7b79
        since: "2026-10-14T16:45:23-07:00"
        until: "2026-10-14T20:07:39-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-14T16:45:23-07:00"
              end: "2026-10-14T20:07:39-07:00"
              began: "2026-10-14T16:45:23-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: bfb6af84bc2c090b93446a6ebb07715f998cc9d8004e775a614575f8a6e6b773
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 8655967
              windows:
                - start: "2026-10-14T16:45:23-07:00"
                  end: "2026-10-14T20:07:39-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.03128333333333334
        cuts:
            - dispatched: "2026-10-14T17:03:03-07:00"
              finalized: "2026-10-14T17:06:40-07:00"
              finalizing: false
            - dispatched: "2026-10-14T20:00:58-07:00"
              finalized: "2026-10-14T20:04:57-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-14T20:15:41-07:00"
      dispatched: "2026-10-14T20:08:23-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: The clean-release guard still reconciles foreign changes before release; all five preservation and undecided-check regressions pass.
          round: 3
        - id: BR-2
          disposition: addressed
          note: The shared lock helper awaits holder contents rather than path existence; native acquisition tests pass.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Done when explicitly covers acquisition, reloads, damaged YAML, undo/redo, save retention, and foreign-change preservation.
          round: 3
        - id: BR-4
          disposition: addressed
          note: session_sync_native_spec.lua:17–35 shares complete-payload readiness across notifications and file assertions. Restoring existence-only notification waits in a disposable checkout made all three foreign-change notification cases fail; pinned head passes.
          round: 3
        - id: BR-5
          disposition: addressed
          note: README.md:53–56 now documents silent undo release, redo acquisition, and save retention, linking to atlas/modes/session_sync.md:29–32 and 43–50.
          round: 3
      recipe: small-diff-review
      isolation: fenced
      reviewed: 1297e8d4ce147ffc6d477eed499d210353c35d8c
      blocked: false
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

## Round 2 — 2026-10-14T20:04:57-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — session_sync.lua:526–531 reconciles foreign changes before release. Removing this guard made all five new overwrite, deletion, preservation-failure, and undecided-check regressions fail; pinned head passes them.
- BR-2 — addressed — session_sync_native_spec.lua:15–20 polls for holder: operator. Delaying sidecar contents reproduced nil-holder failures with the old helper; the corrected helper waits for the contents.
- BR-3 — addressed — The issue's Done when now explicitly covers acquisition before auto-save, reloads, damaged YAML, undo/redo, save retention, and foreign-change preservation. These criteria match the implementation and mapped tests.

### Raised

- **BR-4** [Important] `await-complete-observable-state` (kind: defect) Native violation assertions still race notification-log contents
  tests/integration/session_sync_native_spec.lua:201–202 waits for sent_file existence and immediately matches its first line. Creating the fake sender's empty log and delaying its append by 100 ms makes all three violation cases fail with nil at line 202. This is the 2nd finding in family await-complete-observable-state. Earlier rounds fixed instances; state and enforce the rule that cross-process assertions await the complete expected payload. Enumeration: sent_file existence-only waits at lines 160, 197, and 201; line 201 serves overwrite, deletion, and unkeepable-overwrite cases. Use one shared notification-readiness helper throughout. ARCH-PURPOSE: sweep the family rather than only the lock helper.
- **BR-5** [Important] `document-changed-user-interactions` (kind: defect) README update appears missing for clean-undo and redo turn handling
  atlas/modes/session_sync.md:29–32 introduces silent release on clean undo, reacquisition on redo, and save retention, but README.md has no change in the pinned range. The sole affected README entry is its Couch/session-sync paragraph at README.md:48–52. Add a concise explanation of these changed editing interactions, linking to the updated atlas.

## Round 3 — 2026-10-14T20:15:41-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — The clean-release guard still reconciles foreign changes before release; all five preservation and undecided-check regressions pass.
- BR-2 — addressed — The shared lock helper awaits holder contents rather than path existence; native acquisition tests pass.
- BR-3 — addressed — Done when explicitly covers acquisition, reloads, damaged YAML, undo/redo, save retention, and foreign-change preservation.
- BR-4 — addressed — session_sync_native_spec.lua:17–35 shares complete-payload readiness across notifications and file assertions. Restoring existence-only notification waits in a disposable checkout made all three foreign-change notification cases fail; pinned head passes.
- BR-5 — addressed — README.md:53–56 now documents silent undo release, redo acquisition, and save retention, linking to atlas/modes/session_sync.md:29–32 and 43–50.

## Open findings

(none — every finding has been disposed)
