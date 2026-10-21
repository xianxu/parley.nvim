# Boundary Review — parley.nvim#404 (whole-issue close)

| field | value |
|-------|-------|
| issue | 404 — session-sync: take the operator lock on entering insert mode, not only on first modification; release when unchanged |
| repo | parley.nvim |
| issue file | workshop/issues/000404-session-sync-take-the-operator-lock-on-entering-insert-mode-not-only-on-first-modification-release-when-unchanged.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0fdc27987dd8174c82f7486b9ec8620c87cb5b83..6f837cf5c11ed37ae18b8940245ee2a7c1f10d20 |
| command | sdlc close --issue 404 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-21T08:59:29-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared acquisition path, baseline ownership checks, documentation, and existing tests are sound. One native exit path blocks shipping: Ctrl-C leaves insert protection permanently active, preventing unchanged release and subsequent full-undo release.

Done-when: current — it covers the revised entry/exit contract, baseline retention, and safety cases; the implementation misses an exit case.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: insert-intent-must-follow-mode
    title: |
      Ctrl-C exit strands the operator lock and disables baseline release
    detail: |
      lua/parley/session_sync.lua:609 clears s.inserting only on InsertLeave, which Neovim skips for Ctrl-C. On pinned head with Neovim 0.11.7, native i<C-c> leaves mode n with unchanged content and the lock present; release_if_baseline returns false because of the new guard at line 838. Native iX<C-c>u likewise restores baseline content without releasing. Reproduced both scenarios for registered session files and side docs, with auto-save off and on (eight combinations). The family includes both acquisition entry points—InsertEnter at line 608 and late attachment at line 740—and both release paths: unchanged exit and subsequent baseline undo. Track actual mode departure, including exits that skip InsertLeave, while preserving deferred reconciliation and ownership/epoch guards. Add native regression cases for this matrix. ARCH-PURPOSE: the current implementation leaves the forgotten-turn problem unresolved for this exit.
```

### 1. Strengths

- `take_turn` shares acquisition and deferred disk-race reconciliation between insert entry and edits.
- Baseline release still checks owned lock bytes, protecting pre-existing and replaced locks.
- Native tests exercise actual input ordering, auto-save, late attachment, and foreign writes.
- README and atlas updates cover the changed user behavior.

### 2. Critical findings

One: the Ctrl-C lifecycle defect above, at `lua/parley/session_sync.lua:609`, interacting with line 838.

### 3. Important findings

None.

### 4. Minor findings

None.

### 5. Test coverage notes

- `make test-spec SPEC=modes/session_sync` passed, including 85 native, 71 buffer, and 18 session-sync unit cases.
- The mapped run completed with no surviving test processes.
- Independent native probes exposed the eight failing combinations above; existing tests cover Escape but miss Ctrl-C.
- Range diff-check passed; tracked checkout remained unchanged.

### 6. Architectural notes

- **ARCH-DRY: pass** — shared acquisition avoids duplicated lock/race logic.
- **ARCH-PURE: pass** — changes stay within the existing editor/IO boundary.
- **ARCH-PURPOSE: flag** — insert intent outlives the actual mode after Ctrl-C.
- **ARCH-EVOLVE: pass** — no persisted format changes.

### 7. Plan revision recommendations

Add a `## Revisions` entry requiring insert-state cleanup for exits that skip `InsertLeave`, with native unchanged-exit and subsequent-full-undo regressions across parent/side docs and auto-save on/off. Preserve deferred reconciliation and foreign-lock safety.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d733bcbf-bfe1-44ab-87f1-c961a6b49e2f","repository":"github.com/xianxu/parley.nvim","issue_id":"000404","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/b87dea22024c53c7","reviewed_head":"6f837cf5c11ed37ae18b8940245ee2a7c1f10d20","slot":"parley.nvim:1","requested_at":"2026-10-21T15:53:59.385215Z"},"phase":"finished","pid":54459,"started_at":"2026-10-21T15:53:59.490842Z","finished_at":"2026-10-21T15:59:29.096538Z","session_id":"01a15f2b-5cce-7df3-998f-71ff6010df13","outcome":"returned"}] -->

---

## Re-review — 2026-10-21T09:16:09-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 404 — session-sync: take the operator lock on entering insert mode, not only on first modification; release when unchanged |
| repo | parley.nvim |
| issue file | workshop/issues/000404-session-sync-take-the-operator-lock-on-entering-insert-mode-not-only-on-first-modification-release-when-unchanged.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0fdc27987dd8174c82f7486b9ec8620c87cb5b83..27c43e6abd779c5416890256793e33524c379bb5 |
| command | sdlc close --issue 404 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-21T09:16:09-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The Ctrl-C defect is fixed with meaningful regression coverage, and the mapped suite passes. One related correctness gap blocks shipping: replaying persisted move finalization can remove the operator lock during a new, unchanged insert intent.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The shared ModeChanged/InsertLeave handler fixes actual departure. All 16 native Ctrl-C combinations pass on head; loading the pre-fix module makes all 16 fail. The additional move-intent regression also fails without the fix.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: insert-intent-must-follow-mode
    title: |
      Replayed move finalization removes protection during live insert intent
    detail: |
      lua/parley/session_sync.lua:1121 checks insert intent when creating a snapshot, but prepare_move_finalization at lines 1142-1160 does not recheck it before deleting NEW's lock. Reproduced on pinned head with Neovim 0.11.7: capture an unchanged release snapshot outside insert, retain its protection-stage intent, detach, enter native insert mode, restore_move with that intent, then prepare_move_finalization and retire_move. Before replay: mode=i, destination lock present. After replay: success=true, mode=i, destination lock absent. Production recovery reaches this path through lua/parley/agentic_document.lua:878. This is the 2nd finding in family insert-intent-must-follow-mode. Earlier rounds fixed instances; state and enforce the rule that persisted automatic-release permission cannot override current insert intent. The complete automatic-release enumeration is release_if_baseline (guarded), move_finalization_snapshot (guarded), and persisted cleanup through prepare_move_finalization (unguarded), including restore_move recovery. Apply the shared policy at the destructive boundary and add native recovery regressions, including interrupted cleanup, while preserving journal replay and ownership checks. ARCH-PURPOSE.
```

**1. Strengths**

- Shared `take_turn` preserves acquisition and deferred disk-race handling.
- Ownership checks preserve pre-existing and replaced locks.
- Native regressions cover parent/side documents, early/late attachment, auto-save on/off, and unchanged/full-undo Ctrl-C exits.
- README and atlas updates cover the changed behavior.

**2. Critical findings**

One, detailed above: finalization replay bypasses current insert eligibility. Revalidate before destructive cleanup and keep recovery safe when cleanup has partially completed.

**3. Important findings**

None.

**4. Minor findings**

None.

**5. Test coverage notes**

- `make test-spec SPEC=modes/session_sync` passed, including 102 native, 71 buffer, and 18 session-sync unit cases.
- Negative control using the pre-fix module produced 17 failures: all 16 Ctrl-C cases plus move-intent preservation.
- Independent native replay probe reproduced the new finding.
- Range diff-check passed; tracked files remained unchanged; no test processes survived.

**6. Architectural notes**

- **ARCH-DRY: pass** — shared acquisition and release eligibility helpers.
- **ARCH-PURE: pass** — changes remain within the existing editor/IO boundary.
- **ARCH-PURPOSE: flag** — live intent protection is incomplete during persisted finalization replay.
- **ARCH-EVOLVE: pass** — no persisted format changes.
- No Core concepts table requires cross-checking.

**7. Plan revision recommendations**

Add a `## Revisions` entry requiring current insert eligibility at every automatic lock-removal boundary, including persisted move recovery and interrupted cleanup. Require native regressions for replay with and without live insert intent before marking that clause complete.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b3c2581e-3ee8-4c00-8b76-9c37643865f1","repository":"github.com/xianxu/parley.nvim","issue_id":"000404","recipe":"small-diff-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/c4011392ea6befbc","reviewed_head":"27c43e6abd779c5416890256793e33524c379bb5","slot":"parley.nvim:1","requested_at":"2026-10-21T16:11:13.956803Z"},"phase":"finished","pid":73591,"started_at":"2026-10-21T16:11:14.13063Z","finished_at":"2026-10-21T16:16:09.216848Z","session_id":"01a15f3b-26c9-7df1-ad4d-b561bdc21f99","outcome":"returned"}] -->

---

## Re-review — 2026-10-21T10:41:06-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 404 — session-sync: take the operator lock on entering insert mode, not only on first modification; release when unchanged |
| repo | parley.nvim |
| issue file | workshop/issues/000404-session-sync-take-the-operator-lock-on-entering-insert-mode-not-only-on-first-modification-release-when-unchanged.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0fdc27987dd8174c82f7486b9ec8620c87cb5b83..f808cfd7000fe927812ce1c54a33a91b0fcd9b5e |
| command | sdlc close --issue 404 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-21T10:41:06-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation matches the revised Spec and Plan. BR-2 is verified addressed: recovery admission and cleanup recheck current insert intent while preserving ownership proofs and interrupted replay. No new findings.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      session_sync.lua:987 and :1154 guard recovery admission and destructive cleanup. Native regressions at session_sync_native_spec.lua:698 cover all three cleanup points, insert entry before/after restore, and outside-insert convergence. Removing the fix in a disposable checkout produced six expected failures and 105 passes; pinned-head native tests pass all 111 cases on Neovim 0.12.5 and 0.11.7.
```

1. **Strengths**

   - Shared `take_turn` acquisition preserves baseline and disk-race handling (`lua/parley/session_sync.lua:588`).
   - One departure handler covers Escape and Ctrl-C with deferred reconciliation (`:610`).
   - Replay tests verify unchanged lock bytes on refusal and successful convergence afterward.
   - README and atlas describe the changed lifecycle and recovery action.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**

   - `make test-spec SPEC=modes/session_sync` passed, including 111 native, 71 buffer, and 18 session-sync unit cases.
   - Native tests also passed on installed Neovim 0.11.7.
   - Mutation verification confirmed six regressions fail without the replay fix.
   - Diff-check passed; tracked checkout remained clean. Disposable checkout removed.

6. **Architectural notes**

   - **ARCH-DRY: pass** — shared acquisition and insert-intent policy.
   - **ARCH-PURE: pass** — changes stay within the existing editor/IO boundary.
   - **ARCH-PURPOSE: pass** — inspected baseline release, snapshot creation, recovery admission, and protection/retire cleanup. Legacy move completion removes OLD while retaining NEW; explicit submit remains the intended exception.
   - **ARCH-EVOLVE: pass** — no persisted format changes.

7. **Plan revisions:** None needed. Existing revisions describe the delivered behavior; no Core concepts table requires cross-checking.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"3dbdcc1d-8199-4c46-b9bd-33e755720d07","repository":"github.com/xianxu/parley.nvim","issue_id":"000404","recipe":"small-diff-review","round":3,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/a4c52a1a81e0f353","reviewed_head":"f808cfd7000fe927812ce1c54a33a91b0fcd9b5e","slot":"parley.nvim:1","requested_at":"2026-10-21T17:37:53.450932Z"},"phase":"finished","pid":42585,"started_at":"2026-10-21T17:37:53.631491Z","finished_at":"2026-10-21T17:41:06.574521Z","session_id":"01a15f8a-7da1-7e83-a190-5ee9cf87d27d","outcome":"returned"}] -->
