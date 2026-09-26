# Boundary Review — parley.nvim#279 (whole-issue close)

| field | value |
|-------|-------|
| issue | 279 — Reuse running proxy without a local executable during onboarding |
| repo | parley.nvim |
| issue file | workshop/issues/000279-onboarding-running-proxy.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..d4c0563725ce5bb640c940f15388bd0f0ad0e2bb |
| command | sdlc close --issue 279 |
| reviewer | codex |
| timestamp | 2026-09-25T23:55:33-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation satisfies #279’s Spec and Done when clauses. Onboarding now delegates proxy readiness to the lifecycle owner while retaining credential, model, and failure handling. The new regression test demonstrably catches the original bug. No blocking findings.

1. **Strengths**
   - `lua/parley/starter_onboarding.lua:54` reuses `ensure_running`’s existing probe-before-discovery behavior.
   - `tests/integration/cliproxy_lifecycle_spec.lua:247` exercises repeated readiness without an executable, missing models, and removed credentials against a process-level fake.
   - Existing onboarding tests verify that proxy failures still open setup.
   - README and atlas changes document the broader launcher, shortcut, and statusline surfaces in this range.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Pinned scratch snapshot: **183 starter cases, 54 lifecycle cases, and six launcher tests passed**.
   - Restoring the removed executable guard made the new regression fail at `cliproxy_lifecycle_spec.lua:271`.
   - Shell syntax and pinned diff whitespace checks passed.
   - Real-theme statusline compatibility was inspected but not independently rerun. The harness could not perform its process-survivor census because `ps` was unavailable.
   - The working repository remained unchanged.

6. **Architectural notes**
   - **ARCH-DRY — pass:** removes duplicated executable gating; lifecycle policy retains one owner.
   - **ARCH-PURE — pass:** IO remains in existing integration boundaries; no new business logic is embedded in onboarding.
   - **ARCH-PURPOSE — pass:** repeated reuse works without a local executable, while model and availability failures retain setup paths.

7. **Plan revision recommendations:** None.

```findings
{}
```
