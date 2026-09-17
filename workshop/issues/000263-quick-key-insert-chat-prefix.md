---
id: 000263
status: codecomplete
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-16
estimate_hours: 2.04
started: 2026-09-16T20:14:01-07:00
actual_hours: 4.31
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

- [x] Retire `chat_search`, freeing `<C-g>n` (`config.lua:372`,
  `keybinding_registry.lua:657-666`, `init.lua:2803-2808`).
- [x] `lua/parley/new_question.lua` — the pure planner (`plan` +
  `is_empty_question`), reusing `exchange_clipboard`'s exchange-span and
  blank-line-seam arithmetic (ARCH-DRY), with its unit spec.
- [x] `M.cmd.NewQuestion` + registry entry + `<C-g>n`/`<M-n>` buffer-local
  keymap for normal and insert mode.
- [x] Integration spec against real keymaps: both modes, single undo, the
  no-duplicate second press, a non-default prefix, and the refusal while a
  response is streaming.
- [x] Generalize the chord-shadowing guard from `<M-…>`-only to every chord
  plus prefix shadowing (ARCH-PURPOSE — the class the issue names).
- [x] Atlas: `ui/keybindings.md`, `chat/lifecycle.md`, `traceability.yaml`.
  (No which-key integration exists in this repo; the registry is the single
  source and `<C-g>?` help is generated from it.)

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim              design=0.45 impl=0.60
item: cross-cutting-refactor  design=0.05 impl=0.10
item: smaller-go-module       design=0.10 impl=0.18
item: atlas-docs              design=0.05 impl=0.07
item: milestone-review        design=0.05 impl=0.18
design-buffer: 0.30
total: 2.04
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.*

### Revision — 2026-09-16, after the estimate-quality check

The first pass totalled **2.8** with 1.955h (70%) in the design column. That was
wrong in a way that was **observable at the time**, and the fix moves hours from
design into implementation rather than trimming the total much (2.8 → 2.04).

- **Design was budgeted for a phase that was already over.** `sdlc actual
  --issue 263` reported **0.65h** at the moment of estimating, with the plan
  written, three reviews disposed and the plan gate cleared. Budgeting another
  ~1.3h of design against that is implausible. The first pass reasoned correctly
  that the measurement window *charges* design (which is why the ×0.2 Step-3
  discount stays declined) but never asked *how much design was left* — and that
  was one command away. Design subtotal is now **0.70**, i.e. roughly what has
  been spent plus a small residue for decisions still open during implementation
  (chiefly the insert-mode undo grouping).
- **v2.1 binds Step 3 and Step 6; the first pass split them.** §Step 6 says
  plainly: if Step 3 was ×1.0, *keep the v2 +30%*. The +15% rate is the reward
  for having *taken* the ×0.2 discount, and taking both the undiscounted design
  and the discounted buffer is picking the favorable half of each rule. Buffer
  is now **0.30**.
- **Implementation was light.** `lua-neovim impl` carried four plan tasks —
  planner, command, keymap, and a ten-case integration spec — on a table-mid
  value. It now sits at **0.60**, the top of the v2 range (1.5) at v3.1's 40%
  scale. `smaller-go-module impl` moves 0.14 → **0.18**: the widened guard is
  not only "a second axis on an existing loop", it adds key canonicalization
  (`keytrans` ∘ `replace_termcodes`) and two plant-a-collision proofs.
- **Calibration context.** The two nearest ledger rows on this surface both
  under-estimated: `parley.nvim#262` (same registry/`exchange_clipboard`
  surface, closed yesterday) est 2.57 vs actual 4.84 — ratio 0.53 — and
  `parley.nvim#240` at 0.66. Every `impl=` above is therefore at or near the top
  of its legal v3.1 range rather than at table-mid.
- **This row is a clean calibration point.** Single-session, sequential, no
  subagent fan-out, so the within-session parallelism gap between a v3.1
  estimate and `sdlc actual` does not apply — estimate and actual are directly
  comparable here.

Derivation notes (carried forward, corrected):

- **`lua-neovim`** (v2 design 1–3, impl 0.5–1.5) — the feature proper. Design
  0.45 rather than 1.2: the chord audit, the structural semantics and the
  1089-line plan are already written and measured.
- **`cross-cutting-refactor`** (0.2–1 / 0.2–0.5) — retiring `chat_search`.
  Low end, and confirmed generous: the blast radius is four grep lines across
  three sites, with nothing outside `workshop/` referencing it.
- **`smaller-go-module`** (0–0.3 / 0.2–0.5) — "mirror or extend" fits the
  widened shadowing guard: the detection loop and `scopes_overlap` exist.
- **`atlas-docs`** (0.05–0.2 / 0.05–0.2) — four atlas edits across two files.
- **`milestone-review`** (0–0.2 / 0.2–0.5) — one boundary, at close.
- **Step 2.5 (library availability):** N/A. No novel stack, nothing external to
  shim — plugin-internal Lua against APIs already in use.
- **Step 3 (spec-quality):** ×1.0. The discount credits a spec for design
  front-loaded *outside* the measured window; here `sdlc actual` runs from the
  claim commit and charges the design directly, so discounting it would bias the
  row low. Paired with the +30% buffer, per §Step 6.
- **Step 5 (familiarity):** 1.0, not credited down. The registry and
  `exchange_clipboard` are familiar (#262), but insert-mode undo grouping is
  genuinely unexplored — no existing Parley chord both edits the buffer and
  returns to insert — and that is where the impl risk sits.

## Log

### 2026-09-16
- 2026-09-16: closed — Round 3 fixes. BR-9 (Critical, a round-2 regression): exchange_index_at had been hoisted between get_paste_line{}s @param block and its signature; reordered so each function owns its doc, superseded_comment_spec 9/9 green. BR-10: chat_context reads buffer/window/logger so it moved from the plan{}s Pure entities to Integration points. duplicated-command-preamble (3rd occurrence) answered with a RULE not a patch: measured prevalence 4 init.lua + 2 chat_respond.lua + 1 partial exporter.lua + 1 deliberate exclusion (delete_entity_range shares entity_textobj.parsed_for with the text objects on purpose); lua/parley/chat_context.lua now owns the not_chat->find_header_end->parse_chat sequence tree-wide, two-phase because respond_all interleaves its batch precondition between the gates, with each caller keeping its own wording since messages and failure semantics differ. doc-claim-contradicts-code (2nd occurrence) answered with a derivation test: keybindings_spec now derives the 3-3 lead split from the registry and pins both sides, plus a flip case proving it reads keys[1] rather than membership. Verified: keybindings 80/80, new_question 14 unit + 15 integration, chat_respond 27/27, batch_respond 16/16, batch_lifecycle 10/10, topic_gen 9/9, exchange_clipboard 31/31, entity_range 47/47, superseded_comment 9/9, buffer_mutation 10/10, single_source_sweeps 21/21, documentation 4/4, make lint 0/0 across 628 files. branch_child_spec failed once under 8-way parallel make and passes 62/62 three times serially (known parallel-load class); perf_document_spec same known class; parley_harness_golden_spec 11/11 red at branch point bbe05eef and here alike, pre-existing.; review verdict: FIX-THEN-SHIP

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

### 2026-09-16 — implemented

`<C-g>n` / `<M-n>` → `:ParleyNewQuestion`. `chat_search` retired (its blast
radius really was the four grep lines the plan predicted).

**Design that survived contact.** `lua/parley/new_question.lua` is a pure plan
value; the whole structural decision is `exchange_clipboard.get_paste_line`
plus `build_paste_lines`, so `<C-g>n` and `<C-g>V` cannot drift apart on
spacing (ARCH-DRY). `M.cmd.NewQuestion` is the IO shell and writes through
`buffer_edit`, which is what gives the streaming refusal for free (ARCH-ORDER).

**The plan's stated risk did not materialize.** Insert-mode undo grouping was
called out as the one behavior unreadable from existing code, with `vim.schedule`
named as the fallback. `stopinsert`-then-edit worked first try: a single `u`
restores the pre-press buffer byte-for-byte. All five "open set" cases passed on
the first run.

**What actually failed first** was a fixture, not the design: a 4-line
header-only chat is rejected by `not_chat` (`init.lua:1816`, under 5 lines), so
the chord was simply never bound in it. Six-line fixture, green.

**Tests.** `tests/unit/new_question_spec.lua` 14/14 (cursor in every branch,
`%-Q.:` magic-character prefix, tab normalization, the recorded decision that a
*neighbouring* empty question is not adopted). `tests/integration/new_question_spec.lua`
11/11 through real keymaps via `Registry.key_for` + `maparg().callback`, with
`startinsert` asserted through a `vim.cmd` spy that outlives the callback —
`vim.fn.mode()` cannot work here because `startinsert!` from a mapping callback
is scheduled. Question counts come from a plain `vim.startswith` scan, never a
re-parse (#262 lesson).

**Guard generalized (ARCH-PURPOSE).** `keybindings_spec.lua`'s collision guard
inspected only `<M-…>` keys and so could not have caught this `<C-g>n`
collision. Now covers every chord plus prefix delay, over canonicalized
notation, with `modes_overlap` added because widening past the alt family pulls
in `{o,x}`-only text objects and normal-only `gf`/`gP`. Measured **0 collisions
/ 0 prefix shadows**; both plant-a-collision proofs bite. 78/78.

**Pre-existing failures on `main`, not from this branch** — both reproduced at
the branch point (`bbe05eef`) in a detached worktree:
- `tests/unit/parley_harness_golden_spec.lua` — **11/11 failing at base and on
  this branch alike** (system-prompt golden payload drift).
- `tests/integration/perf_document_spec.lua` — flaky ~50% *serially*, dying
  silently mid-run with no assertion output; 1 of 4 failed at base too. Same
  "dies silently" class `lessons.md` records for three other specs.

Everything else in `make test-unit` / `make test-integration` passes.

### 2026-09-16 — boundary review round 1 (FIX-THEN-SHIP) disposed

8 findings, 2 blocking. Full disposition in the plan's `## Revisions`; the
review itself is `workshop/plans/000263-quick-key-insert-chat-prefix-close-review.md`.

- **BR-1** the "one undo step" clause was asserted for the normal-mode press
  only — the mode where the insert path's `stopinsert` plays no part. The
  integration spec is now parameterized over both modes, so a clause naming two
  modes is asserted in both by construction. The reviewer's counterfactual also
  showed `stopinsert` is *not* what provides the undo scope
  (`document.apply_user`'s transaction is); the comment no longer claims it.
- **BR-2** "the one place the portable key does not lead" was false. Measured:
  the split is even, **3–3** — `<C-g>`-leading are `outline`, `chat_drill_in`,
  `new_question`; alt-leading are `open_file`, `branch_ref`, `chat_prune`.
  Corrected in atlas, `config.lua` and the registry comment.
- **Minors fixed:** `chat_context(what)` extracted and all four commands
  migrated (the preamble was on its 4th verbatim copy); the refusal test
  relabelled as the double it is, with the measured evidence for why the two
  realer routes don't work; stale `--verified` counts corrected; the atlas
  paragraph that swallowed a pre-existing sentence split back out;
  header-cursor placement now tested *and* documented.
- **Deliberately deferred:** the refusal-UX divergence (this command reports,
  twelve siblings raise) → **#265**, with the real-generation fixture the
  proper test needs. Unifying 13 call sites' error semantics at this close is a
  separable extension, not #263's purpose.

Integration spec now 14/14 (was 11/11), unit 14/14, lint 0/0 across 627 files.
Prune/cut/paste verified after the refactor: `topic_gen_spec` 9/9,
`branch_child_spec`, `entity_textobj_spec`, `chat_move_spec` all green.

### 2026-09-16 — boundary review round 2

Round 2 confirmed BR-1/BR-2 fixed (re-ran integration 14/14 including the
insert-mode undo) and raised three items. The one that matters is **M2: the
second finding in the `duplicated-command-preamble` family in consecutive
rounds** — extracting `chat_context` had fixed the *site* and half-swept the
class. Three callers still re-read the cursor instead of `ctx.cursor_line`, and
`new_question` carried its own copy of the exchange-scan already inside
`get_paste_line`. Both swept now, with `exchange_clipboard.exchange_index_at`
as the single owner of "which exchange is the cursor in".

Also: `assert(plan.row)` moved above the buffer write (it guarded nothing
after it); a real insert-session case added via `nvim_feedkeys` after round 2
measured that `vim.cmd("startinsert")` in busted does **not** change `mode()`;
all 40 plan steps ticked.

Integration 15/15, unit 14/14, keybindings 78/78, exchange_clipboard 31/31,
entity_range 47/47, topic_gen 9/9, buffer_mutation 10/10, sweeps 21/21,
documentation 4/4, lint 0/0.

### 2026-09-16 — boundary review round 3 (REWORK) disposed

8 disposed, 4 new, 3 repeat families. Round 3 is where instances stopped being
the point; full disposition in the plan's `## Revisions`.

- **BR-9 (Critical)** — a regression from round 2: hoisting `exchange_index_at`
  put it between `get_paste_line`'s `@param` block and its signature, so the
  doc documented the wrong function. `superseded_comment_spec` caught it. Round
  2's verification ran the specs for the behavior I changed, not the arch suite
  that guards the *kind* of edit I made.
- **BR-10** — `chat_context` was listed under the plan's **Pure entities** while
  reading the buffer, window and logger. It is an integration point; table
  corrected and the new module's three functions listed.
- **`duplicated-command-preamble`, 3rd occurrence → rule.** Measured prevalence:
  4 in `init.lua` (migrated), **2 in `chat_respond.lua`** that a file-local
  helper could never reach, 1 partial in `exporter.lua`, 1 deliberate exclusion
  (`delete_entity_range`, which shares `entity_textobj.parsed_for` with the text
  objects on purpose). The sequence now has **one owner reachable from any
  module** — `lua/parley/chat_context.lua` — and the caller keeps its own
  wording. Two-phase, because `respond_all` interleaves its batch check between
  the gates.
- **`doc-claim-contradicts-code`, 2nd occurrence → rule.** The 3–3 lead split is
  no longer hand-maintained prose: `keybindings_spec` derives it from the
  registry and pins both sides, plus a case that flips one entry's key order to
  prove the derivation reads `keys[1]` (what help renders) rather than
  membership.

keybindings **80/80**, chat_respond 27/27, batch_respond 16/16, batch_lifecycle
10/10, new_question 14 unit + 15 integration, superseded_comment 9/9, lint 0/0
across 628 files. `branch_child_spec` failed once under 8-way parallelism and
passes 62/62 three times serially — the known parallel-load class.
