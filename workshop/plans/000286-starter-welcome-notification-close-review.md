# Boundary Review — parley.nvim#286 (whole-issue close)

| field | value |
|-------|-------|
| issue | 286 — remove redundant starter welcome notification |
| repo | parley.nvim |
| issue file | workshop/issues/000286-starter-welcome-notification.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..f77163e9b3dbd997c3c4a66041a7f6ba9b72e347 |
| command | sdlc close --issue 286 |
| reviewer | codex |
| timestamp | 2026-09-26T20:25:07-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: medium
```

The welcome-notification removal matches #286, and its startup regression passed. Inspection found no concrete correctness defect in the stacked response and branching changes. SHIP remains blocked by incomplete verification and a README omission for the changed shortcut.

1. **Strengths**
   - `starter.lua:185` preserves welcome loading and onboarding while removing the duplicate notification.
   - `starter_project_spec.lua:29` checks both welcome-buffer opening and notification absence.
   - Response refresh rejects duplicates before deleting output and protects pending snapshots with ownership.
   - Launcher tests exercise competing launch/reset operations deterministically; all eight passed.

2. **Critical findings**

   None established.

3. **Important findings**
   - **README shortcut documentation:** `config.lua:414–419` replaces Option+p pruning with private-note insertion and introduces `chat_shortcut_private_note`. README’s shortcut documentation omits this change. Document Option+p, its Normal/Insert modes, and Ctrl+g b as the remaining prune binding.

4. **Minor findings**

   None.

5. **Test coverage notes**
   - Launcher: **8 passed**.
   - Starter: **182 passed, 1 failed**. The concurrent welcome-creator case failed at `starter_config_spec.lua:167` with “Welcome initialization requires repair.”
   - Keybindings: **241 passed, 0 failed**.
   - Both Make verification commands exited nonzero; their required process census could not run because `ps` was unavailable. Rerun in an environment supporting that check and investigate the starter failure. This review does not establish that failure as introduced by this diff.

6. **Architectural notes**
   - **ARCH-DRY — pass:** registry-derived aliases and shared branch formatting.
   - **ARCH-PURE — pass:** formatting remains separate from editor integration.
   - **ARCH-PURPOSE — pass:** #286’s behavior and regression are delivered.
   - **ARCH-MOCK — pass:** controlled launcher doubles exercise actual production entry points.
   - **ARCH-CONSTRAINTS — pass:** no new unbounded fan-out identified.
   - **ARCH-SECURE — pass:** launcher validates profile ownership and rejects unsafe roots.
   - **ARCH-ORDER — pass on inspection:** duplicate admission and snapshot ownership have sequence coverage.
   - **ARCH-FUNERAL — pass:** pending snapshots have terminal cleanup; demo storage has an explicit reset path.

   The issue’s three Core concepts entries match the changed integration APIs.

7. **Plan revision recommendations**

   No design revision required. Record the verification failure and subsequent rerun evidence in the issue log.

```findings
findings:
  - id: new
    severity: Important
    family: user-facing-shortcut-documentation
    title: |
      README omits the Option+p reassignment and private-note configuration
    detail: |
      lua/parley/config.lua:414–419 reassigns Option+p from prune to private-note insertion and adds chat_shortcut_private_note. Update README.md's shortcut guidance to describe the new Normal/Insert behavior and Ctrl+g b for pruning.
  - id: new
    severity: Important
    family: boundary-verification-evidence
    title: |
      Boundary verification did not complete successfully
    detail: |
      make test-spec SPEC=infra/starter produced 182 passes and one failure at tests/integration/starter_config_spec.lua:167. Both starter and keybinding commands also could not perform the required process census because ps was unavailable. Rerun with process inspection available and resolve or establish the cause of the starter failure before claiming successful verification.
```
