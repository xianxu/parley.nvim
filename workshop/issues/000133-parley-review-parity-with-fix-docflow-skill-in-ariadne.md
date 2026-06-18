---
id: 000133
status: working
deps: []
created: 2026-06-17
updated: 2026-06-17
estimate_hours: 8.4
---

# parley review parity with fix/docflow skill in ariadne

## Problem

Parley's document review is a single marker-processor (`<C-g>ve` →
`skills/review`): it edits a doc from `🤖` *ready* markers in one batch, and
refuses entirely when there are no markers. It has no review **modes**, no
**free-form** instruction, no faster **ping-pong** trigger, and no **durable
record** of what each round changed or why (the per-edit `explain` lands only in
ephemeral gutter diagnostics and evaporates on the next run).

The goal is to bring review to **coding-agent parity** so parley can drive a
document review **independently** — borrowing the editing discipline of
ariadne's `fix` skill (reading frontier, attributed per-round history) but *not*
its git-branch machinery.

This **deliberately revises** the earlier "parley = marking layer; Claude Code
(`xx-fix`) resolves" split: review/resolution UX is back in scope for parley.
The one narrow exception is fact-check mode, which still hands resolution off to
the main agent.

## Spec

### 1. Review modes — one skill, modes as sub-markdown files

The existing `review` skill gains a `mode` arg. Each mode is a sub-file
`lua/parley/skills/review/modes/<name>.md` = **YAML frontmatter (behavior flags)
+ markdown prompt body**. The skill reads the flags to drive behavior and feeds
the body as the prompt.

Behavior flags: `scope` (`whole-doc` | `markers-only`), `deletions`
(`apply-with-gutter-why` | `propose-strike`), `frontier` (`on` | `off`).

The six modes and their **default** flags (the deletion column is a *starting
point* — we calibrate apply-vs-propose by using the tool in practice):

| Mode (menu label) | scope | deletions | frontier | notes |
|-------------------|-------|-----------|----------|-------|
| developmental | whole-doc | apply + gutter-why | off | restructure freely |
| line editing | whole-doc | propose (strike) | on | |
| copy editing | whole-doc | propose (strike) | on | |
| proofreading | whole-doc | apply (mechanical) | on | typos/punctuation |
| fact-check | whole-doc, read-only | — inserts `🤖{}` findings only | on | resolution handed to Claude Code (main agent) |
| free-form | inferred | inferred | inferred | instruction **required** (non-empty) |

**Reading frontier** (from `fix`): when `frontier: on`, everything *above* the
topmost `🤖[]` human marker is treated as **settled** — confine edits/findings to
the frontier and below; the frontier descends across rounds. `frontier: off`
(developmental) may touch the whole doc.

### 2. No-marker general review

When a doc has **no markers**, modes still run (whole-doc modes operate on the
full document). This is the headline new capability — today review aborts with
"no markers found". Edit orientation (we keep parley's existing mechanisms):

- **additions / in-place rewrites** → applied + `DiffChange` highlight + INFO
  gutter diagnostic carrying the `explain`.
- **deletions** → per the mode's `deletions` flag: either applied with a gutter
  "why" diagnostic at the join point, or proposed as a `🤖~old~{new}` strike
  marker (review-convention) for the human to accept/reject.

### 3. The review menu (UI)

A composite float modeled on `float_picker`'s two-window layout (the
`chat_finder` pattern — list on top, input below):

- **top** = the six-mode **selector**, sticky-preselected to the last-used mode.
- **bottom** = a **multi-line, normal editable buffer** (proper vim editing, per
  the original ask) for free-form instruction — *not* the single-line
  `buftype=prompt` query the picker uses today, and *not* a list filter.
- Mode selection **and** typed instruction are both sent (a mode plus extra text
  is fine). Free-form mode requires non-empty instruction.

Likely a small purpose-built component reusing `float_picker`'s layout helpers
(`compute_layout`, …) rather than overloading the prompt path.

### 4. Bindings

> **Superseded (acceptance test, see plan Revisions 2026-06-18):** `<M-o>` opens
> the **skill picker** (review is one skill); `<M-CR>` is the direct review
> trigger (opens the review-mode menu). The original §4 text below predates that.

- `<M-o>` — open the review menu, **in addition to** the existing `<C-g>s`
  skill picker.
- `<M-CR>` — in a markdown doc: (re)open the menu **pre-selected** to the sticky
  mode (Enter/`<M-CR>` fires; free text always available for extra instruction).
  **Always works** — if not yet in review, it enters review (no session gate).
  No conflict: `<M-CR>` is chat-respond only in *chat* buffers; it is free in
  markdown artifact buffers.

### 5. Submission behavior (decoupled from quickfix)

- The pending-`{}`-marker **quickfix surfaces on save** (`BufWritePost`), not on
  submission.
- **Submission is allowed even with unaddressed `{}` markers** — the agent
  simply skips non-ready markers (last section `{}`) and processes only ready
  ones (last section `[]`). This **reverses** today's behavior, where
  `run_via_invoke` refuses to submit while `{}` markers are pending.

### 6. Decorations — live cue (behavior B)

After a round, highlights (`DiffChange` extmarks) + INFO diagnostics **ride** via
extmark gravity and **persist until the next round or explicit dismiss** (parley
already clears at each round start). Rationale: edits are *local* but decorations
are *doc-wide* — keep the visual cue for the other changed regions while you edit
one place. We accept that the edited region's decoration goes soft-stale.

### 7. History — self-contained journal sidecar (replaces git/docflow)

Git/branch journaling (the docflow full-mirror) is **dropped**:

- `scripts/docflow.sh` is a dangling symlink into `../../ariadne/` that also
  `source`s ariadne's `lib.sh` → **not portable** to a standalone plugin install.
- A `review/<slug>` branch moves the **whole working tree** — disruptive inside
  nvim, where a doc is one file in a larger repo.
- This workflow **expects external edits** (Claude Code resolving / editing the
  doc), which **invalidate** nvim's persistent `undofile`.
- vim's **native undo** already covers in-session undo/redo for free.

Instead: a **self-contained, pure-Lua markdown journal sidecar beside the doc**
(e.g. `<doc>.parley-journal.md`), tracked in git **alongside** the doc (no
gitignore — the review history travels with the document). Per round it stores:
base snapshot (round 0) + per-round **unified diff** (`vim.diff()`), mode, side,
per-edit **explanations** (rationale), the **decoration set** (highlight ranges +
diagnostic messages), and a timestamp. It can also **detect external drift**
(compare last-recorded state to disk on open).

This captures docflow's *value* (attributed per-round diffs + rationale) without
its git-branch *mechanism*. Durable revisit = **open the journal**; in-session
text time-travel = **vim native undo**.

The journal must reconstruct any round's text (base + replayable diffs — git's
model). Recording ships first; "revert to round N" (diff application) can follow.

### 8. Deferred / v2

- **Active in-buffer undo-projection**: re-render a past round's decorations when
  the buffer content **exactly matches** a stored round's snapshot
  (content-projection — O(rounds) hashes, one check per `TextChanged`, no
  per-keystroke storage). The journal already stores decoration sets, so this is
  a clean future add. Not in v1.
- **Cross-session sticky mode** (persist last-used across nvim restarts; in-session
  recall already exists via `float_picker`).
- **"Show round N"** command — reconstruct a round's text + decorations from the
  journal.

### Seed — original ask (verbatim)

1. bind `alt+o` to skill open, for easier access.
2. last-used skill selected by default.
3. review tool supports free-form instruction (location-neutral, e.g. "give me
   some ideas", "expand the sketches into a document"); plus a menu to select a
   stage of review, each tied to specific prompting; free-form is the escape.
4. when there are no markers, general review can be performed.
5. borrow from `../ariadne/construct/local/fix`: settling top-to-bottom, auto
   commit per back-and-forth.
6. faster shortcut for ping-pong (`alt+return`, like `pair`/`parley` chat mode):
   in an active review, it triggers the next round, or pops the menu with a
   sticky selection.
7. review modes (the menu): developmental (brainstorming), line editing, copy
   editing, proofreading, review-of-fact (fresh-context 2nd-agent), free-form.
8. an edit box below the menu — a normal buffer with good editing; mode +
   typed text both sent.
9. `alt+return` also surfaces the quickfix of items needing attention.

## Done when

- `<M-o>` opens a composite review menu (mode selector + multi-line instruction
  editor); the last-used mode is pre-selected.
- The `review` skill takes a `mode` arg backed by per-mode sub-files
  (frontmatter flags + prompt body); all six modes present and selectable.
- A doc with **no markers** runs a general review per the selected mode
  (whole-doc modes edit the full document); a doc with markers still processes
  ready markers as before.
- Edits orient the user: additions highlighted + gutter `explain`; deletions per
  the mode's flag (gutter-why or `🤖~old~{new}` strike marker).
- `<M-CR>` (re)opens the menu pre-selected to the sticky mode and runs the next
  round; works even when not yet in review; submission proceeds even with
  unaddressed `{}` markers.
- The pending-`{}` quickfix surfaces on **save**, decoupled from submission.
- Each review round appends to a self-contained markdown journal sidecar beside
  the doc (base + diff + mode + rationale + decoration set + timestamp); no git
  or branch machinery; the record survives across nvim sessions.
- Round decorations persist (ride) until the next round or explicit dismiss.
- Tests cover: mode loading + flag parsing, no-marker general review,
  submission-with-pending-`{}`, journal append/read + drift detection, and
  addition/deletion (strike) rendering.

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim       design=0.4 impl=1.0
item: lua-neovim       design=0.3 impl=1.0
item: lua-neovim       design=0.4 impl=1.0
item: lua-neovim       design=1.0 impl=1.5
item: milestone-review design=0.0 impl=0.3
item: milestone-review design=0.0 impl=0.3
item: milestone-review design=0.0 impl=0.3
item: milestone-review design=0.0 impl=0.3
item: lua-neovim       design=0.3 impl=1.0
item: milestone-review design=0.0 impl=0.3
item: lua-neovim       design=0.2 impl=0.8
item: milestone-review design=0.0 impl=0.3
item: lua-neovim       design=0.3 impl=1.0
item: milestone-review design=0.0 impl=0.3
design-buffer: 0.30
total: 13.2
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v2.md` against `baseline-v2.md`. Method A only.*

Mapping: the four `lua-neovim` items are M1 (modes engine), M2 (flexible review
flow), M3 (journal sidecar), M4 (composite menu UI). Design carries the **×0.2
spec-quality discount** (the durable plan pre-resolves decisions) — except M4 at
×0.5, since composite-float interaction design partly emerges in
implementation. The four `milestone-review` items are the M1–M4 review
boundaries. M2's impl was lifted 0.8→1.0 (estimate-quality judge, #133): it's
control-flow rework (resubmit-loop terminal logic) + a new deletion render path,
not additive work. **M5** (added in acceptance test): decoration projection for undo/redo coherence
— one more `lua-neovim` (design=0.3, ×0.5 — design partly emerges) + its review
boundary. **M6** (acceptance test): review-diagnostic display — wrapped inline
why + cursor auto-show + toggle (small focused `lua-neovim`, design=0.2) + its
boundary. **M7** (acceptance test): detached progress bar (reusable long-op
feedback surface) (design=0.3 ×0.5) + its boundary.
`recomputed = Σdesign(2.9)×1.30 + Σimpl(9.4)×1.0 ≈ 13.2`. Unit:
build-effort (design + AI-impl); diverges from `sdlc actual` (operator-attention).

## Plan

Detailed, executable plan: **`workshop/plans/000133-review-modes-journal-plan.md`**
(authored via `superpowers-writing-plans`, fresh-eyes reviewed — see the
2026-06-18 Log entry). Four milestone review boundaries:

- [x] M1 — Modes engine: `Mode` pure parser + 6 mode sub-files + `skill_dir` injection + review `source(ctx)` composition (reuses `skill_invoke`).
- [x] M2 — Flexible review flow: no-marker general review, submission decoupled from pending `{}` (quickfix on save), deletion gutter-why + decoration ride-until-next-round (B).
- [x] M3 — Journal sidecar: pure serialize/parse/diff/drift + thin IO append/read + `on_done` payload widening + wired into the round.
- [x] M4 — Composite review menu (mode selector + multi-line instruction editor) + `<M-o>`/`<M-CR>` bindings + sticky mode; manual e2e.
- [x] M5 — Decoration projection (undo/redo coherence): snapshot decorations per content-state, re-render on undo/redo, ride forward edits (B). Added during acceptance test.
- [x] M6 — Review-diagnostic display: hard-wrapped inline why + `:ParleyShowDiagnostics` toggle + auto-show when cursor in the edit's region (virtual_lines current_line, scoped). Added during acceptance test.
- [x] M7 — Detached progress bar: reusable floating bar (spinner + elapsed) for long-running ops; review shows it during a round. Added during acceptance test.

## Log

### 2026-06-17 — session summary

Brainstormed the full design with the operator and converged the Spec above.
Key decisions landed: (1) **scope revision** — parley drives review
independently now (memory + the project split note updated); (2) **one** review
skill with modes as sub-markdown files (frontmatter flags + prompt body), six
modes; (3) **no-marker general review** is the headline new capability;
(4) deletions handled per-mode (apply+gutter-why vs `🤖~old~{new}` strike),
calibrated in practice; (5) fact-check is mark-only and hands resolution to
Claude Code; (6) **drop git/docflow** (dangling symlink, whole-tree branch
churn, external edits invalidate `undofile`) in favour of a **self-contained
pure-Lua journal sidecar** beside the doc; vim native undo owns in-session
time-travel; (7) decorations **ride until next round** (behavior B) so doc-wide
cues survive a local edit; (8) active undo-projection, cross-session sticky
mode, and "show round N" deferred to v2.

Grounding checked against current code: `skills/review/{init,SKILL}.lua`,
`skill_invoke.lua`, `skill_picker.lua`, `skill_registry.lua`, `float_picker.lua`
(two-window layout + session recall), `skill_render.lua` (DiffChange highlight +
INFO diagnostics, no deletion path today). Confirmed `<M-CR>` is chat-respond
only in chat buffers (free in markdown docs), and parley ships no git-commit
runtime machinery.

Next: `sdlc start-plan` → durable plan in `workshop/plans/`.

### 2026-06-18
- 2026-06-18: closed M7 — make test EXIT=0 (116 spec files; lint 0/0 in 218 files). M7: reusable detached progress bar (pure frame/format 2 unit; float/timer lifecycle 2 integration) wired into skill_invoke start/stop with the generation guard (1 integration). Review shows a spinner+elapsed bar during the round.; review verdict: FIX-THEN-SHIP
- 2026-06-18: closed M6 — make test EXIT=0 (114 spec files; lint 0/0 in 215 files). M6: skill_render.wrap + region-anchored wrapped diagnostics (9 unit), diag_display toggle scoped to parley ns (2 integration), :ParleyShowDiagnostics + default-on. Cursor-region auto-show via virtual_lines current_line.; review verdict: FIX-THEN-SHIP
- 2026-06-18: closed M5 — make test EXIT=0 (113 spec files; lint 0/0 in 213 files). M5: skill_render snapshot/apply_snapshot (7 unit), projection module record/decide/project (3 integration), wired into round on_done (19 flow). Undo/redo re-render style coherently; forward edits ride (B).; review verdict: FIX-THEN-SHIP
- 2026-06-18: closed M4 — make test EXIT=0 (112 spec files; lint 0/0 in 211 files). M4: composite review_menu (mode selector + multi-line instruction editor, sticky mode, 6 tests) + <M-o>/<M-CR> bindings via setup_keymaps; float_picker.compute_layout exported; sidecar excluded from attachment.; review verdict: FIX-THEN-SHIP
- 2026-06-18: closed M3 — make test EXIT=0 (111 spec files; lint 0/0 in 209 files). M3: pure journal serialize/parse/diff/drift (6 unit), sidecar IO append/read/drift (4 integration), wired into review on_done + widened skill_invoke payload + pure should_resubmit (16 flow + 4 skill_invoke).; review verdict: FIX-THEN-SHIP
- 2026-06-18: closed M2 — make test EXIT=0 (109 spec files; lint 0/0 in 206 files). M2: no-marker general review + submission decoupled from pending {} (10 flow tests), deletion gutter-why + highlight empty-skip + dismiss + decoration ride (6 render tests).; review verdict: SHIP
- 2026-06-18: closed M1 — make test EXIT=0 (109 spec files pass; lint 0/0 in 206 files). M1: mode.parse+directives (8 unit), load/list+6 mode files+source composition (6 integration), skill_dir injection (10 provider tests). Legacy marker-only review preserved.; review verdict: FIX-THEN-SHIP

Drafted the durable plan (`workshop/plans/000133-review-modes-journal-plan.md`,
4 milestones) and ran a fresh-eyes plan review — caught 1 blocking issue (the
plan falsely claimed `skill_invoke`'s `on_done` exposes `original`; it passes
only `{ok,applied,calls,results}`) + 4 important under-specs; all folded in.

Corrected `estimate_hours` 14 → **8.2**, derived via `estimate-logic-v2` (was a
free-floating guess before). Added the `## Estimate` block. Note: parley's
installed `sdlc` predates #117, so `change-code` won't reconcile the block here
yet — the derivation is done by hand per the methodology.
