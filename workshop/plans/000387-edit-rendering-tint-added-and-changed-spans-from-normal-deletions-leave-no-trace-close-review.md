# Boundary Review — parley.nvim#387 (whole-issue close)

| field | value |
|-------|-------|
| issue | 387 — Edit rendering: tint added and changed spans from Normal; deletions leave no trace |
| repo | parley.nvim |
| issue file | workshop/issues/000387-edit-rendering-tint-added-and-changed-spans-from-normal-deletions-leave-no-trace.md |
| boundary | whole-issue close |
| milestone | — |
| window | a67ec3d7773f36787e8f51fb6afbf13a02c5ca78..2842873c3b0e939612c75a5088fe77221a1712c4 |
| command | sdlc close --issue 387 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-18T12:32:54-07:00 |
| verdict | SHIP |

## Review

Reviewing the #387 diff; now running the affected specs to confirm the suite is green.

The specs need to run through make. Retrying that way.

```verdict
verdict: SHIP
confidence: high
```

**Verdict: ready to ship.** I found nothing Critical or Important; there are three Minor findings below.

The change does what #387 asks. There is one place that decides whether an edit is an add, a change or a delete: `presentation.kind`. The agent's round uses it, and so do the review skill's edit records. The define term and the footnote reload path are both hard-wired to `add`. The new `color.blend` is pure and has its own tests. The tints are worked out from `Normal`'s background inside the existing highlight setup, so they are rebuilt after every `:colorscheme`. Every clause of "Done when" has a test: the tint, the rebuild after a theme change, the fallback for both `light` and `dark`, the two user overrides, round add/change/delete, review change and delete, define add, and undo/redo keeping each span's colour.

I ran the full `make test` twice. Every spec this change touches passed both times. Both runs still had failures, but only in specs this change doesn't touch:
- **First run:** `scratch_placement`, `open_reference`, `file_history`, `starter_project`, `starter_config`, `zero_config`.
- **Second run:** only `tools_builtin_find`.

Since the failing set changed between runs, they look flaky or environment-related rather than caused by this change. I didn't confirm that against the base commit.

### Strengths
- **One owner for the rule.** `presentation.kind` (`lua/parley/presentation.lua:74`) is the only definition of add/change/delete. `skill_invoke.lua:77` uses it instead of keeping its own copy.
- **Simpler `highlight_span`.** It now has one signature with an optional kind (`skill_render.lua:288`). The old 4-or-5-argument overload is gone, and I found no callers still using the old form.
- **Pure core, thin shell.** `color.lua` is pure and tested without any I/O. `setup_highlights` only reads `Normal` and sets the groups.
- **Undo/redo keeps the colour.** `kind_of` stores the kind in the snapshot. The test at `skill_render_spec.lua:167` checks that an `add` span is still `ParleyEditAdd` after restore.
- **The fallback test is careful.** It sets `'background'` before clearing `Normal`, because setting `'background'` reloads the colour scheme.

### Critical findings
None.

### Important findings
None.

### Minor findings
1. **Two comments still describe the old deletion behaviour.**
   - `atlas/chat/inline_define.md:152` (edited in this window) says reloaded footnotes don't recreate the `ParleyEditAdd` highlight. They do: `publish_footnotes` calls `highlight_footnote_span` (`skill_render.lua:101-126`), and `highlighting_spec.lua:753/775/797` tests exactly that.
   - `lua/parley/skills/review/mode.lua:8` describes `apply-with-gutter-why` as "explain in the gutter". Pure deletions no longer get a gutter diagnostic, so the "why" now lives only in the reply or a 🤖 note, as `round.md:49` already says.
2. **A doc comment line is out of place** at `skill_render.lua:224`: the new "A pure deletion…" line sits between the `@param buf` and `@param edits` tags.
3. **ARCH-DRY: two functions re-check the delete rule.** `attach_diagnostics` (`skill_render.lua:230`) and `highlight_edits` (`:271`) test `new_string ~= ""` on top of `kind ~= "delete"`, which repeats part of `presentation.kind`. `decorations` also calls `M.kind` twice per span. This is harmless, but the class is three spots in this window.

### Test coverage notes
- Every "Done when" clause has a test. Both `light` and `dark` fallbacks are tested.
- The pure-deletion review test sets both `kind="delete"` and `new_string=""`, so it can't tell which guard is doing the work.
- `highlight_groups_spec`'s fallback test restores `vim.o.background` without a `finally`, so a failed assertion would leave it changed for later tests.

### Architectural notes
- **ARCH-DRY:** pass. The kind rule has one owner; finding 3 is a small leftover.
- **ARCH-PURE:** pass. `color.blend` and `presentation.kind` are pure, and the highlight setup is thin glue.
- **ARCH-PURPOSE:** pass. Every place that draws edits now goes through the kind (round, review edits, define, footnote reload, snapshot restore). None still uses a single hard-coded group.

### Plan revision recommendations
None. The plan and its log match the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-drift
    title: |
      Two comments still describe the old deletion and footnote-reload behaviour
    detail: |
      atlas/chat/inline_define.md:152 (edited in this window) says reloaded footnotes don't recreate the ParleyEditAdd highlight, but publish_footnotes -> highlight_footnote_span does (skill_render.lua:101-126; tested in highlighting_spec.lua:753/775/797). lua/parley/skills/review/mode.lua:8 describes apply-with-gutter-why as "explain in the gutter", but pure deletions no longer get a gutter diagnostic (round.md:49 already puts the why in the reply or a note). Fix both comments.
  - id: new
    severity: Minor
    kind: defect
    family: doc-comment-placement
    title: |
      attach_diagnostics doc line sits between two @param tags
    detail: |
      skill_render.lua:224: move "A pure deletion ... leaves no trace" above the @param block. No other instance in this window.
  - id: new
    severity: Minor
    kind: defect
    family: kind-rule-restated
    title: |
      ARCH-DRY: delete rule re-checked next to the kind field
    detail: |
      attach_diagnostics (skill_render.lua:230) and highlight_edits (skill_render.lua:271) test new_string ~= "" on top of kind ~= "delete", repeating part of presentation.kind; decorations (presentation.lua) also calls M.kind twice per span. Rely on the kind (or call presentation.kind once) so the rule has one source.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"c966caaf-8e54-47d3-b6d2-de653c386df8","repository":"github.com/xianxu/parley.nvim","issue_id":"000387","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/210aaf5863e9e92b","reviewed_head":"2842873c3b0e939612c75a5088fe77221a1712c4","slot":"parley.nvim:3","requested_at":"2026-10-18T19:25:49.434981Z"},"phase":"finished","pid":53786,"started_at":"2026-10-18T19:25:49.53626Z","finished_at":"2026-10-18T19:32:54.00303Z","session_id":"a3e13219-be7b-4ec8-9b8a-b89035191986","outcome":"returned"}] -->
