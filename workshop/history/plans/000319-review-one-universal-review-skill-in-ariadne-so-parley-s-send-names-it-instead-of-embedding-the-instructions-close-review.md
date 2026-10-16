# Boundary Review — parley.nvim#319 (whole-issue close)

| field | value |
|-------|-------|
| issue | 319 — Review: one universal review skill in ariadne, so parley's send names it instead of embedding the instructions |
| repo | parley.nvim |
| issue file | workshop/issues/000319-review-one-universal-review-skill-in-ariadne-so-parley-s-send-names-it-instead-of-embedding-the-instructions.md |
| boundary | whole-issue close |
| milestone | — |
| window | a936c96ce50bc9034e175915f691b0eebc690b33..03cda5a53e5dedef3e5cc1a0518b5bad51501c08 |
| command | sdlc close --issue 319 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T14:59:01-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation matches the approved submitted-only revision: Couch submissions retain S1 ownership, the legacy sender and baseline are removed, and local review consumes the packaged canonical protocol. No blocking defects found. README and atlas updates cover the changed behavior.

```findings
{}
```

1. **Strengths**

   - `lua/parley/review_send.lua:55` preserves S1-first admission and removes the alternate transport.
   - `lua/parley/skills/review/init.lua:498` composes canonical rules, selected inputs, then the local adapter; incomplete packages fail visibly.
   - `scripts/sync-review-protocol.py:106` validates source integrity before writing; fixture tests cover corruption, unsafe paths, stale modes, and read-only checks.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**

   - `make test-spec SPEC=modes/review` passed: 301 tests, clean process census.
   - Python export suite passed: 11 tests.
   - Independently verified packaged member hashes and exact generated `SKILL.md` composition.
   - Pinned-range whitespace check passed; checkout remains unchanged.
   - Full-suite and operator-smoke claims were not independently repeated.

6. **Architectural notes**

   | Principle | Result | Evidence |
   |---|---|---|
   | ARCH-DRY | Pass | Deleted duplicate directive renderer; local consumers use canonical rules. |
   | ARCH-PURE | Pass | Context and snapshot transformations remain pure; filesystem work stays in integration seams. |
   | ARCH-PURPOSE | Pass | Both Couch submission and standalone local review satisfy the revised contract; no legacy builder consumers remain. |
   | ARCH-MOCK | Pass | Submission tests exercise the actual keymap through the existing stateful Couch fake. |
   | ARCH-CONSTRAINTS | Pass | Couch submission removes diff/protocol work and introduces no runtime probes. |
   | ARCH-SECURE | Pass | Export validation rejects malformed records and unsafe paths; package failures surface visibly. |
   | ARCH-ORDER | Pass | S1 retains state ownership; repeated and failed/retried submissions remain submitted-only. |
   | ARCH-FUNERAL | Pass | Editor baseline storage is deleted; snapshots have fixed replacement ownership and fixtures clean up. |

7. **Plan revision recommendations:** None required.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cc4edc40-de56-4f25-9f3d-f67ed44e8bd5","repository":"github.com/xianxu/parley.nvim","issue_id":"000319","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/d0f9514534a344c5","reviewed_head":"03cda5a53e5dedef3e5cc1a0518b5bad51501c08","slot":"parley.nvim:1","requested_at":"2026-10-16T21:57:40.994401Z"},"phase":"finished","pid":72726,"started_at":"2026-10-16T21:57:41.336894Z","finished_at":"2026-10-16T21:59:00.479676Z","session_id":"01a146b8-8ad0-7d31-beaa-9323454f90f2","outcome":"returned"}] -->
