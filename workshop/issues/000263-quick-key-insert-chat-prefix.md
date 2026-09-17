---
id: 000263
status: working
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-16
estimate_hours: 2.8
started: 2026-09-16T20:14:01-07:00
---

# Quick key to insert the chat question prefix at cursor

## Problem

Starting a new question in a Parley chat buffer means typing `💬:` — an emoji
the keyboard cannot produce. The operator works around this with a personal
clipboard shortcut, but end users have no discoverable quick key: they must
remember the emoji, copy-paste it, or reach for the OS emoji picker. A shipped
chat UI should provide the keystroke itself.

## Spec

Provide a **single quick key** that inserts the configured chat user prefix
(`config.chat_user_prefix`, default `💬:`) plus a trailing space at the
cursor:

- Works in **normal and insert mode**, buffer-local to Parley chat buffers.
  In normal mode, insert at the cursor and enter insert mode after; in insert
  mode, insert at the cursor without leaving insert mode.
- On an empty line or at column 0, insert at line start. Otherwise insert at
  the cursor position. If the line already starts with the prefix, do not
  duplicate it — move the cursor after it instead.
- Read the prefix from `config.chat_user_prefix` rather than hardcoding `💬:`,
  so an operator override is honored.
- Pick a chord that does not collide with existing Parley bindings — candidate
  under `<C-g>` (Parley's finder prefix) or a `<leader>` mapping; keep it
  chat-buffer-local, never global. Document it in help, atlas and which-key.
- No clipboard dependency. This is the end-user path that replaces the
  operator's clipboard workaround; any clipboard-based insertion stays a
  separate power-user affordance.

## Done when

- Pressing the quick key in a chat buffer inserts `💬: ` at the cursor (or
  moves after an existing prefix) with no clipboard or emoji picker involved.
- Works in both normal and insert mode, is undoable as one step, and leaves
  the cursor in insert mode ready to type the question.
- The inserted text follows `config.chat_user_prefix` when overridden.
- The keybinding is registered buffer-locally, documented in help/atlas/
  which-key, and shadows no existing Parley chord (verified against the
  keybinding registry).
- Focused tests cover insertion on an empty line, mid-line, an
  already-prefixed line, a non-default `chat_user_prefix`, and the normal/
  insert mode transitions.

## Plan

Durable design: `workshop/plans/000263-new-question-chord-plan.md`.

Single-pass atomic work — plain checkboxes, no `Mx`: one review boundary, at
`sdlc close`.

- [ ] Retire `chat_search`, freeing `<C-g>n` (`config.lua:372`,
  `keybinding_registry.lua:657-666`, `init.lua:2803-2808`).
- [ ] `lua/parley/new_question.lua` — the pure planner (`plan` +
  `is_empty_question`), reusing `exchange_clipboard`'s exchange-span and
  blank-line-seam arithmetic (ARCH-DRY), with its unit spec.
- [ ] `M.cmd.NewQuestion` + registry entry + `<C-g>n`/`<M-n>` buffer-local
  keymap for normal and insert mode.
- [ ] Integration spec against real keymaps: both modes, single undo, the
  no-duplicate second press, a non-default prefix, and the refusal while a
  response is streaming.
- [ ] Generalize the chord-shadowing guard from `<M-…>`-only to every chord
  plus prefix shadowing (ARCH-PURPOSE — the class the issue names).
- [ ] Atlas: `ui/keybindings.md`, `chat/lifecycle.md`, `traceability.yaml`.
  (No which-key integration exists in this repo; the registry is the single
  source and `<C-g>?` help is generated from it.)

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim              design=1.2  impl=0.40
item: cross-cutting-refactor  design=0.2  impl=0.10
item: smaller-go-module       design=0.15 impl=0.14
item: atlas-docs              design=0.1  impl=0.06
item: milestone-review        design=0.05 impl=0.14
design-buffer: 0.15
total: 2.8
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.*

Derivation notes:

- **`lua-neovim`** (v2 design 1–3, impl 0.5–1.5) — the feature proper: the pure
  planner, the command, the keymap and the integration spec. Design taken at
  1.2, near the low end: the chord audit and the structural semantics were
  settled in one session against a registry that is already a single source.
  Impl 1.0 → **0.40** at v3.1's 40% implementation scale.
- **`cross-cutting-refactor`** (0.2–1 / 0.2–0.5) — retiring `chat_search`.
  Low end: measured, the blast radius is exactly three sites and no test, doc
  or README references it.
- **`smaller-go-module`** (0–0.3 / 0.2–0.5) — "mirror or extend" is literally
  what widening the shadowing guard is: the detection loop already exists and
  gains a second axis. Impl slightly above mid (0.35 → **0.14**) because the
  plant-a-collision proof is the part that takes the thinking.
- **`atlas-docs`** (0.05–0.2 / 0.05–0.2) — two atlas sections plus
  traceability.
- **`milestone-review`** (0–0.2 / 0.2–0.5) — one boundary, at close. Design
  0.05: single-pass work needs no review design.
- **Step 2.5 (library availability):** N/A. No novel stack and nothing external
  to shim — the work is plugin-internal Lua against APIs already in use.
- **Step 3 (spec-quality):** the ×0.2 design discount was **not** applied. It
  credits a spec for design already front-loaded, but `sdlc actual` measures
  from the claim commit and so counts this session's brainstorm, chord audit
  and plan authoring as real hours. Discounting design the actual will still
  charge for would bias the row low and pollute the calibration.
- **Step 6 (buffer):** +15%, the thorough-plan-doc rate — a 780-line plan that
  carries the literal module, the registry entry and the command body.
- **Step 5 (familiarity):** left at 1.0 rather than credited down. The
  keybinding registry and `exchange_clipboard` are familiar (#262 closed in the
  same surface yesterday), but the insert-mode undo-grouping question is
  genuinely unexplored, and that is where impl risk actually sits.

## Log

### 2026-09-16

Filed from operator: "quick command to insert `💬:` — while I just have a
clipboard shortcut, as an end user facing [the product] needs to provide
that."

Captured first in `brain#000017` as `[pair / parley]`, because the sibling
repo write was sandbox-blocked; migrated here. The same need exists in
`pair`'s nvim draft pane — if that surface wants it too, file a sibling issue
in `pair` rather than widening this one. The operator's transcription of the
product name ("arle") matched no repo on disk; read as the end-user-facing
chat surface, which is Parley.

## Revisions

### 2026-09-16 — reframed from "insert prefix at cursor" to "new question after the exchange"

**Reason:** operator direction on picking the work up: *"I think we can use
`<C-g>n` if not conflicting, and it should create an empty question behind the
current exchange."*

**Delta:**

1. **Semantics.** The action is no longer "insert `💬: ` at the cursor
   position". It is **structural**: find the exchange the cursor is in, and
   open a new empty question *after* it. Cursor column no longer participates;
   the exchange boundary decides the insertion point. The old spec's
   already-prefixed rule survives in structural form — if the target exchange
   is already an empty unanswered question, focus it instead of creating a
   second one.
2. **Chord.** `<C-g>n` **was** taken: `chat_shortcut_search`
   (`keybinding_registry.lua:658`), a one-line wrapper over
   `/^💬:\|^🌿:`. Operator chose (of four options offered) to **retire
   `chat_search` and hand `<C-g>n` to the new action**, with `<M-n>` as the
   alt-family twin per the #217 convention. Plain `/` with the marker pattern
   remains available for what `chat_search` did.
3. **which-key.** The repo has no which-key integration; the keybinding
   registry is the single source and help is generated from it. "Document in
   which-key" reduces to one registry entry.
4. **Scope addition (ARCH-PURPOSE).** The Done-when asks the chord to "shadow
   no existing Parley chord (verified against the keybinding registry)". The
   existing guard (`keybindings_spec.lua:935`) only inspects `<M-…>` keys — it
   could not have caught this `<C-g>n` collision, which is the class the issue
   names. Generalize it to the whole chord space, including prefix shadowing
   (`<C-g>e` would delay `<C-g>em`/`<C-g>eh`), so the verification is a test
   rather than a manual audit. Measured: the registry has **0** collisions
   today under that wider rule, so the generalization lands green.

### 2026-09-16 — restated acceptance contract (plan-gate PQ-1)

**Reason:** the reframe above changed what gets built but left `## Spec` and
`## Done when` describing the pre-revision, cursor-position feature. Three of
the five original Done-when bullets are unsatisfiable by the structural design
on purpose — and `sdlc close` judges the diff against Done-when. Restating the
contract here rather than overwriting the originals, per AGENTS.md §1.

**Superseded.** These clauses of `## Spec` and `## Done when` no longer apply:

- *"On an empty line or at column 0, insert at line start. Otherwise insert at
  the cursor position."* — the cursor **column never participates**. The
  exchange boundary alone decides where the question goes.
- *"Pressing the quick key in a chat buffer inserts `💬: ` at the cursor."* —
  it inserts after the exchange the cursor is in.
- *"Focused tests cover insertion on an empty line, mid-line, an
  already-prefixed line…"* — there is no mid-line case and no column-0 case.
  The branches are `insert` and `focus`, and the axis the tests walk is *where
  the cursor's exchange is*, not where in a line the cursor sits.

**Done when (restated, authoritative):**

- Pressing `<C-g>n` (or `<M-n>`) in a chat buffer opens a new, empty question
  immediately **after the exchange the cursor is in** — not at the cursor
  column, not at end of file — and leaves the cursor in insert mode on it. No
  clipboard, no emoji picker.
- The new question's line is the configured `chat_user_prefix` followed by a
  space, so typing produces `💬: text` rather than `💬:text`. This holds for an
  overridden prefix, including one containing Lua-pattern magic characters.
- Its blank-line spacing is decided by `exchange_clipboard`, the same source
  `<C-g>V` pastes against — a pasted exchange and a new question are spaced
  identically.
- If the cursor's exchange is **already** an empty unanswered question, the
  chord focuses it instead of creating a second one. (An empty question in the
  *next* exchange is not adopted — the rule is about the exchange the cursor is
  in, so the landing spot never depends on off-screen content.)
- Works from normal **and** insert mode, and is one undo step: a single `u`
  after one press restores the buffer exactly.
- While a response is streaming into the target region, the chord **refuses
  visibly** — buffer unchanged plus a warning — rather than corrupting the
  transcript or silently doing nothing.
- The chord shadows no existing Parley chord, and that is **enforced by a
  test**: the shadowing guard covers every chord in the registry (not only the
  `<M-…>` family, which is why the original `<C-g>n` collision went unnoticed)
  and also catches prefix delay, over canonicalized key notation.
- `chat_search` is retired — config option, registry entry and callback all
  gone, with nothing else in the tree referencing it.
- Documented in `<C-g>?` help (via the registry, the single source) and in the
  atlas, including the ordering exception this entry makes to #214's
  "portable key leads" rule.
