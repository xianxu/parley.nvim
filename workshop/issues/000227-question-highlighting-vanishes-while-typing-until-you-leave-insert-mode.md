---
id: 000227
status: working
deps: []
github_issue:
created: 2026-09-09
updated: 2026-09-10
estimate_hours: 4.30
started: 2026-09-10T13:13:23-07:00
---

# question highlighting vanishes while typing until you leave insert mode

## Problem

Operator report with a screenshot: while composing in insert mode, the chat's
highlighting is gone — the `💬:` question line and its block render as plain
text. Returning to normal mode restores it, which reads as *"moving outside to
normal mode triggers recoloring of the question"*. **Expected: questions are
constantly coloured.**

The recolour on mode change is a side effect, not the mechanism. Highlighting is
drawn by a decoration provider on redraw, and it **fails closed** the moment the
structure cache goes dirty.

### The symptom is instability, not only absence (operator, 5 more screenshots)

The first report showed the block rendering **plain**. A second batch taken
while typing continuously shows the colouring **changing frame to frame** —
*"as I typed, the question coloring kept changing"*. Across five captures of the
same buffer, the ordered-list markers (`1.` `2.` `3.`) render in one colour in
some frames and another in others, while the body text stays coloured.

That is the same defect seen at different redraw frames rather than a second
one. A chat buffer is `filetype=markdown` (`init.lua:1714`), so markdown's own
highlighting sits **underneath** parley's decoration overlay:

- frames where the structure cache is clean → the provider runs → parley's
  question colours win;
- frames where an edit has just dirtied it → `on_win` returns `false` → no
  parley decorations → **markdown's own colours show through**.

Typing alternates between the two states, so the block appears to shimmer rather
than simply vanish. The first screenshot caught a dirty frame at rest; these
catch the alternation.

**Stated as a hypothesis, not a finding:** the colour attribution above is read
off screenshots, and which layer owns the list-marker colour should be confirmed
at the buffer (`:Inspect` on a marker in a clean vs dirty frame) before the fix
is designed around it. What is *not* in doubt is the instability itself, which
the operator observed directly and which the `return false` path fully explains.

**This raises the fix's bar.** "Highlighting is present after typing stops" is
not enough — the Done-when must assert the rendered result is **stable across
consecutive redraws during a burst of edits**, since an intermittently-correct
overlay is what is actually being reported.

### The chain

**1. `on_lines` invalidates and does not repair.** `rebuild_structure`'s
`nvim_buf_attach` hook (`highlighter.lua:928-943`) tries an incremental update
and, when it cannot, gives up:

```lua
if reason then
    current.dirty = true
    current.renderable = false
else
    current.structure = replaced
end
```

Nothing schedules a rebuild. The cache simply stays unrenderable.

**2. The incremental path bails on almost any real edit.** `M.replace`
(`highlight_structure.lua:351-374`) succeeds only when **both** hold:

```lua
if old_last0 - first0 ~= #new_lines then
    return nil, #new_lines, "structural", ...      -- line COUNT changed
end
...
if not identical then return nil, #new_lines, "structural", work end   -- any fingerprint changed
```

So it handles only edits that change no line's structural fingerprint *and* keep
the line count identical. **Pressing Enter changes the count and bails
immediately** — which is exactly what the operator had just done (cursor on a
fresh line 11 in the screenshot). Typing a character that changes a line's
fingerprint bails too.

**3. The decoration provider draws nothing when dirty.**
`highlighter.lua:996-998`:

```lua
local structure_cache = structure_caches[bufnr]
if not structure_cache or structure_cache.dirty or not structure_cache.renderable then
    return false
end
```

`return false` means the window renders with **no** decorations at all — not
stale ones, none. Every highlight in the visible region disappears together,
which is why the symptom is "the whole thing goes plain" rather than "the edited
line is wrong".

**4. Recovery is incidental.** The cache is only rebuilt when something else
calls `rebuild_structure` — `BufEnter` (`highlighter.lua:1051`), or
`highlight_question_block` (`:851`, reached via `init.lua:2872`). Leaving insert
mode happens to reach one of those, so the colour returns and the mode change
gets the blame.

### Why the current design defers, which the fix must respect

`rebuild_structure` calls `build_structure`, which reads the **whole buffer**
(`reader:lines(0, -1, false)`) and re-derives every fingerprint and
`state_before`. That is precisely why the incremental path exists, and why a
naive "rebuild on every `on_lines`" would be wrong — it would put an O(buffer)
scan on every keystroke of a long chat. The current code avoids that cost by
paying with a blank screen instead.

## Spec

**Two independent changes; the first removes the symptom, the second restores
correctness.**

**1. Fail open, not closed.** While the structure is dirty, the provider should
render from the **last good structure** rather than returning `false`. The
edited region may be briefly stale — a line that just became a `💬:` may not
colour for a frame — but nothing flickers and the rest of the visible buffer
keeps its highlighting. Requires keeping the previous structure rather than
discarding it on invalidation, and distinguishing "stale but usable" from
"absent".

**The stale structure must stay aligned** (revised 2026-09-10). Footer start,
draft ranges and `state_before` are row-indexed, so a structure rendered
unchanged after an Enter paints the footnote colour N rows too high — over the
lines being typed. Every edit is therefore spliced into the structure (rows
inserted/removed, tokens re-derived): tokens, footer and drafts are always
exact, and the splice is fully exact whenever the edit touches only inert rows
(text, blank, fence, draft delimiter) and the first row below it is entered in
the same state as before. Only marker/`🧠:`/footnote edits leave it approximate.

**2. Schedule the repair.** `on_lines` should mark dirty **and** schedule a
debounced `rebuild_structure`, so correctness catches up within a frame or two
instead of waiting for an unrelated event. Debounce so a burst of keystrokes
costs one rebuild, not one per character.

Together the operator never sees plain text, and the structure converges without
an O(buffer) scan per keystroke.

**3. Close the rest of the class** (added 2026-09-10). Every path that leaves
the structure not matching its buffer must repair it rather than wait for an
unrelated event: a `:checktime`/autoread reload (today Nvim *detaches* the
attachment, blanking non-current windows), a splice that throws, and Nvim's
empty-buffer `on_lines` report (zero lines, though one remains). A failed
rebuild keeps rendering the aligned structure instead of going blank.

### Worth considering, not required

`M.replace`'s bail on a changed line **count** is the common case (every Enter).
An incremental path that handled pure insertion/deletion of non-structural lines
— shifting `fingerprints` and `state_before` rather than rebuilding — would keep
most edits on the fast path. Larger change; only worth it if (2)'s debounced
rebuild proves too expensive on long chats, which should be measured rather than
assumed.

## Done when

- Typing in a chat buffer — including pressing Enter — never blanks the
  highlighting; the `💬:` line and its block stay coloured throughout.
- The rendered highlighting is **stable across consecutive redraws** during a
  burst of edits — no frame-to-frame alternation between parley's colours and
  markdown's. Asserted by driving several edits and comparing decorations per
  frame, not by checking the end state once typing stops.
- A test drives `on_lines` with a line-count change and asserts the provider
  still returns decorations for rows outside the edit.
- A test asserts a dirty cache is rebuilt without any `BufEnter` /
  `highlight_question_block` call — i.e. the repair is scheduled, not incidental.
- Rebuild cost under a burst of keystrokes is measured on a long chat and
  recorded; one rebuild per burst, not per character.
- No regression in what the provider draws once clean.
- The structure's row count equals the buffer's after every edit, including
  emptying the buffer; a `:checktime` reload leaves the cache attached and
  current without any `BufEnter`/`TextChanged`.

## Estimate

One item per Plan task family: the `build` split (Task 1, a behavior-preserving
`cross-cutting-refactor`); two `lua-neovim` primitives — the pure splice, and
the highlighter glue (fail-open, repair deferral, reload/resync) that also
carries the test helper and the perf phases (Tasks 3–5); atlas/docs; one
operator e2e round (Task 7, `ux-rename-iteration`: the Done-when is a visual
stability claim reported from screenshots, so one round is the likely case);
and the one close review. Design takes the mid-density ×0.5 spec discount, not
×0.2: the pre-claim issue settled the diagnosis and direction, but the design
decisions (aligned splice, exactness rule, the class sweep, the state table)
were made after `claim`, inside the window `sdlc actual` measures. The operator
round takes no discount. `impl=` is 40% of the v2 table (v3.1). Design buffer
0.15 for baseline consistency — `baseline-v3.1.md` prices every row as
`est_design * 1.15` (the rule #215 and #218 settled). Familiar territory (#170,
#218 touched the same modules) → familiarity 1.0.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: cross-cutting-refactor design=0.1 impl=0.12
item: lua-neovim design=1.0 impl=0.4
item: lua-neovim design=1.0 impl=0.6
item: atlas-docs design=0.1 impl=0.08
item: ux-rename-iteration design=0.3 impl=0.08
item: milestone-review design=0.0 impl=0.14
design-buffer: 0.15
total: 4.30
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. `sdlc estimate-source` reports the calibration doc `[stale]` (ledger newer than the doc) — per-primitive hours are provisional.*

## Plan

Detailed plan: `workshop/plans/000227-question-highlighting-vanishes-while-typing-until-you-leave-insert-mode-plan.md`.
Single-pass work — one `sdlc close`, no milestones.

- [x] Split `highlight_structure.build` into shared per-row steps (`enter_row`/`leave_row`, markers, `derive`); behavior unchanged.
- [x] `replace` returns an aligned splice for every edit, exact when inert + converged; shape table + property test; see each guard fail.
- [x] Shared decoration test helpers (`tests/helpers/decoration.lua`).
- [x] Highlighter: fail-open `on_win`, splice in `on_lines`, debounced repair (injectable deferral), `on_reload` resync, splice-failure/row-count resync; delete `renderable`; `highlight_typing_spec.lua` per Done-when.
- [x] `make perf` reports `structure_splice` + `structure_rebuild`; record numbers and the one-rebuild-per-burst result in Log.
- [x] Atlas (`ui/highlights`, `chat/lifecycle`), `TOOLING.md`, traceability; full `make test`.
- [ ] Operator e2e check (list typing with Enter above a footer; fence + pause; markdown draft).

## Log

### 2026-09-09

Operator report with screenshot: `💬: Astrophotography.` and its block rendering
plain in insert mode, coloured again in normal mode.

Diagnosed by reading the path rather than reproducing: the mode change is
incidental, and the real trigger is any edit `M.replace` cannot apply
incrementally — which includes every newline, since it requires an unchanged
line count. The provider's `return false` on a dirty cache is what turns a stale
structure into a blank one.

### 2026-09-10 — design

- The blank-on-dirty behavior was a deliberate #170 trade-off (its plan: "Dirty
  redraw returns false"; `TOOLING.md` even documents "structural marker edits
  may suppress decorations during insertion"). `buffer_lifecycle` converges on
  `InsertLeave` but owns no `TextChangedI` handler — which is exactly why
  leaving insert mode "recolours". #170's hard gates (zero full reads per
  keystroke, one structure row per prose character) are kept.
- Measured (pure LuaJIT, perf fixture): full `build` 1.1 ms @1k, 5.5 ms @5k,
  21.8 ms @20k lines; a shallow two-array splice for an Enter at the top of the
  buffer 0.005 / 0.019 / 0.09 ms — ~250× cheaper. That is what makes an aligned
  splice per keystroke affordable and the Spec's "worth considering" fast path
  fall out of the fix (ARCH-CONSTRAINTS).
- Probes (headless nvim 0.11.7): `:checktime` reload with no `on_reload`
  handler **detaches** the attachment (only `on_detach` fires); with a handler,
  `on_reload` fires and already sees the new text. `:e!` detaches but fires
  `BufEnter` during the command, which rebuilds — no change needed. Emptying a
  buffer reports `on_lines 0 2 0` with `line_count == 1`. `nvim__redraw({buf,
  valid=true})` re-ran `on_win` but redrew 0 lines; `valid=false` redrew all.
- The backward `🧠:` lookahead's terminator list is identical to the module's
  `STRUCTURAL_TOKENS`; the refactor reuses the set instead of a second list
  (ARCH-DRY).
- Fresh-context plan review (ran the plan's code on a scratch copy): exactness
  rule held — no `reason == nil` counterexample in a 60k-edit run; property
  test exercised 974 exact / 2,626 approximate splices; refactored `build`
  matched the old one on 3,000 random docs; all 24 shape rows hand-verified.
  Fixed from its findings: Task 4's test-update list missed `renderable` at
  `highlighting_spec.lua:1282,1306` and two `prior` captures that a splice
  invalidates; two mutation steps named tests that would not go red; the
  `"structural"` contract said stale rows are only at/after the edit, but the
  `🧠:` lookahead reaches rows *above* it — pinned with a new unit test that
  isolates the inertness rule.
- `sdlc change-code`: plan-quality passed round 1 (no blocking; judge re-ran
  the probes and a 60k-edit exactness run). Three Minor findings, disposed in
  implementation rather than by editing the gated plan: (1) install the manual
  repair deferral file-wide in `highlighting_spec.lua` too, since that file
  pumps the loop (`vim.wait(700)`) while structural-edit tests would arm real
  250 ms timers — the helper moves to `tests/helpers/decoration.lua`; (2) add
  the new spec to **both** traceability entries that list
  `highlighting_spec.lua`; (3) `init.lua` pointers corrected (`:1714`,
  `:2872`). Ledger: `workshop/plans/…-plan-gate.md`.

### 2026-09-10 — implementation

- Task 1 (`build` split): unit 22/22, `highlighting_spec` 47/47,
  `fence_containment_spec` 2/2 green before and after; whitespace-only blank
  lines pinned first.
- Task 2 (`replace` splice): RED 6 → GREEN 25/25. Mutations, each seen red then
  reverted: convergence forced true → shape table + fence-width + property;
  `is_inert` always true → shape table + lookahead-above + property; marker
  derivation dropped from the splice → shape table + property.
- Task 4 (highlighter): the new typing spec was run against `main` in a
  throwaway worktree (seam stubbed) — all 14 red, the list-typing test at the
  first Enter with "ordinary typing must splice exactly" (the operator's repro).
  On this branch after Task 2 alone, 4 of them already passed: the splice makes
  Enter exact and the old `on_lines` installs it. GREEN 14/14 after Task 4;
  `highlighting_spec` 47/47 after updating the fail-closed pins (incl.
  `:1274,:1298` and the two `prior` captures); `perf_chat_typing_spec` 13/13
  unchanged. Mutations, each seen red then reverted: no `on_reload` → checktime
  test; no `nvim__redraw` → spy test + real-clock "0 lines redrawn"; no-op
  `arm_repair` → 6 repair/teardown/alignment tests; no row-count check →
  empty-buffer test; fail-closed `on_win` → the fail-open repair test.
- Found by the mutation step: under fail-closed, the real-clock test *also*
  failed with 0 lines redrawn — not a Neovim quirk (an isolated two-provider
  probe repainted 12/12 either way) but a stub leak: the failing test had
  replaced `vim.api.nvim__redraw` and died before its inline restore, so every
  later test in the file called a recorder. Every stub in the spec now goes
  through a cleanup stack that `after_each` unwinds; the fail-closed mutation
  now reddens exactly the one intended test. The real code repaints during
  `vim.wait` (17 lines before any explicit `:redraw`), i.e. the main loop
  flushes the invalidation on its own.
- Task 5 — `make perf` (exit 0, hard gates unchanged), median / p95 ms:

  | phase | 1,000 lines | 5,000 lines |
  |---|---|---|
  | `edit_total` (inclusive, one prose char) | 2.81 / 3.41 | 2.77 / 3.17 |
  | `decoration_redraw` | 0.30 / 0.37 | 0.35 / 0.80 |
  | `structure_splice` (one Enter) | 0.02 / 0.09 | 0.10 / 0.19 |
  | `structure_rebuild` (the one per burst) | 1.20 / 1.63 | 5.67 / 6.97 |

  One rebuild per burst on the 5,000-line chat is asserted in
  `highlight_typing_spec` (a fence + 21 keystrokes → 22 restarts, 1 pending,
  0 builds until it fires, then exactly 1); a plain-text burst with Enter
  schedules none.
- Task 6: atlas (`ui/highlights` new section, `chat/lifecycle`), `TOOLING.md`,
  traceability (both entries). The first full `make test` went red on one
  file — `single_source_sweeps_spec`: the plan's Core-concepts Name cells
  (`highlight_structure.build`, `M._set_repair_deferral`, `on_win`) were not
  the bare grep-able names its table↔code guards match (lesson #186). I had run
  only the targeted specs after Task 4; the arch suite runs only in the full
  `make test`. Cells renamed (`on_win` via `setup_buf_handler`, the function
  that registers it); guard 21/21.

## Revisions

### 2026-09-10 — planning (before implementation)

Reason: rendering the last good structure *unchanged* (Spec 1 as written)
misplaces every row-indexed value after a line-count edit — most visibly the
footnote footer, which would colour the lines being typed.
Delta: Spec 1 now requires an aligned splice (exact for inert edits); Spec 3
added (reload, splice failure, empty-buffer report, failed rebuild) as the
enumerated class; one Done-when bullet added for alignment and reload. The
"worth considering" incremental path is adopted in its inert-edit form, on the
measurement above rather than deferred.

### 2026-09-10 — estimate (after change-code)

Reason: estimate-quality (INFO) noted the +30% buffer breaks consistency with
`baseline-v3.1.md`, which prices every row at `est_design * 1.15` (settled on
#215 and #218), and that Task 1 (build split) and Task 7 (operator e2e round)
had no line item.
Delta: `estimate_hours` 3.95 → 4.30 — buffer 0.30 → 0.15; added
`cross-cutting-refactor` (0.1/0.12) and `ux-rename-iteration` (0.3/0.08);
provenance now carries the `[stale]` calibration caveat.
