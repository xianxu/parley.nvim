# Boundary Review — parley.nvim#292 (whole-issue close)

| field | value |
|-------|-------|
| issue | 292 — Alt+h as an alias of <C-g>? (keybinding help) |
| repo | parley.nvim |
| issue file | workshop/issues/000292-alt-h-alias.md |
| boundary | whole-issue close |
| milestone | — |
| window | d25dfcfc83d148b99a69e352040c637bca15b531..be93eb1b5d121443b1604f7fafa1700d585236a3 |
| command | sdlc close --issue 292 |
| reviewer | claude |
| timestamp | 2026-09-27T17:59:36-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Verdict: FIX-THEN-SHIP.** One small comment fix is left, and it doesn't block the gate.

The change does what the issue asks. `<M-h>` is added as a second key to `global_shortcut_keybindings` through the existing alias mechanism. The registry's `default_key` and `config.lua` stay in agreement. Both keys are tested through the installed mappings in Normal and Insert mode, and a second test confirms `<M-h>` goes quiet when `default_keymaps = false`. The atlas lists the alias, and the help float already shows aliases generically as `(also …)` (`keybinding_registry.lua:1272`). The one finding is a stale comment in `config.lua`, on the line next to the one this diff edited.

**1. Strengths**
- The alias reuses the existing list-shortcut mechanism instead of adding a second binding entry (`config.lua:450`, `keybinding_registry.lua:115`). This satisfies ARCH-DRY.
- The integration test calls the real `maparg` callback for each key/mode pair and counts calls to `cmd.KeyBindings`. It restores the original handler in a `pcall` guard (`keybinding_agreement_spec.lua:665-691`). Both Done-when modes (n and i) and both keys are covered.
- The master-switch "off" state is covered as well as the "on" state.
- The lead-split unit test and the starter-profile test were updated to include `help`. That keeps the "which key leads" decision locked by a test.
- The existing generic `collisions()` guard (`keybindings_spec.lua:977-1022`) already covers the spec's "no collision" clause. No ad-hoc check was needed.

**2. Critical:** none.

**3. Important:** none.

**4. Minor**
- **Stale comment at `lua/parley/config.lua:379-381`.** It still says "the split is even" and lists `chat_prune` as alt-leading.
  - The diff edited line 380 to add `help`, so the groups are now 4 `<C-g>`-leading vs 2 alt-leading.
  - `chat_prune` is now `<C-g>b`-only (`keybindings_spec.lua:290,360`), so it doesn't belong in the alt-leading list.
  - The lead-split test (`keybindings_spec.lua:1077-1080`) points to this comment as naming the groups, and it asserts alt = `{branch_ref, open_file}`.
  - The atlas copy was fixed in this diff: the "split is even" wording was removed, and it says "two lead with the alt key".
  - **Fix:** drop "the split is even" and remove `chat_prune` from the alt list at 379/381, matching the atlas and the test.

**5. Test coverage notes**
- Every Done-when clause is tested in both of its states.
- The help float showing both keys relies on existing generic alias-rendering coverage. That's acceptable because the rendering path wasn't touched.
- The `single_source_sweeps_spec` failure and the flaky parallel specs in the Log are environment problems, not caused by this diff: this diff adds no exports.

**6. Architecture**
- **ARCH-DRY: pass.** It reuses the alias list and the generic collision guard.
- **ARCH-PURE: pass.** It's a config and data change only, with no logic added.
- **ARCH-PURPOSE: pass.**
  - Every consumer derives from the one list: the installed mappings, the help float, the starter profile and the lead-split test.
  - The one hand-written restatement of the lead-split groups is the `config.lua` comment in the Minor finding.

**7. Plan revisions:** none. The plan matches the code.

```findings
findings:
  - id: new
    severity: Minor
    family: doc-claim-drift
    title: |
      config.lua lead-split comment still says "the split is even" and lists chat_prune as alt-leading
    detail: |
      lua/parley/config.lua:379-381. The diff edited line 380 to add help, but left line 379
      ("This is not an exception -- the split is even") and line 381 (chat_prune listed as
      alt-leading) stale. The actual split is 4 <C-g>-leading (outline, chat_drill_in,
      new_question, help) vs 2 alt-leading (open_file, branch_ref); chat_prune is <C-g>b-only
      (keybindings_spec.lua:290,360). The lead-split test (keybindings_spec.lua:1077) points to
      this comment. The one other copy of the grouping is atlas/ui/keybindings.md:140-146, which
      this diff already fixed. Fix: drop "split is even" and remove chat_prune from the alt list.
```
