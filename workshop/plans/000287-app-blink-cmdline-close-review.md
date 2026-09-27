# Boundary Review — parley.nvim#287 (whole-issue close)

| field | value |
|-------|-------|
| issue | 287 — app: blink.cmp (lua matcher) for fuzzy cmdline completion and history search |
| repo | parley.nvim |
| issue file | workshop/issues/000287-app-blink-cmdline.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6eea72a374350bc1287791c577506ff44f27d93e..70626cb01660e0be0e8d5e37e8fc886600870050 |
| command | sdlc close --issue 287 |
| reviewer | claude |
| timestamp | 2026-09-27T11:27:08-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Summary.** The blink.cmp change does what the Spec asks. It is pinned to v1.10.2 at `78336bc8` (I checked the scratch checkout). It uses the Lua matcher, has no insert sources, sets the insert preset to `none`, uses the cmdline preset with the arrow keys removed, and sets `auto_show`. Both test layers are sound: a spec-shape check in `bootstrap_lazy.lua`, and a check against the real pinned blink that types `:mkpv`/`:thm` and confirms insert mode stays quiet. The README and atlas are updated. The one real problem is next to the diff. Adding `keys` to the telescope spec quietly turns telescope into a lazy-loaded plugin. So `:Telescope` no longer exists at startup, and the new fuzzy `:` completion can't offer it. The fix is one line.

**Strengths**
- `packaging/starter-config/init.lua:151-163`: pinned by commit like the other app plugins, with a comment explaining why the arrows are dropped. I checked blink's `keymap/presets.lua:26-43`: the cmdline preset binds `<Left>`/`<Right>` to select_prev/next and leaves `<Up>`/`<Down>` alone. That makes the README line "arrow keys still move the cursor and walk earlier commands" accurate.
- `tests/packaging/completion_compatibility.lua`: it fakes only the installer boundary (`lazy.setup`) and runs the production `init.lua` options through the real blink. It covers both states in Done-when: the cmdline menu appears, and insert mode shows no items, no menu and no buffer-local insert maps. It also checks that blink's directory has no native library.
- `tests/packaging/bootstrap_lazy.lua:18-37`: it calls the `<C-g>:` handler and checks that it reaches `command_history`, instead of only comparing the key string.
- `keymap.preset = "none"` respects #262 (the app claims no ordinary editing keys), and the Log records why.

**Critical:** none.

**Important**
1. `packaging/starter-config/init.lua:147-149`: **adding `keys` makes telescope lazy-loaded.**
   - Before this change the telescope spec had no trigger, so lazy.nvim loaded it at startup (`lazy` is false by default, and `init.lua` sets no `defaults.lazy`). A spec that has `keys`/`cmd`/`event`/`ft` is lazy unless it sets `lazy = false`.
   - Result: until the user presses `<C-g>:`, `:Telescope …` is "Not an editor command". It also won't show up in the new blink menu, which undercuts this issue's goal of making commands findable.
   - Parley itself never requires telescope (grep over `lua/` finds only a comment), so the `:Telescope` command is the only thing lost.
   - Fix: add `cmd = "Telescope"` (keeps telescope lazy and still registers the command) or `lazy = false`. Assert it in `bootstrap_lazy.lua`.
   - The same risk applies to every spec in `additional_plugins`. The other specs in this window already choose their loading explicitly: lualine and blink use `lazy = false`, markdown-preview uses `cmd`/`ft`. Telescope is the only one whose loading changed as a side effect.

**Minor**
- `tests/packaging/bootstrap_lazy.lua:23-26`: `package.loaded['telescope.builtin']` is only restored if `history_key[2]()` returns normally. Use pcall to restore it on error too.
- `completion_compatibility.lua` isn't run by any runner (same as the existing `statusline_compatibility.lua`). The Done-when's "headless test asserts blink's cmdline completions" holds only when someone runs it by hand with `PARLEY_BLINK_RUNTIME` set. The automated spec checks the opts shape, not the ranking. It's worth recording as a release step (for example in TOOLING.md) so it doesn't go stale.
- The fixed 800 ms `defer_fn` waits in `completion_compatibility.lua` could be flaky on a slow machine. Consider `vim.wait` with a condition.

**Test coverage notes.** The insert-quiet and cmdline-ranking states are both covered. The Log lists the mutations that turn the tests red (preset `default`, insert sources, arrows kept, `auto_show` off, `prefer_rust`). No test pins how telescope loads, which is why Important 1 got through.

**Architecture**
- **ARCH-DRY: pass.** The blink config lives only in `init.lua`. Both tests read it from the production spec instead of copying it.
- **ARCH-PURE: pass.** The change is declarative config. The test fakes only the installer boundary.
- **ARCH-PURPOSE: pass.** It delivers fuzzy `:` completion plus fuzzy history recall through telescope, with a documented reason (blink has no history source). The only way it falls short of the purpose is Important 1: a command drops out of the discoverable set.

**Plan revisions.** None needed beyond noting the telescope loading fix in the Log if it's applied.

```findings
findings:
  - id: new
    severity: Important
    family: lazy-spec-trigger-implies-lazy
    title: |
      Adding keys to the telescope spec makes it lazy-loaded, so :Telescope is gone at startup
    detail: |
      lazy.nvim treats any spec that has keys/cmd/event/ft as lazy unless it sets lazy = false. Telescope was loaded at startup before this change; now :Telescope is undefined, and missing from blink's : menu, until the user presses <C-g>:. Fix: add cmd = "Telescope" (or lazy = false) at packaging/starter-config/init.lua:147 and assert it in tests/packaging/bootstrap_lazy.lua. Family enumeration for this window: telescope is the only spec whose loading changed; lualine and blink set lazy = false, and markdown-preview already uses cmd/ft on purpose.
  - id: new
    severity: Minor
    family: test-global-restore-not-error-safe
    title: |
      bootstrap_lazy restores package.loaded telescope.builtin only if the handler returns normally
    detail: |
      tests/packaging/bootstrap_lazy.lua:23-26. Wrap the call in pcall, restore, then re-raise.
  - id: new
    severity: Minor
    family: release-check-not-wired
    title: |
      completion_compatibility.lua is not run by any test runner or release script
    detail: |
      Same as statusline_compatibility.lua. Record the manual command (PARLEY_BLINK_RUNTIME) as a release step so the real-blink ranking check doesn't go stale.
```

---

## Re-review — 2026-09-27T11:30:25-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 287 — app: blink.cmp (lua matcher) for fuzzy cmdline completion and history search |
| repo | parley.nvim |
| issue file | workshop/issues/000287-app-blink-cmdline.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6eea72a374350bc1287791c577506ff44f27d93e..64c470e604af9d427dc6653b893149adbc96bcbb |
| command | sdlc close --issue 287 |
| reviewer | claude |
| timestamp | 2026-09-27T11:30:25-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

All three findings from the previous round are fixed. The fix commit `64c470e6` changes only the starter spec, the bootstrap test, the packaging README and lessons, and each change is small and on target. For BR-1, the fix covers the whole class. It adds `lazy = false` to telescope, and the bootstrap test now fails for any plugin spec that has a load trigger (`keys`, `cmd`, `event` or `ft`) without `lazy = false`, except the deliberately lazy MarkdownPreview. Reading the loop at `tests/packaging/bootstrap_lazy.lua:30-36`: if telescope's `lazy = false` were removed, that assertion would fire. So the test would fail without the fix. `make test-spec SPEC=infra/starter` passes: 16 suites, 0 failures, 0 errors, including `starter_bootstrap_spec`. I found nothing new at Critical or Important severity.

1. **Strengths**
   - `tests/packaging/bootstrap_lazy.lua:30-36` states the lazy.nvim rule as one check over every plugin spec. It covers the whole family, so a future plugin with a trigger will also fail the test.
   - `bootstrap_lazy.lua:25-27` wraps the call in `pcall`, restores `package.loaded['telescope.builtin']`, and only then re-raises the error. That is the order BR-2 asked for.
   - `packaging/README.md:34-37` records the real-blink check as a release step, next to the existing theme-compatibility step.
   - `workshop/lessons.md` now has rules for both new families.
   - Every item in Done when can be traced to the code:
     - Fuzzy `:` completion with the Lua matcher and no native library is checked in `completion_compatibility.lua`.
     - The insert-mode quiet state (no items, no menu, no insert keys) is checked in the same file.
     - History recall comes from the `<C-g>:` key.
     - The starter README section was already added in the previous round.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none new.

5. **Test coverage**
   - The spec-level asserts (pin, options, the history key, the lazy rule) run automatically in `starter_bootstrap_spec`.
   - The check against the real blink plugin runs only when someone runs it by hand. That is now a written release step, not a test-runner job, so it matches how the existing theme and statusline checks work.

6. **Architecture notes**
   - **ARCH-DRY: pass.** No block in the diff duplicates code elsewhere, and the lazy rule lives in one place.
   - **ARCH-PURE: pass.** The changes are config and tests. The only fake is the installer boundary, and it is used appropriately.
   - **ARCH-PURPOSE: pass.** Each Done-when clause is delivered, and the BR-1 fix covers the class, not just the one instance.

7. **Plan revisions:** none needed. The Plan's checkboxes match the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      init.lua sets telescope lazy = false. bootstrap_lazy.lua:30-36 fails any spec with a trigger that lacks lazy = false (MarkdownPreview excepted). Removing the fix fails the test. Starter specs pass.
  - id: BR-2
    disposition: addressed
    note: |
      bootstrap_lazy.lua:25-27 now calls through pcall, restores the global, then raises call_error.
  - id: BR-3
    disposition: addressed
    note: |
      packaging/README.md:34-37 documents the PARLEY_BLINK_RUNTIME completion_compatibility run as a release step for blink bumps, matching the existing theme check.
```
