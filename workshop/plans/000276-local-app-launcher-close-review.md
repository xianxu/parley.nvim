# Boundary Review — parley.nvim#276 (whole-issue close)

| field | value |
|-------|-------|
| issue | 276 — Add local app onboarding launcher |
| repo | parley.nvim |
| issue file | workshop/issues/000276-local-app-launcher.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..c17aac9089046c6873c085efc724cb4fb815e402 |
| command | sdlc close --issue 276 |
| reviewer | codex |
| timestamp | 2026-09-25T22:39:33-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The statusline configuration and documentation are well scoped, and the focused tests pass. One launcher boundary violates the promised “outside repo mode” behavior: rejecting this checkout’s descendants does not exclude other marked repositories.

1. **Strengths**
   - The launcher quotes paths correctly; tests exercise spaces, argument forwarding, isolated environment roots, and retained data.
   - Lualine reuses the existing Parley model/activity integration.
   - Actual statusline rendering passed for all 19 packaged theme choices in NORMAL, INSERT, and VISUAL modes.
   - README and atlas updates cover both new surfaces.

2. **Critical findings**
   - **`parley_app:9–14` — outside-checkout does not imply outside repo mode.** The guard accepts a demo directory containing `.parley`, or beneath an ancestor containing `.parley`, provided it is outside this checkout. Production startup then calls `detect_root()` at `lua/parley/starter.lua:171` and enables repo mode. I reproduced both cases through the launcher with a probe invoking the production detector; both launches succeeded and returned a repository root.
     
     **Family enumeration:** a marker in the demo itself or any ancestor, reached through either `PARLEY_DEMO_DIR` or the default cache-derived location. Enforce non-repo startup explicitly or reject all marker-bearing ancestry. Add regression coverage crossing the launcher and production detection boundary, including a successful unmarked alternate profile. **ARCH-PURPOSE** is not yet satisfied.

3. **Important findings:** None beyond the regression coverage required for the critical correction.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Passed: both Python launcher tests, shell syntax validation, diff whitespace checks, and real Lualine/theme compatibility tests.
   - Existing launcher tests observe arguments/environment but never exercise repo detection. Their override case only tests rejection inside this checkout.
   - No prior findings required disposition.

6. **Architectural notes**
   - **ARCH-DRY — pass:** shared starter, theme catalog, and model/activity integration are reused.
   - **ARCH-PURE — pass:** the launcher is thin process glue; statusline changes are declarative configuration.
   - **ARCH-PURPOSE — flag:** the non-repo launch guarantee is only partially enforced.

7. **Plan revision recommendation**
   - Append a `## Revisions` entry recording the marker-ancestry discovery, chosen enforcement mechanism, and regression cases for marked/unmarked default and alternate profiles.

```findings
findings:
  - id: new
    severity: Critical
    family: enforce-non-repo-launch
    title: |
      Launcher accepts demo locations that enable repo mode
    detail: |
      parley_app:9–14 rejects only this checkout's descendants, while lua/parley/starter.lua:171 detects a .parley marker in the accepted cwd or its ancestors. Both cases reproduced through the launcher and production detector. The family covers markers in the demo or any ancestor, for both PARLEY_DEMO_DIR and cache-derived defaults. Explicitly enforce non-repo startup or reject marked ancestry, and add regression tests crossing the launcher/detection boundary plus a successful unmarked override. ARCH-PURPOSE: the promised non-repo app experience is not enforced.
```
