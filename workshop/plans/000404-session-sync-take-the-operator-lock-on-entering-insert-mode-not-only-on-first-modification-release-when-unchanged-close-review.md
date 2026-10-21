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
