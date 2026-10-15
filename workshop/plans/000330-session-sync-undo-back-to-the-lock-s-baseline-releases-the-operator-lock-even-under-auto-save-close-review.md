# Boundary Review — parley.nvim#330 (whole-issue close)

| field | value |
|-------|-------|
| issue | 330 — session-sync: undo back to the lock's baseline releases the operator lock, even under auto-save |
| repo | parley.nvim |
| issue file | workshop/issues/000330-session-sync-undo-back-to-the-lock-s-baseline-releases-the-operator-lock-even-under-auto-save.md |
| boundary | whole-issue close |
| milestone | — |
| window | 874ccbaa9c1693ee56477ec39052765b043ba18b..4d1788796dd9147a790eba2c1f7c1bf5d0fb2199 |
| command | sdlc close --issue 330 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-14T22:22:29-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation delivers baseline-based release under auto-save, and all 109 mapped tests pass. No correctness blocker was found. Update README’s obsolete saved-text description before closing; two minor plan corrections are also noted.

```findings
findings:
  - id: new
    severity: Important
    family: user-docs-match-behavior
    title: |
      README still documents the replaced saved-text release rule
    detail: |
      README.md:54-55 says undo releases when unmodified and redo retakes ownership away from saved text. Under auto-save, saved changed text remains locked, while undo to the acquisition baseline releases even when it initially makes the buffer modified. Both stale clauses are the complete instance family in this window. Update them to match lua/parley/session_sync.lua:531-549 and atlas/modes/session_sync.md; README has no change in the pinned range.
  - id: new
    severity: Minor
    family: core-concept-classification
    title: |
      Both Core concepts rows omit kind and change status
    detail: |
      The issue file's Core concepts table at lines 59-62 lists Lock baseline and Release reconciliation without PURE/INTEGRATION classifications or new/modified/deleted status. These are both instances. Identify their implementing entities, classify the buffer/lock coordination as INTEGRATION, and record status so the required cross-check is explicit.
  - id: new
    severity: Minor
    family: documented-work-bounds
    title: |
      The plan understates the maximum hashes per edit
    detail: |
      The issue's Design notes at line 66 promise at most two SHA-256 hashes per edit. A successful baseline restoration requiring a write hashes at session_sync.lua:508, :531 and :547. This is the sole inaccurate work-bound claim found in the window. Document the three-hash path or reduce it while retaining the post-write content check.
```

1. **Strengths**

   - The baseline captures pre-edit content only after successful lock acquisition and survives saves (`session_sync.lua:507-512`).
   - Release reconciles foreign changes and saves restored baseline text before deleting the lock (`:535-549`).
   - Native tests exercise auto-save enabled and disabled, both reload paths, partial/full undo, redo, explicit saves, unknown locks and preservation failures.

2. **Critical findings:** None.

3. **Important findings:** README’s two obsolete clauses need the correction described above. The atlas update accurately describes the new behavior.

4. **Minor findings:** Complete both concept classifications and correct the hash-count bound.

5. **Test coverage notes**

   Independently ran `make -k test-spec SPEC=modes/session_sync`: 43 native, 52 integration and 14 unit cases passed; no surviving processes. Changed Lua files pass luacheck, and the pinned diff passes whitespace checks. The declared full suite and live operator acceptance were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** Reuses existing attachment, disk classification and violation handling.
   - **ARCH-PURE — pass:** The added coordination stays within the existing buffer/IO boundary; tests use real child-editor ordering and an injected Couch fixture.
   - **ARCH-PURPOSE — pass:** Release follows acquisition content across saves, with the required undo/redo and foreign-change cases covered.

7. **Plan revision recommendations**

   Add `## Revisions` entries recording the concept classifications/statuses and the corrected maximum hash count. Keep the final acceptance/landing checklist item open until those actions occur.
