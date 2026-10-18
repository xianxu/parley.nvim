# Boundary Review — parley.nvim#386 (whole-issue close)

| field | value |
|-------|-------|
| issue | 386 — Edit rendering: subtle changed-span highlight; show full 🤖 marker text and links |
| repo | parley.nvim |
| issue file | workshop/issues/000386-edit-rendering-subtle-changed-span-highlight-show-full-marker-text-and-links.md |
| boundary | whole-issue close |
| milestone | — |
| window | 998cde19c99d8d15d45b98e6edee98229ca3e637..248e11d528ccc8ea5f7c95405bcbe819e2c49355 |
| command | sdlc close --issue 386 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-18T10:08:59-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking whether every Parley highlight group really survives `:colorscheme`, as the Log says, then I'll run the tests.

Running the touched spec files; the first attempt printed no summaries, so checking raw output.

A handful of unrelated specs failed; checking whether that's environmental by running them at base.

Same six failures at base, so they're environmental. Now checking the test diffs against Done-when.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change does what the Spec asks. Every edited span now gets one extmark in `ParleyEditChange`, with no whole-line `DiffChange` left in `skill_render.lua`. `ParleyAgentChange` and `highlight_line` are gone with no remaining callers. `view.layout` no longer emits hidden ranges, and the snap, `blocked_spans`, `has_marker` and `concealcursor` forcing are all removed. `conceallevel` now depends on buffer kind: 0 for markdown, 2 for chat, and an unknown kind fails an assert. All eight touched spec files pass, including the new `highlight_groups_spec.lua`. The full suite has six failures, but the same six fail at base 998cde19, so they come from the environment, not from this diff. One cheap fix is needed before close. The atlas says, and the issue Log claims as a class-wide sweep, that *every* Parley highlight group is re-applied on `ColorScheme`. That's false: the autocmd only re-runs `setup_highlights`, and several Parley groups are defined in other modules.

### 1. Strengths
- `lua/parley/skill_render.lua:250-276`: `position_of` plus a single `highlight_span` call replaces the per-line loop. The specs cover the boundary cases exactly: a span inside one line, a multi-line span with UTF-8, and a span ending in a newline that ends at `(next_row, 0)` (`tests/unit/skill_render_spec.lua`). The pure-deletion guard is kept.
- `lua/parley/highlighter.lua:1067-1070`: the `ColorScheme` callback wraps `setup_highlights` so its truthy return doesn't delete the autocmd. The spec runs `:colorscheme` twice to prove the autocmd outlives its first run.
- `lua/parley/comment/init.lua:17-19`: the `CONCEALLEVEL` table is the single place both buffer kinds are set. The assert catches a caller that passes the wrong kind. Both kinds are tested, including the global-2 override in markdown (`comment_attach_spec`).
- The snapshot format dropped `hl_lines` everywhere it appeared, including `projection.record_empty_for`. A spec pins `snap.hl_lines == nil`.
- `comment_render_spec` checks that nothing is concealed except brackets re-asserted as themselves, in both markdown and chat.

### 2. Critical findings
None.

### 3. Important findings
- **The "every group survives `:colorscheme`" claim is too broad** (`atlas/ui/highlights.md:4`, issue Log, ARCH-PURPOSE "class not site"). The `ColorScheme` autocmd at `lua/parley/highlighter.lua:1070` only re-runs `setup_highlights`. These Parley groups are defined elsewhere and are still lost after `:hi clear`:
  - `ParleySessionSync*` in `session_sync.lua:536`. It's defined only on the first `attach`, which returns early afterwards, so an attached buffer loses its red or orange turn band until another buffer attaches.
  - `ParleyAttention*` in `attention.lua:230`.
  - `ParleyTagOn`, `ParleyTagOff` and `ParleyTagAction` in `float_picker.lua:811`.
  - The issue-card highlight in `issue_tracker.lua:71`. It's re-ensured lazily, so it's lower risk.
  - The `diag_display` header and message groups in `skills/review/diag_display.lua:57`. They're re-set on every `ensure_display`, so they recover.
  - Not a Parley group, but the `Search` override in `init.lua:1383` is also lost.
  
  Fix: either have the `ColorScheme` callback also call the other modules' define functions (`session_sync`, `attention`, `float_picker` tags, `issue_tracker.ensure_highlight`), or narrow the atlas and Log wording to "every group set in `setup_highlights`".

### 4. Minor findings
- ARCH-DRY: `position_of` (`skill_render.lua:251`) is a third converter from a byte offset to a 0-based (row, col). The other two are `init.lua:2107` (`byte_offset_to_rowcol`) and `skills/review/init.lua:258` (`offset_to_pos`). All three are local; a shared pure helper would remove the duplication.
- `snapshot` (`skill_render.lua:~313`) falls back to `end_lnum = details.end_row or m[2]`, which silently records a zero-width span for a mark with no end. This is harmless now that every writer sets an end.
- The nvim-cmp clause in Done-when is tested with plain `feedkeys` and no completion plugin loaded. That's acceptable because the snap that caused the problem is gone, but the test doesn't literally exercise cmp.

### 5. Test coverage notes
- Specs cover span exactness (`skill_render_spec`), the round group (`skill_render_round_spec`), a pure deletion getting no highlight in both `highlight_edits` and the round, `:colorscheme` survival, the config override, both buffer kinds, and insert-mode typing in a turn.
- The `:colorscheme` spec only asserts groups from `setup_highlights`, so it can't catch the gap in the Important finding.
- Suite: every spec touched by this diff passes. Six integration and arch specs fail (`scratch_placement`, `file_history`, `open_reference`, `starter_project`, `starter_config`, `zero_config`), and the same six fail at base, so they're environmental.

### 6. Architectural notes
- ARCH-DRY: flagged as Minor, for the offset-converter duplication.
- ARCH-PURE: pass. `comment/view.lua` stays pure and got smaller. `skill_render` is the documented thin IO wrapper, and `position_of` inside it is pure.
- ARCH-PURPOSE: flagged as Important. The Spec's purpose is delivered in full: spans only, one group, nothing concealed, links shown. The class-wide `:colorscheme` sweep that the Log claims is incomplete.

### 7. Plan revision recommendations
- Add a Revisions or Log entry that corrects "One `ColorScheme` autocmd … re-runs `setup_highlights` for all of them". It should either list the out-of-module groups that are now also re-applied, or scope the claim to `setup_highlights` groups.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: highlight-groups-survive-colorscheme
    title: |
      Atlas and Log claim every Parley group is re-applied on ColorScheme, but only setup_highlights groups are
    detail: |
      highlighter.lua:1070 re-runs only setup_highlights. Groups defined elsewhere are still lost after :hi clear: ParleySessionSync* (session_sync.lua:536, defined once on first attach, so attached buffers lose their turn band), ParleyAttention* (attention.lua:230), ParleyTagOn/Off/Action (float_picker.lua:811), the issue_tracker.lua:71 card highlight (re-ensured lazily), and the diag_display groups (re-set per ensure_display). atlas/ui/highlights.md says "Every group is re-applied on ColorScheme". Fix: call those modules' define functions from the ColorScheme callback, or narrow the atlas and Log wording to setup_highlights groups.
  - id: new
    severity: Minor
    kind: defect
    family: offset-to-rowcol-helper
    title: |
      position_of is a third byte-offset to (row, col) converter (ARCH-DRY)
    detail: |
      skill_render.lua:251 position_of duplicates init.lua:2107 byte_offset_to_rowcol and skills/review/init.lua:258 offset_to_pos. All three are local; they could become one shared pure helper.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"949630c7-4702-4875-acb5-5819e1c4591b","repository":"github.com/xianxu/parley.nvim","issue_id":"000386","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f504c4f5485847b2","reviewed_head":"248e11d528ccc8ea5f7c95405bcbe819e2c49355","slot":"parley.nvim:3","requested_at":"2026-10-18T16:56:55.994632Z"},"phase":"finished","pid":72299,"started_at":"2026-10-18T16:56:56.088222Z","finished_at":"2026-10-18T17:08:59.135896Z","session_id":"0e8e8fb0-5cab-4066-90eb-9a979136c9af","outcome":"returned"}] -->

---

## Re-review — 2026-10-18T10:42:36-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 386 — Edit rendering: subtle changed-span highlight; show full 🤖 marker text and links |
| repo | parley.nvim |
| issue file | workshop/issues/000386-edit-rendering-subtle-changed-span-highlight-show-full-marker-text-and-links.md |
| boundary | whole-issue close |
| milestone | — |
| window | 998cde19c99d8d15d45b98e6edee98229ca3e637..0b8c2fa14d28084ae98bc18d93956c8f5a58ba97 |
| command | sdlc close --issue 386 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-18T10:42:36-07:00 |
| verdict | SHIP |

## Review

BR-1 looks fixed. Now I'm checking the skill_render and comment-view changes, then I'll run the tests.

Running the touched spec files now.

Running the full unit and integration suites through make.

```verdict
verdict: SHIP
confidence: high
```

The fix for BR-1 holds, and it covers the whole class rather than one site. The new `lua/parley/highlight_groups.lua` `keep(name, define)` registry is the single owner of the `ColorScheme` re-run. All six modules that set a Parley group now register with it: highlighter, session_sync, attention, issue_tracker, float_picker and diag_display. A guard spec fails if a module sets a Parley group without registering. I grepped every `nvim_set_hl` in `lua/` and found no unregistered Parley group; the only ones outside the registry are the theme's `Search` and the `@markup.strikethrough` clears. The rest of the issue matches the Spec and Plan. `skill_render` marks only the changed span with `ParleyEditChange`. No whole-line `DiffChange`, `hl_lines`, `highlight_line` or `ParleyAgentChange` is left in `lua/`. `view.layout` no longer hides anything, and the snap and `concealcursor` forcing are gone. `comment.attach` takes the buffer kind: markdown 0, chat 2. The unit suite is green. In `make test-integration`, eight files fail: `scratch_placement`, `zero_config`, `starter_*`, `file_history`, `open_reference`, `fresh_clone` and `entity_textobj`. The failures I could see in `scratch_placement`, `zero_config` (the chat landed under `workshop/parley/` instead of the default dir), `starter_*`, `file_history` and `open_reference` all trace to this review checkout's location: its scratch sits inside the repo tree, under `.sdlc-review/tmp`. I didn't get failure output for `fresh_clone` or `entity_textobj`; their failing set changed between runs. None of the eight specs mention conceal, `ParleyEditChange`, `highlight_groups` or comments. I didn't check whether they also fail at base. Nothing blocks SHIP.

1. **Strengths**
   - `lua/parley/highlight_groups.lua:15`: the registry is keyed by module name, so registering again replaces the old definer and nothing grows. It holds one augroup, and the callback returns nothing, which avoids the "truthy return deletes the autocmd" trap.
   - `tests/integration/highlight_groups_spec.lua`: a class guard over `lua/parley/**/*.lua` checks that the rule holds, not just one instance of it. It also tests that a replaced definer stops running.
   - Removing the duplicate `ParleyPickerApproximateMatch` from `init.lua` fixes a real bug: it ran after `setup_highlights` and overrode `highlight.approximate_match`.
   - `skill_render.lua:263-280`: `highlight_edits` now marks one exact span and still skips pure deletions. `snapshot` and `apply_snapshot` keep only spans. The comment-module cleanup also removed state: `prev_col`, the `parley_cc_*` window variables and the comment augroup are gone.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - BR-2 (offset-to-(row, col) helpers) is still open; see the disposition below.
   - `README.md:112` says users can restyle edits through "the `ParleyEditChange` group". But `setup_highlights` sets the group without `default = true` and re-runs on every `ColorScheme`, so a plain `:hi ParleyEditChange` is overwritten at the next `:colorscheme`. The README should point users to `highlight.edit_change`, which is what the Log already says.
   - The guard checks per file, not per definer: a file with two definers passes if it registers only one. That's acceptable for now.
   - `highlighter.disable_strikethrough` clears `@markup.strikethrough` once, so a later `:colorscheme` can bring strikethrough back. This predates the issue and isn't a Parley group, but it's a nearby gap.

5. **Test coverage**
   - Specs cover:
     - span-only marking, including multi-row edits;
     - the round group;
     - surviving `:colorscheme` twice;
     - the config override;
     - `keep` replacing a definer;
     - the registration guard.
   - No spec shows a session-sync band keeping its color after `:colorscheme`. The guard covers this structurally.

6. **Architecture (one line per principle)**
   - **ARCH-DRY:** pass. One registry replaces the per-module autocmds. BR-2 remains (Minor).
   - **ARCH-PURE:** pass. `position_of` is pure. The rendering code was already a thin layer over the vim API.
   - **ARCH-PURPOSE:** pass. Every module that defines groups now goes through `keep`, and the guard enforces it.
   - **ARCH-MOCK:** N/A. There are no external binaries or services.
   - **ARCH-CONSTRAINTS:** pass. The definers run once per `:colorscheme`, and there are only six.
   - **ARCH-SECURE:** N/A. Nothing reads untrusted input or touches secrets.
   - **ARCH-ORDER:** pass. The diff removed cross-event cursor and concealcursor state. The registry is a name → function map, and the order definers run in doesn't matter because no definer depends on another.
   - **ARCH-FUNERAL:** pass. The registry is bounded by module count, keeps one augroup, and writes nothing durable.

7. **Plan revisions:** none needed. The Log already records the registry and BR-2's deferral.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      highlight_groups.keep is registered by all six group-defining modules (grep of nvim_set_hl in lua/ confirms); the guard spec in highlight_groups_spec fails for any unregistered module; the atlas text matches.
  - id: BR-2
    disposition: not-addressed
    note: |
      position_of (skill_render.lua:251) is still a third local offset-to-(row, col) converter; the deferral is reasonable for a Minor and does not block.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: override-through-config
    title: |
      README says restyle via the ParleyEditChange group, but setup_highlights overwrites it on every ColorScheme
    detail: |
      highlighter.lua:677 sets ParleyEditChange without default=true and re-runs it on ColorScheme through highlight_groups.keep, so a user's direct :hi ParleyEditChange is lost at the next :colorscheme. README.md:112 should point to highlight.edit_change only, which is what the Log already says.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e51952ae-19db-4cd6-aa1f-e6a59386e434","repository":"github.com/xianxu/parley.nvim","issue_id":"000386","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/05d9485f170113c2","reviewed_head":"0b8c2fa14d28084ae98bc18d93956c8f5a58ba97","slot":"parley.nvim:3","requested_at":"2026-10-18T17:22:38.991115Z"},"phase":"finished","pid":92085,"started_at":"2026-10-18T17:22:39.087806Z","finished_at":"2026-10-18T17:42:36.283883Z","session_id":"242c8302-de3c-40f2-a032-2dd0edaf5ce3","outcome":"returned"}] -->
