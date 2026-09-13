# Boundary Review — parley.nvim#246 (whole-issue close)

| field | value |
|-------|-------|
| issue | 246 — Starter config as a product artifact: NVIM_APPNAME=parley, lazy.nvim bootstrap, derived from the operator config without personal data |
| repo | parley.nvim |
| issue file | workshop/issues/000246-starter-config-artifact.md |
| boundary | whole-issue close |
| milestone | — |
| window | a60edc290cac74330f868ea3e2738546c6ddaa64..b668b9b2f2a83657a680112192d9782016e02834 |
| command | sdlc close --issue 246 |
| reviewer | codex |
| timestamp | 2026-09-13T15:44:49-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The starter has strong profile isolation, atomic key publication, and controlled concurrency tests. However, a real two-process reproduction shows that startup overwrites the persisted model selection. The personal-marker guard also omits categories explicitly required by the Spec. Both need correction before closing this boundary.

1. **Strengths**

   - `starter_profile.lua:16` validates the opened inode before reading or changing permissions; complete keys are published without replacing a competing winner.
   - Bootstrap and welcome tests exercise competing processes and abrupt owner death, with explicit recovery rather than automatic lock stealing.
   - Picker and restoration share the live-agent tool-policy projection, preserving the distinction between omitted tools and `{}`.
   - README, atlas, and traceability updates document and map the new starter surface.

2. **Critical findings**

   - **Persisted model selection is overwritten on startup — `lua/parley/starter_config.lua:21`.** The unconditional `default_agent` triggers `init.lua:930` to overwrite the selection after restoration. In separate processes using one temporary profile, I observed `SELECTED=claude-opus-5*`, then `RESTORED=Choose a model`. Subsequent chats therefore revert to the placeholder model. Apply the learner-agent fallback only when no valid selection exists, and add a two-launch regression through `starter.start()`. **ARCH-PURPOSE, ARCH-ORDER.**

3. **Important findings**

   - **Personal-marker enforcement omits promised categories — `scripts/check-starter.py:9`.** The scanner accepts `~/notes`, `~/workspace/ariadne`, and `require("ariadne")`; its current negative fixtures omit these classes too. Extend the guard to cover personal home-relative paths and ariadne imports, with narrowly scoped exceptions for legitimate installation comments. Add negative fixtures for each required category. **ARCH-PURPOSE.**

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Confirmed passing: artifact scanner test, six bootstrap tests, seven runtime startup/recovery tests, and nine client-key tests.
   - The mapped run stopped at two connection-test failures. This sandbox independently rejects loopback binding with `Operation not permitted`; connection acceptance remains unverified here.
   - `git diff --check` passed.
   - Existing restoration tests bypass the full startup sequence and miss the reproduced override.
   - Released-plugin remote-bootstrap acceptance remains explicitly pending in the plan; local-runtime acceptance does not establish it.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared live-agent policy and directory-creation owner.
   - **ARCH-PURE — pass:** configuration decisions are separated from filesystem and UI orchestration.
   - **ARCH-PURPOSE — flag:** persisted selection and promised scanner coverage are incomplete.
   - **ARCH-MOCK — pass structurally:** managed connection tests reuse stateful release/proxy fixtures; execution is limited by sandbox networking.
   - **ARCH-CONSTRAINTS — pass on inspection:** bootstrap deadlines, bounded key reads, and capped welcome discovery are explicit.
   - **ARCH-SECURE — pass:** private key publication, inode validation, and sensitive-log regression coverage.
   - **ARCH-ORDER — flag:** startup’s default-agent override defeats restored selection; initialization ownership otherwise has meaningful interleaving tests.
   - **ARCH-FUNERAL — pass:** normal staging cleanup, interrupted-state recovery, and profile removal are documented.

7. **Plan revision recommendations**

   Append a `## Revisions` entry specifying that the learner agent is a first-use fallback and that restart acceptance must exercise full starter startup. Record the complete personal-marker categories and any narrow exceptions.

```findings
findings:
  - id: new
    severity: Critical
    family: startup-preserves-persisted-selection
    title: |
      Starter startup overwrites the saved live model with the learner placeholder.
    detail: |
      lua/parley/starter_config.lua:21 sets default_agent unconditionally; lua/parley/init.lua:930 applies it after restoring state. Two independent starter launches reproduced SELECTED=claude-opus-5* followed by RESTORED=Choose a model. Make the placeholder a first-use fallback and add a full-startup restart regression (ARCH-PURPOSE, ARCH-ORDER).
  - id: new
    severity: Important
    family: personal-marker-contract-coverage
    title: |
      The artifact guard omits home-relative paths and ariadne imports required by the Spec.
    detail: |
      scripts/check-starter.py:9 accepts ~/notes, ~/workspace/ariadne, and require("ariadne"). Extend enforcement across the promised categories, narrowly exempt legitimate installation comments, and add negative fixtures that fail without the correction (ARCH-PURPOSE).
```
