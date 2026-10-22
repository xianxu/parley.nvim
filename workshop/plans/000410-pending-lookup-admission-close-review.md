# Boundary Review — parley.nvim#410 (whole-issue close)

| field | value |
|-------|-------|
| issue | 410 — Bound insert admission across pending registration lookup |
| repo | parley.nvim |
| issue file | workshop/issues/000410-pending-lookup-admission.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6 |
| command | sdlc close --issue 410 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T12:22:23-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared-deadline mechanism and documentation are sound, but pending discovery bypasses confirmed admission when a legacy session-sync controller already exists—the normal setup path for typed session files. This reproduces on both supported runtimes and blocks shipping.

Done-when: current — the existing criteria still cover confirmed first-input protection, shared timing, and safe late-edit reconciliation.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: admission-handoff-covers-existing-controllers
    title: |
      Existing session-sync controllers bypass pending-lookup admission
    detail: |
      lua/parley/session_sync.lua:726 updates an existing controller's identity and returns without consuming input_scope or admitting its insert intent. Production setup at lua/parley/init.lua:3190 attaches session-sync before S1, so typed session files reach this branch. The legacy InsertEnter handler can already have created tokenless protection. Both instances of this family are affected: adoption without observed edits, and adoption with outstanding edits, where acquire_observed skips acquisition because the legacy turn reads as operator. Re-running the parent freshness test with session_sync.attach(0) immediately after the helper's detach reproduced confirmed identity, zero acquire calls, and stale first-character text on Neovim 0.12.5 and 0.11.7; the saved-edit case also reported zero acquisitions. ARCH-PURPOSE: handle both existing and newly created controllers, coordinate legacy InsertEnter ordering, and require confirmed acquisition/freshness or refusal within the original deadline. Add production-order regressions for both edit states; the current helper at tests/integration/session_sync_native_spec.lua:147 masks this path by detaching the controller.
```

1. **Strengths**

   - Residual-budget arithmetic is pure, with expiry and fractional-boundary tests.
   - Couch subtracts spawn time before waiting and avoids spawning after expiry.
   - The existing admission owner retains lock/history ownership; README and atlas explain the new behavior.

2. **Critical findings**

   - The existing-controller handoff above bypasses acquisition and freshness. Fix the handoff and legacy callback ordering together.

3. **Important findings**

   None separately raised.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Preferred-runtime session-sync mapping: all 32 files passed.
   - Both runtimes: 12 new native cases and 25 Couch cases passed.
   - Disposable real/fake Couch conformance and corrupted-fake negative control passed.
   - Production-order probes failed as described above. Tracked files remained unchanged; process census was clean.

6. **Architectural notes**

   - **ARCH-DRY: pass** — existing process and admission owners are reused.
   - **ARCH-PURE: pass** — arithmetic is directly tested; IO remains in adapters.
   - **ARCH-PURPOSE: flag** — the existing-controller consumer does not honor the new admission scope.
   - **ARCH-EVOLVE: pass** — no persisted format changes.
   - Core-concept symbols exist at their documented locations; fixture changes were conditional and unnecessary.

7. **Plan revision recommendations**

   Add a `## Revisions` entry explicitly covering existing-controller adoption, legacy InsertEnter ordering, and native regressions with and without outstanding saved edits. Preserve production attachment order in those tests.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"008812c4-feb7-4fd2-9bf7-47e5b2a1a62a","repository":"github.com/xianxu/parley.nvim","issue_id":"000410","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/eb5b13688580f6b8","reviewed_head":"adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6","slot":"parley.nvim:4","requested_at":"2026-10-22T19:16:34.97545Z"},"phase":"finished","pid":96134,"started_at":"2026-10-22T19:16:35.074286Z","finished_at":"2026-10-22T19:22:16.753209Z","session_id":"01a1650b-338a-7fe3-b6b7-d627a5de240d","outcome":"returned"}] -->
