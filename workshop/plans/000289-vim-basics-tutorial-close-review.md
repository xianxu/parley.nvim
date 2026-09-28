# Boundary Review — parley.nvim#289 (whole-issue close)

| field | value |
|-------|-------|
| issue | 289 — Add tutorial 4: VIM Basics for newcomers |
| repo | parley.nvim |
| issue file | workshop/issues/000289-vim-basics-tutorial.md |
| boundary | whole-issue close |
| milestone | — |
| window | 28bef17ae32a381473fdef81c5c1141b3065ba89..53ce7d04a116b7734e8dc9cba29425f1ac91d3dc |
| command | sdlc close --issue 289 |
| reviewer | codex |
| timestamp | 2026-09-28T11:56:39-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The fourth tutorial is seeded, discoverable, and available through help. All 26 targeted tests and the packaged keyboard probe passed. Two inexpensive documentation corrections remain: README omits the lesson, and the tutorial incorrectly implies wrapped-line arrow movement works in Insert mode.

1. **Strengths**
   - One pure registry supplies seeding, filename recognition, help discovery, and Finder diagnostics.
   - Upgrade coverage verifies the new lesson is added without replacing edited tutorials.
   - The packaged probe exercises actual keystrokes and uses a stateful clipboard fake without touching the host clipboard.

2. **Critical findings:** None.

3. **Important findings**
   - [vim-basics.md:28](/Users/xianxu/workspace/parley.nvim/packaging/tutorials/vim-basics.md:28): The wrapped-line claim covers Normal and Insert, but the packaged mappings apply only to Normal and Visual. In the real profile, Down moved from `{1,0}` to `{1,77}` in Normal, but to `{2,0}` in Insert. Scope the claim to the supported modes; retain this issue’s no-new-editor-behavior constraint.
   - [README.md:118](/Users/xianxu/workspace/parley.nvim/README.md:118): “Learn by chatting” still lists only three lessons. Add the fourth tutorial’s link and a short description.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Passed: help-content unit tests (3), documentation integration tests (4), starter integration tests (19), and the packaged keyboard probe.
   - The probe omits wrapped-line movement; a separate packaged-profile check exposed the discrepancy above.
   - Both requested fixes are prose-only; wording-presence tests are unnecessary.

6. **Architectural notes**
   - **ARCH-DRY: pass.** All four runtime consumers derive tutorial names from the registry; no competing runtime list found.
   - **ARCH-PURE: pass.** Registry construction and membership remain deterministic and free of IO.
   - **ARCH-PURPOSE: flag.** The requested lesson is delivered, but its movement instructions must match the packaged profile. README discovery also needs completing.

7. **Plan revision recommendations:** No scope revision needed. Record the documentation corrections and verification in the issue Log.

```findings
findings:
  - id: new
    severity: Important
    family: documented-mode-behavior
    title: |
      Wrapped-line movement is incorrectly described for Insert mode
    detail: |
      packaging/tutorials/vim-basics.md:28-29 implies Up/Down follow wrapped lines in both Normal and Insert. packaging/starter-config/init.lua:20-24 maps these keys only in Normal and Visual; a real packaged-profile check confirmed Insert Down moves to the next logical line. Family enumeration: both Up and Down in this passage. Restrict the claim to supported modes, preserving the no-new-behavior scope (ARCH-PURPOSE).
  - id: new
    severity: Important
    family: readme-user-surface-discovery
    title: |
      README update appears missing for the fourth tutorial
    detail: |
      README.md:118-123 lists Welcome, Basics, and Advanced but omits the newly shipped VIM Basics lesson; README is unchanged in the pinned range. Family enumeration: the new fourth lesson is the sole added user surface missing from this catalog. Add its packaged-content link and a concise description.
```

---

## Re-review — 2026-09-28T12:04:14-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 289 — Add tutorial 4: VIM Basics for newcomers |
| repo | parley.nvim |
| issue file | workshop/issues/000289-vim-basics-tutorial.md |
| boundary | whole-issue close |
| milestone | — |
| window | 28bef17ae32a381473fdef81c5c1141b3065ba89..f8598aefdb403f1b5f7bfca908e54d796c44b7ef |
| command | sdlc close --issue 289 |
| reviewer | codex |
| timestamp | 2026-09-28T12:04:14-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

Both prior findings are addressed by accurate prose corrections. The pinned implementation delivers the fourth tutorial through seeding, Finder, navigation, and help while preserving edited lessons. No new blocking findings.

1. **Strengths**
   - `lua/parley/tutorials.lua:3` centralizes tutorial names across all four runtime consumers.
   - `tests/integration/starter_config_spec.lua:77` covers adding the missing fourth lesson while preserving existing edits.
   - `tests/packaging/vim_basics_compatibility.lua:24` exercises actual keyboard input with a stateful clipboard fake.

2. **Critical findings:** None.

3. **Important findings:** None remaining.

4. **Minor findings:** None.

5. **Test coverage notes:** Read-only Neovim checks passed for registry membership, the 256/257 help-topic boundary, and retrieval of all four packaged tutorials. Inspected startup preservation and keyboard regression tests; did not rerun the filesystem-writing integration suite or packaged-app probe.

6. **Architectural notes**
   - **ARCH-DRY: pass.** Seeding, recognition, help discovery, and Finder diagnostics derive from the registry.
   - **ARCH-PURE: pass.** Registry construction and membership are deterministic; filesystem operations remain in existing integration boundaries.
   - **ARCH-PURPOSE: pass.** The lesson covers the specified everyday actions, with corrected mode instructions and complete discovery documentation.

7. **Plan revision recommendations:** None.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The pinned correction at packaging/tutorials/vim-basics.md:28-29 explicitly distinguishes Normal/Visual wrapped-line movement from Insert text-line movement for both Up and Down. This matches packaging/starter-config/init.lua:20-24, whose mappings apply only to n/x modes. The correction changes prose only.
  - id: BR-2
    disposition: addressed
    note: |
      README.md:124-125 now links the fourth lesson and describes its contents. The target packaging/tutorials/vim-basics.md exists and covers the listed topics; read-only help retrieval also passed. The correction changes prose only.
```
