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

---

## Re-review — 2026-10-14T20:04:57-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 324 — session-sync: a normal-mode edit (dd) doesn't take the operator's lock; only insert-mode edits seem to |
| repo | parley.nvim |
| issue file | workshop/issues/000324-session-sync-a-normal-mode-edit-dd-doesn-t-take-the-operator-s-lock-only-insert-mode-edits-seem-to.md |
| boundary | whole-issue close |
| milestone | — |
| window | dc5ac559cac017645cebce541af8e04625cd7b79..bce3f188c7da771e2a7beac3e499e1ab4dcf7a2c |
| command | sdlc close --issue 324 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-14T20:04:57-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The production fix passes all 97 mapped tests, and all three prior findings are addressed. Two Important gaps remain: new notification assertions repeat the readiness race, and README.md omits the new undo/redo turn behavior. Full-suite and operator confirmation remain pending as recorded in the plan.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      session_sync.lua:526–531 reconciles foreign changes before release. Removing this guard made all five new overwrite, deletion, preservation-failure, and undecided-check regressions fail; pinned head passes them.
  - id: BR-2
    disposition: addressed
    note: |
      session_sync_native_spec.lua:15–20 polls for holder: operator. Delaying sidecar contents reproduced nil-holder failures with the old helper; the corrected helper waits for the contents.
  - id: BR-3
    disposition: addressed
    note: |
      The issue's Done when now explicitly covers acquisition before auto-save, reloads, damaged YAML, undo/redo, save retention, and foreign-change preservation. These criteria match the implementation and mapped tests.
findings:
  - id: new
    severity: Important
    kind: defect
    family: await-complete-observable-state
    title: |
      Native violation assertions still race notification-log contents
    detail: |
      tests/integration/session_sync_native_spec.lua:201–202 waits for sent_file existence and immediately matches its first line. Creating the fake sender's empty log and delaying its append by 100 ms makes all three violation cases fail with nil at line 202. This is the 2nd finding in family await-complete-observable-state. Earlier rounds fixed instances; state and enforce the rule that cross-process assertions await the complete expected payload. Enumeration: sent_file existence-only waits at lines 160, 197, and 201; line 201 serves overwrite, deletion, and unkeepable-overwrite cases. Use one shared notification-readiness helper throughout. ARCH-PURPOSE: sweep the family rather than only the lock helper.
  - id: new
    severity: Important
    kind: defect
    family: document-changed-user-interactions
    title: |
      README update appears missing for clean-undo and redo turn handling
    detail: |
      atlas/modes/session_sync.md:29–32 introduces silent release on clean undo, reacquisition on redo, and save retention, but README.md has no change in the pinned range. The sole affected README entry is its Couch/session-sync paragraph at README.md:48–52. Add a concise explanation of these changed editing interactions, linking to the updated atlas.
```

1. **Strengths**

   - Acquisition runs before immediate auto-save and retains attached identity through damaged frontmatter.
   - The release path reuses `disk_changed` and `violation`, including preservation failures and undecided checks.
   - Real child-Neovim input tests cover all six edit kinds after open, watcher reload, and checktime reload.

2. **Critical findings**

   None.

3. **Important findings**

   The two findings above require complete notification-payload polling and a README update.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make -k test-spec SPEC=modes/session_sync`: 31 native, 52 integration, and 14 unit cases passed.
   - Removing the BR-1 guard produced five expected regression failures.
   - Delayed notification-log contents reproduced three readiness failures.
   - Changed Lua files pass luacheck; range whitespace checks pass.
   - Temporary mutations were restored; the checkout is clean. The full suite and live-editor confirmation were not verified in this review.

6. **Architectural notes**

   - **ARCH-DRY — pass:** existing locking and violation helpers are reused.
   - **ARCH-PURE — pass:** changed entities are correctly classified as integration; no new pure entity requires IO.
   - **ARCH-PURPOSE — flag:** notification waits leave enumerable siblings of the readiness family unresolved.

7. **Plan revision recommendations**

   Add a `## Revisions` entry establishing complete-payload polling for every cross-process readiness assertion, enumerating the three notification waits above. Include the README interaction update in the documentation completion step.
