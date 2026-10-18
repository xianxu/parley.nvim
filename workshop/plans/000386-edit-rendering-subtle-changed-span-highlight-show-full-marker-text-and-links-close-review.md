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
