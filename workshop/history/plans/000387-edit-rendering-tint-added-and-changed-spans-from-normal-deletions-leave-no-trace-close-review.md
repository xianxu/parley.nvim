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

---

## Re-review — 2026-10-18T13:46:59-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 387 — Edit rendering: tint added and changed spans from Normal; deletions leave no trace |
| repo | parley.nvim |
| issue file | workshop/issues/000387-edit-rendering-tint-added-and-changed-spans-from-normal-deletions-leave-no-trace.md |
| boundary | whole-issue close |
| milestone | — |
| window | a67ec3d7773f36787e8f51fb6afbf13a02c5ca78..6a3660d606f4b8ec358e602192d7776ae7520a28 |
| command | sdlc close --issue 387 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-18T13:46:59-07:00 |
| verdict | SHIP |

## Review

Diff read; prior findings look addressed. Next I'm running the focused specs.

Specs need the harness's isolated environment; switching to `make test-spec`.

Running the last mapped spec group (skills/skill-system).

```verdict
verdict: SHIP
confidence: high
```

All three findings from the last round are fixed, and nothing new comes up at Critical, Important or Minor. One function, `presentation.kind(old, new)` (`lua/parley/presentation.lua:74`), now decides whether an edit is an add, a change or a delete. The round (`decorations`) and the review skill's edit records (`skill_invoke.lua:77`) both get the kind from it. `attach_diagnostics` and `highlight_edits` look only at that kind and no longer re-check `new_string`. I checked every Done-when item against the code. The tints are blended from `Normal`'s bg, fall back to black or white by `'background'`, are re-derived on ColorScheme and can be overridden. A round deletion gives no extmark and no diagnostic, and so does a review deletion. The define term is marked add, both when it is first drawn and when footnotes are reloaded. Snapshots keep each span's kind. I ran the mapped specs through the harness (`make test-spec` for ui/highlights, modes/review, modes/session_sync, chat/inline_define and skills/skill-system), and every file reported 0 failed and 0 errors.

**1. Strengths**
- `lua/parley/color.lua` is a small pure module. Its unit tests (`tests/unit/color_spec.lua`) cover the endpoints, rounding, and dark and light bases.
- `presentation.kind` is the single source for the empty-old rule. The `deletion` flag and its message are removed rather than left alongside the new field.
- `highlight_span` now takes one argument order. The four-argument form had no production caller and was removed, which also removes an ambiguous overload.
- `highlight_groups_spec.lua` checks the tints against `color.blend` over a known `Normal` bg. It also checks they are re-derived on ColorScheme, checks the fallback from both `'background'` values (setting the option before clearing Normal, as it must), and checks the overrides.
- A snapshot keeps the span's kind (`kind_of`, `skill_render.lua:296`), and the test asserts `ParleyEditAdd` after a round trip, so undo/redo no longer turns an add into a change.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings:** none new.
- Not raised: `highlight_edits` no longer guards against an empty `new_string` itself; it relies on `kind == "delete"`. The only production caller (`skill_invoke`) always sets the kind, and a call without a kind but with an empty string would only make a zero-width extmark. Not worth a finding.

**5. Test coverage notes**
- BR-3 changed structure only, not behaviour. The existing deletion test (`skill_render_spec.lua:80`, which now passes `kind = "delete"`) and the presentation "yields nothing for a deletion" test pin the behaviour it had to keep.
- The round spec covers a mixed add/change pair, and the review spec covers add and change edits plus a deletion with neither a highlight nor a diagnostic. The define highlight is covered at three rehydrate sites (`highlighting_spec.lua:753/775/797`) and in `define_spec`.

**6. Architectural notes**
- **ARCH-DRY: pass.** One kind rule. `decorations` calls `M.kind` once per span. `EDIT_HL` is one table mapping kinds to group names.
- **ARCH-PURE: pass.** `blend` and `kind` are pure and unit-tested without IO. `setup_highlights` stays a thin layer that reads `Normal` and sets groups.
- **ARCH-PURPOSE: pass.** I checked every consumer of the edit groups: the round, review edits, a fresh define, footnote rehydrate, and snapshot/apply_snapshot. Each one gets its group from the kind. The define paths hard-code `add`, which matches the spec ("the define's term span inserts the reference without replacing anything"). That is a fixed fact about defines, not a second copy of the empty-old rule.
- **ARCH-MOCK: pass (N/A).** No new external dependency; the inputs are Neovim's own highlight API.
- **ARCH-CONSTRAINTS: pass.** The blend runs once per setup or ColorScheme and costs almost nothing. There's no new keystroke-path work.
- **ARCH-SECURE: pass.** The only inputs are the user's own config overrides and `Normal`'s bg. A missing bg falls back visibly, not to a made-up value.
- **ARCH-ORDER: pass.** No new state is held between events. The snapshot now records the kind, so an undo/redo replay gives back the same group.
- **ARCH-FUNERAL: pass.** Nothing durable is created. The extmarks live in the existing namespaces and are cleared by the existing paths.

**7. Plan revision recommendations:** none. The plan and Log match the code: `kind` replaces `deletion`, `highlight_span` has one form, and snapshots carry `kind`.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      atlas/chat/inline_define.md:152 now says publish_footnotes redraws the ParleyEditAdd span (matches highlight_footnote_span, skill_render.lua:106, EDIT_HL.add). mode.lua:8-10 now puts the why in the agent's reply, consistent with round.md:49 and SKILL.md:53. I grepped the tree for other stale deletion/gutter claims and found none.
  - id: BR-2
    disposition: addressed
    note: |
      skill_render.lua:223 deletion line now sits in the description above the @param block.
  - id: BR-3
    disposition: addressed
    note: |
      attach_diagnostics (skill_render.lua:230) and highlight_edits (:269) test only kind ~= "delete"; decorations calls M.kind once per span (presentation.lua:101-102). The change is structural only; the existing deletion specs (skill_render_spec.lua:80, presentation_spec) still pin the behaviour and pass under make test-spec.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"a4b6ce80-1915-487b-9e48-9227a02f9ff1","repository":"github.com/xianxu/parley.nvim","issue_id":"000387","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/532beda65f31019c","reviewed_head":"6a3660d606f4b8ec358e602192d7776ae7520a28","slot":"parley.nvim:3","requested_at":"2026-10-18T20:33:02.017498Z"},"phase":"finished","pid":36902,"started_at":"2026-10-18T20:33:02.141187Z","finished_at":"2026-10-18T20:46:59.054308Z","session_id":"083bd6ac-146a-45e4-9a2c-d738d8f98fbe","outcome":"returned"}] -->
