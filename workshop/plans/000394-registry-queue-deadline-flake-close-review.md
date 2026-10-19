# Boundary Review — parley.nvim#394 (whole-issue close)

| field | value |
|-------|-------|
| issue | 394 — Registry queue deadline flake |
| repo | parley.nvim |
| issue file | workshop/issues/000394-registry-queue-deadline-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | e8f76c78941e4ca85064086760564479eb35fecb..73da5e8a628d5ea970a8591ddb41e21f0088529e |
| command | sdlc close --issue 394 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T14:36:44-07:00 |
| verdict | SHIP |

## Review

I'm reviewing the #394 test change against the registry queue code. Next I'll run the spec and the arrival-budget arch check, then do the red check.

Running the registry spec through make; then I'll do the red check.

Green. Now the red check: arm the deadline at admission.

```verdict
verdict: SHIP
confidence: high
```

This change only touches a test, and it does what #394 asked. The flaky case "starts a request's deadline when its child spawns, not when it queues" now stubs `couch.run`, so no child answers until the test says so. The old real-process coverage moved into its own case with a deadline that load can only slow, not break. I checked the diagnosis against `lua/parley/document_registry.lua`. `queued_at` is set when a request is admitted (line 60), `started_at` and the deadline timer are set in `item.start` (lines 104–128), and `finish` returns early when a child answers synchronously (line 121). The stub test relies on all three, and they behave as it assumes. `make test-spec SPEC=modes/session_sync` passes (rc=0, all 12 document-registry cases pass). For the red check, I moved the deadline timer from `item.start` to admission in this disposable checkout. The deterministic case then failed at `document_registry_spec.lua:122`: request 5 came back `unavailable` with "deadline exceeded after 300 ms" and `queued_ms = 301`. I restored the file afterwards and the tree is clean. Nothing blocks SHIP.

1. **Strengths**
   - `tests/integration/document_registry_spec.lua:108-112`: the stub answers request 5 inside the same `couch.run` call that starts it. Its own 300 ms deadline is never armed, so any deadline failure must come from admission. This makes the regression exact rather than dependent on timing.
   - `:118-121`: the test checks `#held == 4` and that `results[5]` is still empty after the 900 ms hold. This proves request 5 really sat in the queue and that `MAX_ACTIVE` held, not just that it eventually answered.
   - `:124-126`: `couch.run` is restored and `client.shutdown()` runs before `assert(ok, err)`, so a failure cannot leak the stub into later cases.
   - `:136-155`: the real-process case uses `arrival.MS` as each request's deadline. The old 0.4 s slack is gone, and the `>= 150` queued bound follows from the fake's 0.2 s sleep.
   - The plan's diagnosis is backed by the recorded failure. `queued_ms=0` with `ran_ms=1000` means request 1 never queued, so leaving registry code unchanged was the right call.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - The comment at `:101` says "a timer never fires early". The same file's comment at `:174-175` says libuv's millisecond-truncated clock can make a correct 300 ms deadline read 299. The argument still holds because the hold is 900 ms against a 300 ms deadline, but the absolute wording is too strong. Something like "never fires materially early" would fix it. This is the only overstated claim in the window.
   - Small style inconsistency: `assert(ok, err)` at `:126`, where the file's other pcall-guarded cases use `assert.is_true(ok, tostring(err))` (`:69`, `:93`).

5. **Test coverage notes**
   - Done-when clause 1 (a deterministic regression catches a deadline started at admission) is met, and the red check confirms the test fails without the fix.
   - Done-when clause 2 (parallel load no longer marks a valid request unavailable) is met by design rather than by a stress run. With a 15 s deadline per request, a 0.2 s child cannot plausibly overrun it. Both cases pass in the suite run.
   - Both `vim.wait` bounds comply with `tests/arch/arrival_budget_spec.lua`: `900` carries a `-- bound:` reason and `2 * arrival.MS` matches the arrival form.

6. **Architectural notes**
   - ARCH-DRY: pass. The stubbed `absent` reply is a one-off fixture and duplicates no helper.
   - ARCH-PURE: pass. The change is test-only, the stub is injected through the module's `couch.run` field, and no logic moved into IO.
   - ARCH-PURPOSE: pass. It delivers both parts of the Spec: the deterministic invariant test, and the real process-boundary coverage kept without the narrow slack. Nothing is deferred.
   - ARCH-EVOLVE: not applicable, because no persisted format changes.
   - Docs: no new user-facing or architectural surface, so no atlas or README update is needed. The `workshop/lessons.md` entry matches the diagnosis.

7. **Plan revision recommendations:** none. The plan matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-overstated-absolute
    title: |
      Comment says "a timer never fires early", but the same file notes libuv truncation can fire a deadline about 1 ms early
    detail: |
      tests/integration/document_registry_spec.lua:101 states an absolute that the file's own comment at :174-175 contradicts (a 300 ms deadline can read 299). The argument still holds because the hold is 3x the deadline; soften to "never fires materially early". This is the only instance in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"40f5ec4c-d13c-49ff-9d2d-30d1b3e6afa2","repository":"github.com/xianxu/parley.nvim","issue_id":"000394","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/d0501a49ec530696","reviewed_head":"73da5e8a628d5ea970a8591ddb41e21f0088529e","slot":"parley.nvim:3","requested_at":"2026-10-19T21:25:12.849315Z"},"phase":"finished","pid":53809,"started_at":"2026-10-19T21:25:13.109118Z","finished_at":"2026-10-19T21:36:44.103265Z","session_id":"e76c35b5-7fe4-47db-b975-4ac9b60f666a","outcome":"returned"}] -->
