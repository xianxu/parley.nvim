# Boundary Review — parley.nvim#324 (whole-issue close)

| field | value |
|-------|-------|
| issue | 324 — session-sync: a normal-mode edit (dd) doesn't take the operator's lock; only insert-mode edits seem to |
| repo | parley.nvim |
| issue file | workshop/issues/000324-session-sync-a-normal-mode-edit-dd-doesn-t-take-the-operator-s-lock-only-insert-mode-edits-seem-to.md |
| boundary | whole-issue close |
| milestone | — |
| window | dc5ac559cac017645cebce541af8e04625cd7b79..4de5e880e7b94de94b0c0916417938a0675c9390 |
| command | sdlc close --issue 324 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-14T17:06:39-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Acquisition before auto-save and callback reattachment work, with meaningful real-input regression coverage. However, clean undo can release the lock before an outstanding foreign write or deletion is handled, bypassing the existing preservation protocol. The new tests also contain an observed readiness race, and Done-when needs to cover the expanded contract.

Done-when: stale — it covers first-edit acquisition and agent refusal, but omits clean release, redo acquisition, attached identity, and save retention.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: reconcile-foreign-changes-before-release
    title: |
      Clean undo bypasses outstanding foreign-write violation handling
    detail: |
      lua/parley/session_sync.lua:522–524 checks whether disk mtime changed since on_lines, but does not establish that the buffer's saved baseline matches disk. Reproduction: open without auto-save, dd acquires the lock, then write different disk contents and execute normal! u in one child-Neovim request. The scheduled reconciliation deletes the lock; the watcher reloads the foreign contents without preserving .clobbered. The same sequence with a disk deletion leaves the file unrestored. Both probes fail at pinned head; the overwrite probe passes with the base implementation. Family enumeration: the sole new release site at lines 522–524 bypasses both foreign overwrite and foreign deletion handling. Resolve pending foreign changes through the existing disk_changed/violation protocol before permitting release, and add regressions for both cases. ARCH-PURPOSE: the plan promises preservation of existing violation behavior.
  - id: new
    severity: Important
    kind: defect
    family: await-complete-observable-state
    title: |
      The new lock assertion races the child process's sidecar write
    detail: |
      tests/integration/session_sync_native_spec.lua:15–17 waits only for file existence, then immediately reads its holder. The pinned mapped test run failed p after open with nil instead of holder: operator; subsequent runs passed. File creation precedes completion of write_lock's contents. Family enumeration: this single helper serves acquisition after open/watch/checktime, header edits, undo/redo, multi-step undo, submit/reload, and explicit-save cases. Poll for the complete holder value inside the shared helper.
  - id: new
    severity: Important
    kind: defect
    family: acceptance-criteria-track-contract
    title: |
      Done-when omits the newly introduced turn-release contract
    detail: |
      workshop/issues/000324-session-sync-a-normal-mode-edit-dd-doesn-t-take-the-operator-s-lock-only-insert-mode-edits-seem-to.md:33 retains only first-edit acquisition and Couch exit 3 despite the expanded Revisions and implementation. Family enumeration: missing acceptance criteria cover acquisition before auto-save, attached identity through damaged YAML, silent clean-undo and multi-step release, redo acquisition, explicit/automatic save retention, and preservation of foreign-write/deletion handling. Add these criteria so completion measures the full revised contract.
```

1. **Strengths**

   - Real child-Neovim input reproduces the relevant auto-save ordering.
   - Reload coverage includes watcher reload, `:checktime`, and submit followed by reload.
   - Idempotent reattachment reuses the existing lifecycle, and atlas traceability includes the new tests.

2. **Critical findings**

   - The release guard at `lua/parley/session_sync.lua:522` needs foreign-change reconciliation before deleting the lock. Cover overwrite and deletion together.

3. **Important findings**

   - Wait for complete lock contents in the shared test helper.
   - Expand issue #324’s Done-when to match its revised behavior.

4. **Minor findings**

   - None.

5. **Test coverage notes**

   - Pinned mapped run: 25/26 native cases, 52/52 existing integration cases, and 14/14 unit cases passed; process census was clean.
   - In a disposable checkout, replacing the implementation with base code made 22 native regressions fail, confirming meaningful regression coverage.
   - Head passed all 26 existing native cases in later runs; both added foreign-change probes failed.
   - `git diff --check` passed. Full-suite and live-editor verification remain pending. Disposable checkout removed; tracked files unchanged.

6. **Architectural notes**

   - **ARCH-DRY: pass.** Existing lock, refresh, timer, and violation helpers are reused.
   - **ARCH-PURE: pass.** Native callbacks are integration glue; no new entity falsely claims purity. The Core concepts table describes invariants rather than the requested kind/path/status mapping.
   - **ARCH-PURPOSE: flag.** Clean release undermines the explicitly retained violation contract.
   - Atlas updates are present. No new command, flag, keybinding, or configuration key requires a README update.

7. **Plan revision recommendations**

   - Add a `## Revisions` entry requiring foreign overwrite/deletion reconciliation before clean release, with both regression cases.
   - Refresh Done-when with the enumerated revised behaviors.
   - Add kind/path/status columns identifying `M.attach` as modified INTEGRATION code.
