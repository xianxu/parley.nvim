# Boundary Review — parley.nvim#249 (whole-issue close)

| field | value |
|-------|-------|
| issue | 249 — Fix chat finder delete key collision |
| repo | parley.nvim |
| issue file | workshop/issues/000249-finder-delete-key.md |
| boundary | whole-issue close |
| milestone | — |
| window | c90d2f953d6b6c3d3b91f7a6b13368ea5c61b9ed..54bfa80d6a2df8b0352d83d5cf8f2f38cbbb86b1 |
| command | sdlc close --issue 249 |
| reviewer | codex |
| timestamp | 2026-09-14T09:20:42-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fulfills #249: Ctrl+d retains single-chat deletion, and tree deletion moves to the distinct `<C-g>D` chord in both default sources. Confirmation behavior and custom override resolution remain intact. No blocking findings.

1. **Strengths**
   - Minimal production change; existing deletion and picker lifecycle logic is reused.
   - Six regression cases inspect effective Neovim mappings and verify confirmation targets, cancellation, child preservation, and picker resume.
   - README documents both deletion shortcuts.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Independently passed: 54 finder tests, 70 keybinding tests.
   - Lint passed: 447 files, zero warnings or errors.
   - The initial `chat/finder` test recipe had no mapping; both focused files were subsequently run directly.
   - Full-suite and pre-fix failure claims were not independently rerun.

6. **Architecture**
   - **ARCH-DRY — pass:** Both existing default sources agree; no duplicated implementation added.
   - **ARCH-PURE — pass:** Binding data changes only; effects stay in existing handlers.
   - **ARCH-PURPOSE — pass:** Both configured defaults and registry fallback receive the correction.
   - **ARCH-MOCK — pass:** Tests use temporary files, real picker mappings, and controlled confirmation.
   - **ARCH-CONSTRAINTS — pass:** No additional per-keystroke work.
   - **ARCH-SECURE — pass:** No new trust boundary; deletion tests target temporary chats.
   - **ARCH-ORDER — pass:** Existing confirmation/suspend/resume sequencing remains unchanged.
   - **ARCH-FUNERAL — pass:** No new durable runtime artifacts.
   
   README covers the changed user surface. No new architectural surface requires an atlas update.

7. **Plan revision recommendations:** None.

```findings
{}
```

---

## Re-review — 2026-09-14T09:33:07-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 249 — Fix chat finder delete key collision |
| repo | parley.nvim |
| issue file | workshop/issues/000249-finder-delete-key.md |
| boundary | whole-issue close |
| milestone | — |
| window | c90d2f953d6b6c3d3b91f7a6b13368ea5c61b9ed..5880aff1161064498fb36a2d9fd09d058710def4 |
| command | sdlc close --issue 249 |
| reviewer | codex |
| timestamp | 2026-09-14T09:33:07-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fulfills #249, including the documented starter-profile revision. Single-chat and tree deletion now have distinct defaults, and the starter retains finder-local controls. No blocking findings.

1. **Strengths**

   - Both default sources consistently use `<C-g>D` for tree deletion.
   - Nine regression cases inspect effective Neovim mappings across config defaults, registry fallback, and starter setup; they verify confirmation targets, cancellation, child preservation, and finder resume.
   - Starter policy reuses registry scopes to preserve chat, note, and issue finder controls.
   - README, starter documentation, and atlas reflect the changed behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   Independently passed: 57 finder tests, 5 starter-policy tests, and 70 keybinding tests. Lint passed with zero warnings/errors across 447 files. The initial keybinding test invocation used an incorrect filename; the corrected invocation passed. Full-suite, native-launcher, and pre-fix failure claims were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** Reuses registry metadata and existing deletion handlers.
   - **ARCH-PURE — pass:** Starter policy remains a deterministic configuration projection; UI effects stay in existing handlers.
   - **ARCH-PURPOSE — pass:** Covers both default sources and all three documented finder families.
   - **ARCH-MOCK — pass:** Integration coverage uses temporary files, real picker mappings, and controlled discovery/confirmation seams.
   - **ARCH-CONSTRAINTS — pass:** Adds only setup-time filtering; no new per-keystroke work.
   - **ARCH-SECURE — pass:** Tests isolate storage; no new credential or external-input boundary.
   - **ARCH-ORDER — pass:** Existing confirmation sequencing remains intact; cancellation and resume are exercised.
   - **ARCH-FUNERAL — pass:** No new durable runtime artifacts; temporary fixtures are cleaned up.

7. **Plan revision recommendations:** None. Existing revisions explain the starter-policy expansion and match the implementation.

```findings
{}
```

---

## Re-review — 2026-09-14T09:46:38-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 249 — Fix chat finder delete key collision |
| repo | parley.nvim |
| issue file | workshop/issues/000249-finder-delete-key.md |
| boundary | whole-issue close |
| milestone | — |
| window | c90d2f953d6b6c3d3b91f7a6b13368ea5c61b9ed..64ef3ccce2bc0de9e769aa0c4bf017bd9925706f |
| command | sdlc close --issue 249 |
| reviewer | codex |
| timestamp | 2026-09-14T09:46:38-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned changes satisfy issue #249’s Spec and revised Plan. Single-chat and tree deletion now have distinct defaults, the starter retains finder-local controls, and Ctrl+j/k use consuming prompt mappings. No blocking findings emerged. Independently run focused tests and lint passed.

1. **Strengths**
   - Config and registry fallback both use `<C-g>D`, keeping runtime and help aligned.
   - Deletion regressions inspect effective Neovim mappings and verify confirmation targets, cancellation, and child-file preservation across three configuration sources.
   - Starter policy reuses registry scope metadata and covers chat, note, and issue finders.
   - README and starter atlas changes document the revised behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Passed: ChatFinder **57**, float picker **79**, starter configuration **5**, keybindings **70** tests.
   - Lint: **0 warnings, 0 errors across 447 files**.
   - This review did not independently rerun the full suite or native launcher audit. Effective-map tests verify dispatch and effects; they do not reproduce native keyboard timing.

6. **Architectural notes**
   - **ARCH-DRY — Pass:** reuses registry scopes and existing navigation helpers.
   - **ARCH-PURE — Pass:** policy remains a data projection; UI effects stay in the picker.
   - **ARCH-PURPOSE — Pass:** addresses both the collision and starter filtering across finder families.
   - **ARCH-MOCK — Pass:** introduces no external-service dependency; deletion tests exercise temporary files through existing seams.
   - **ARCH-CONSTRAINTS — Pass:** adds no scanning, fan-out, or expensive per-keystroke work.
   - **ARCH-SECURE — Pass:** new integration cases use temporary chat roots; no credential handling added.
   - **ARCH-ORDER — Pass:** retains existing confirmation suspend/resume handling; navigation consumes native actions.
   - **ARCH-FUNERAL — Pass:** creates no new durable runtime artifacts or background processes.

7. **Plan revision recommendations:** None. Existing revisions account for the expanded scope.

```findings
{}
```
