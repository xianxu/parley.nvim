---
id: 000214
status: working
deps: [#212]
github_issue:
created: 2026-09-02
updated: 2026-09-05
estimate_hours: 3.83
started: 2026-09-05T22:03:29-07:00
---

# audit and curate the default keybinding surface

## Problem

Parley claims a large share of the user's keyspace by default, and the claim was
never curated — bindings accumulated as features were added. Today
`lua/parley/config.lua` ships **65 default shortcuts** across six prefix
families:

| Family | Count | Keys |
|---|---|---|
| `<C-g>` chat/parley | 24 | the core chat surface |
| `<C-n>` notes | 4 | `c f h r` |
| `<C-y>` issues | 6 | `c f g i s x` — ariadne |
| `<C-j>` vision | 6 | `ec ed f n o v` — ariadne |
| `<leader>` | 6 | `cc cC cf cl cL` **plus `fo`, which maps oil.nvim** — a plugin parley never requires |
| other | 19 | `gf`, `gP`, `<M-CR>`, `<M-o>`, and finder-local keys |

Three separate defects sit underneath that count.

**1. Ten bindings cannot be rebound or disabled at all.** The registry
(`keybinding_registry.lua`) holds 78 entries, 68 with a `config_key` the user can
override and **10 registry-only**:

```
interview_start         <C-n>i            note
interview_stop          <C-n>I            note
note_template           <C-n>t            note
outline                 <C-g>t, <M-t>     parley_buffer
branch_ref              <C-g>i            parley_buffer
chat_toggle_web_search  <C-g>w            chat
chat_drill_in           <C-g>q, <M-q>     parley_buffer
chat_accept_drill_in    <M-a>             parley_buffer
chat_reject_drill_in    <M-r>             parley_buffer
md_delete_file          <C-g>d            markdown
```

`<M-q>` is a headline feature and `md_delete_file` **deletes a file** — neither
can be moved off a colliding key.

**2. Four bindings are made outside the registry entirely**, so they appear in no
audit surface, in no `<C-g>?` help, and in no config:

- `u` and `<C-r>` are shadowed in chat buffers (`init.lua:2213,2216`)
- `<CR>` is rebound in insert mode by spell typeahead (`spell.lua:168`) and again
  by interview mode (`interview.lua:85`) — colliding with cmp/blink, which nearly
  every Neovim user has on `<CR>`

**3. The core/peripheral line was never drawn.** Ariadne workflow keys
(`<C-y>*`, `<C-j>*`), the `<leader>` copy helpers, and an oil.nvim mapping all
ship with the same default status as `<C-g>c`.

## Spec

Draw an explicit line between the bindings parley claims by default and the ones
a user opts into, and make everything it does claim rebindable and visible.

**Policy to decide and then encode:**

- **Core default set** — small enough to justify itself key by key. The
  candidates are the `<C-g>` chat surface plus `<M-CR>` and `<M-q>`; each survives
  only if it is defensible as a *chat product* binding.
- **Opt-in set** — everything a user should turn on deliberately. Per the
  operator's direction, ariadne bindings (`<C-y>*`, `<C-j>*`) are configured
  explicitly rather than defaulted, **even inside an ariadne repo** — this goes
  further than #212, which only stops binding them where the feature cannot work.
  The `<leader>` maps belong here too: `<leader>` is the user's namespace, and
  `<leader>fo` maps a plugin parley does not depend on.
- **Never-claimed set** — keys parley should not shadow at all, or should shadow
  only with an explicit opt-in: `u`, `<C-r>`, and `<CR>` in insert mode.

**Structural work, independent of where the policy lands:**

- Every binding parley registers must have a `config_key`, so it can be
  rebound or disabled. Ten currently cannot (`ARCH-PURPOSE`: the registry is the
  single source only if *every* binding derives from it — ten exceptions make it
  a partial source).
- Move the four off-registry bindings into the registry, or document why they
  cannot be. A binding invisible to `<C-g>?` and to config is the worst case: it
  shadows a core Vim key, and the user has no way to find or change it
  (`ARCH-DRY`).
- Provide one documented switch to disable the whole default keymap for users who
  bind everything themselves.
- Resolve the redundant doubles (`<C-g>t`/`<M-t>`, `<C-g>q`/`<M-q>`) — keep both
  deliberately or drop one.
- Review the `<M-*>` family for terminal portability; alt-chords are the least
  reliable class shipped, and `<M-CR>` is already split across two registry
  entries because one entry could not express its key/mode matrix
  (`config.lua:326-329`).

Ordering: this depends on #212, which establishes context-filtered registration.
This issue sets the *policy* that mechanism enforces; doing them in the other
order means reworking the same call sites twice.

## Enumeration (2026-09-05)

Measured from `keybinding_registry.M.entries` + `config.lua`, not counted by
hand. **81 registry entries** (the Problem section said 78 — it grew by 3),
across 11 scopes:

| scope | n | notes |
|---|---|---|
| `global` | 17 | incl. 5 `<leader>` maps and `<leader>fo` → oil.nvim |
| `chat` | 17 | the core chat surface |
| `parley_buffer` | 10 | 5 of the 10 registry-only entries live here |
| `markdown` | 7 | |
| `chat_finder` | 7 | picker-local, only live while the picker is open |
| `vision` | 6 | **ariadne** |
| `repo` | 4 | **ariadne** (3 × `<C-y>`, 1 × `<C-j>`) |
| `issue_finder` | 4 | **ariadne**, picker-local |
| `issue` | 3 | **ariadne** |
| `note` | 3 | all three are registry-only |
| `note_finder` | 3 | picker-local |

### Three entries ship with no key at all

`default_key = nil`, resolved through `config_key`:

| id | resolves to |
|---|---|
| `super_repo_toggle` | `<C-g>p` |
| `chat_prune` | `<C-g>b` |
| `chat_toggle_tool_folds` | **nil — genuinely unbound** |

`chat_toggle_tool_folds` confirms the audit's finding: a feature with 60+ tests
that no user can reach without editing config. It is not a keyspace question,
it is a missing default.

### Off-registry bindings: eight, not four

The Problem section lists four. There are **eight**, in five sites:

| keys | where | mode |
|---|---|---|
| `u`, `<C-r>` | `init.lua:2208,2211` | n |
| `<CR>` | `spell.lua:168` | i |
| `<CR>` | `interview.lua:85` | i |
| `*`, `#`, `g*`, `g#` | `init.lua:2175-2183` | n |

The last row is new to this issue: four **core Vim search keys** shadowed in
chat buffers, invisible to `<C-g>?` and to config, exactly like `u`/`<C-r>`.
(`q`/`<Esc>` at `init.lua:1527-1529` are float-local and conventional — not in
scope.)

So the never-claimed question covers seven core keys, not three.

## Operator decisions (2026-09-05)

### Never-claimed set: only `<CR>` is in it

The Problem section grouped seven core keys together. Reading them showed they
are not comparable, and the operator split them accordingly.

**`u` / `<C-r>` and `*` / `#` / `g*` / `g#` — default ON, no configuration.**
Both are *conditional* intercepts that fall through to native:

- `bracket_jump` (`init.lua:2156-2173`) calls `drill_in.bracket_at`; with the
  cursor outside a `[...]` anchor it runs `normal! <builtin>` and returns.
  Inside one it searches the whole span. It sets the search register like
  builtin `*` and deliberately does not force `hlsearch`, so the user's own
  setting governs — matching the fall-through path.
- `u` / `<C-r>` intercept only while this chat owns a pending response.

Neither is a keyspace claim: with the feature inapplicable, the native key runs.
They stay off-registry and unconfigurable, and this issue records **why not**
rather than registering them — which the Plan's "or record why not" allows.

**`<CR>` in insert mode is the real one, and the whole typeahead gets gated.**
The logic is already guarded (`spell.lua:71-80`): no popup → defer to `base_cr`;
selection → `<C-y>`; otherwise `<C-e>` + base. The defect is not the logic, it is
**whose popup**: `pumvisible()` is true for cmp's and blink's menus too, so in a
chat buffer parley silently reinterprets the accept key those users configured.

Rejected as the fix: detecting "someone else's popup". It is not reliably
determinable, and the operator's call is to gate the feature instead.

**Decision: opt-in semantics AND `typeahead = false` shipped.** Flipping only the
shipped value would leave the trap; flipping only the semantics would leave the
default reinterpreting cmp/blink's accept key. Both.

**A trap found while confirming the gate.** `config.chat_spell.typeahead` exists,
but `spell.lua:130` documents it as *opt-out* — `nil ⇒ on`, so a partial
`chat_spell = { enable = true }` (squiggles only) silently also gets the `<CR>`
map. The entry condition `if cs and (cs.enable or cs.typeahead)` reinforces it.
Gating means making `typeahead` **opt-in** (`nil ⇒ off`), not just flipping the
shipped value — otherwise the trap survives the fix.

## Done when

- The default keymap is enumerated in one place with a written rationale per
  family, and the enumeration is what the code registers — not a parallel list.
- Every binding parley registers is rebindable and disableable through config;
  a test asserts no registry entry lacks a `config_key`, and has been seen red.
- `u`, `<C-r>` and insert-mode `<CR>` are either not shadowed by default, or are
  shadowed only behind an opt-in that is documented and testable.
- No **registry-derived** binding exists that `<C-g>?` cannot show — asserted in
  both directions. The conditional fall-through keys (`u`, `<C-r>`, `*`, `#`,
  `g*`, `g#`) are a named, closed allowance list: the assertion checks the list
  does not grow, rather than pretending they are registered (PQ-4 — the earlier
  wording contradicted this issue's own decision to leave them off-registry).
- A single documented switch disables the entire default keymap, verified by
  `:map` showing no parley mapping afterwards.
- **(M3)** `<M-i>` inserts a branch reference **at the cursor** and creates the
  child it points at — asserted per case (visual selection / pending `<M-q>`
  markers / neither), driven through the real keymap callback on a real chat
  buffer rather than through the planner alone. It **never deletes** anything
  from the parent, and it is never a no-op: with nothing to gather it still
  inserts a placeholder and opens an empty child.
- With the opt-in set unconfigured, a fresh install claims no `<leader>` key.
  *(The `<C-y>`/`<C-j>` half of this criterion moved out — it cannot be
  certified while the ariadne split is deferred. Owner: #212, then a follow-up
  that applies the policy. See the Plan's deferral note.)*

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim         design=0.3  impl=0.6
item: lua-neovim         design=0.2  impl=0.5
item: lua-neovim         design=0.2  impl=0.4
item: lua-neovim         design=0.25 impl=0.5
item: atlas-docs         design=0.05 impl=0.08
item: milestone-review   design=0.0  impl=0.2
item: milestone-review   design=0.0  impl=0.2
item: milestone-review   design=0.0  impl=0.2
design-buffer: 0.15
total: 3.83
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* Calibration reported **stale** by
`sdlc estimate-source` (ariadne#127); hours provisional.

Derivation notes:

- **Corrected twice.** The first block asserted `total: 3.22`, which reconciles
  to neither buffer — an arithmetic slip, caught by the reconciliation gate.
  Recomputing surfaced a second error the gate would not have caught: `impl=0.7`
  on M2 was **above** the primitive band, since v3.1 scales v2's Lua/Neovim
  0.5–1.5 to **0.2–0.6**. A single item cannot carry M2's scope while staying in
  band, which is the table telling me M2 is two primitives, not one.
- **Three `lua-neovim` items.** M1 (chords + the four-function branch unification
  + the fold-toggle binding); M2a (nine `config_key`s + the superset guard);
  M2b (typeahead gate + `<leader>` opt-in + master switch). Splitting M2 is not
  bookkeeping — it is what keeps each item inside the band it is drawn from.
- **impl 0.6 / 0.5 / 0.4** — M1 at the ceiling because the gate widened its class
  from two functions to four; M2a next because a nine-site sweep is where #218
  showed the overrun lands; M2b lowest, being three localised default flips.
- **design 0.3 / 0.2 / 0.2** sit in v2.1 Step 3's discounted band (×0.2 of 1–3 =
  0.2–0.6). All three are at or near the floor: three plan-quality rounds
  resolved the ordering trap, the creation-timing question and the class width,
  so what remains is execution.
- **atlas-docs impl 0.08** is the scaled ceiling (0.05–0.2 × 0.40 = 0.02–0.08);
  the first block's 0.1 was over it.
- **design-buffer 0.15** — v3.1 step 4's thorough-plan rate, matching
  `baseline-v3.1.md`'s own `est_design * 1.15` column.
- **Three `milestone-review` items**, one per genuine boundary, each at the
  scaled ceiling (0.2–0.5 × 0.40 = 0.08–0.20). #218 needed five close rounds and
  M1 needed five; budgeting one clean round per boundary would be optimistic.
- **M3 added 2026-09-07** (`design=0.25 impl=0.5`): routing pending `<M-q>`
  quotes into the new branch — the half of the chord's semantics specified in
  #217 gap 11 and never built. Its design line is above M1/M2's because one
  decision is genuinely open (does redirecting quotes *move* them out of the
  parent or *copy* them), and that choice changes what the action means.
  `impl=0.5` sits below M2a's 0.6 because it reuses `gather_and_strip` rather
  than adding parsing, but above M2b because it is behaviour with a durable
  side effect — the class that produced every Critical in M1.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `splice_inline_link` | `lua/parley/branch_ref.lua` | new |
| `ref_block` | `lua/parley/branch_ref.lua` | new |
| `format_ref_line` | `lua/parley/branch_ref.lua` | new |
| `topic_for_selection` | `lua/parley/branch_ref.lua` | new |
| `resolve_keys` | `lua/parley/keybinding_registry.lua` | changed |
| `help_lines` | `lua/parley/keybinding_registry.lua` | changed |
| `key_label` | `lua/parley/keybinding_registry.lua` | new |
| `plan_submission` | `lua/parley/branch_submit.lua` | new |
| `chat_gather_opts` | `lua/parley/drill_in.lua` | new |
| `is_annotation` | `lua/parley/annotation.lua` | new |
| `inline_links` | `lua/parley/annotation.lua` | new |
| `survivors` | `lua/parley/annotation.lua` | new |
| `seed_question` | `lua/parley/branch_submit.lua` | new |

- **`branch_ref`** — the line-editing half of a branch reference: build the
  `🌿:` line, splice an inline link around a selection, derive a child topic
  from selected text. No buffer, no IO.
  - **DRY rationale:** four near-identical branch functions each formatted the
    line themselves (`ARCH-DRY`); an arch guard now enforces single ownership.
- **`resolve_keys`** — `(entry, config) -> (keys, modes)`. M2 made an explicit
  `shortcut` authoritative in **both** directions (non-empty rebinds, empty
  disables) and put the `default_keymaps` master switch inside it, so
  registration, `key_for` and `<C-g>?` can never disagree.
  - **Relationships:** every key parley binds derives from it — enforced by
    `tests/arch/single_source_sweeps_spec.lua`, since the review skill and ~20
    picker sites previously read `config.X.shortcut` directly and so sat
    outside every guarantee it provides.
- **`help_lines`** — renders the `<C-g>?` float from the registry. Now shows
  aliases (primary in the aligned column, the rest after the description) and
  omits any entry that resolves to nothing.
- **`plan_submission`** — `(parsed_chat, cursor_line, markers) -> plan|nil`.
  Decides whether there is anything to rearrange; returns
  `{ case = "quotes", ref_after, strip_markers }` when pending `<M-q>` markers
  exist and `nil` otherwise, so the caller inserts a plain placeholder. No IO, no
  buffer — the decision is unit-testable with hand-built parser output while the
  effects stay in `branch_inserters`.
  - **As designed vs as shipped (#214 BR-59):** the plan specified
    `case = "quotes" | "question"` with `question`, `topic` and `delete_lines`,
    mirroring `<M-CR>`'s resubmit. Two operator revisions on first use — the
    reference lands at the cursor, and the chord never deletes — removed the
    question case entirely. Recorded here rather than left as a table describing
    code that does not exist.
- **`survivors`** — what must outlive a regenerated answer. Two FORMS, which is
  the distinction three rounds kept missing: a line-start annotation survives
  verbatim, and an inline `[🌿:anchor](file)` survives as a **standalone**
  reference — the prose around it belonged to the answer being replaced, but the
  link is the only pointer to a child on disk. Enumerating line *positions*
  (leading/middle/trailing) is not enumerating forms, and the visual branch —
  the case that exists to produce an inline link — kept losing its child.
- **`is_annotation`** — one owner for "does this line start a `🌿:`/`🔒:`
  annotation". The parser's trailing-span trim, the resubmit's survivor filter
  and the arch guard all need that answer; spelled three times, a fourth caller
  gets it subtly wrong.
- **`ref_block`** — the lines that make a reference its own block: one blank
  line each side, added only where there is not one already. "One blank line each
  side" was asserted in three artifacts and held by neither insert path — one
  emitted a blank before only, the other none — and the tests passed because
  their fixtures happened to have a blank where the margin would go (#214 BR-68).
- **`seed_question`** — one place that knows how a payload becomes a prompt.
  Three call sites would otherwise each invent wording, and two already had:
  `what is "X"` was built inline at the follow-a-dead-link path as well.
- **`chat_gather_opts`** (`lua/parley/drill_in.lua`, new) — the gather options a
  chat buffer uses: turn boundaries plus whether to mark referenced spans with
  `[]`. `chat_respond` built them inline and the branch path hardcoded
  `bracket = true`, so under `mark_reference_span = false` the two keys stripped
  differently (#214 BR-60). A test asserts neither call site rebuilds them.
- **`key_label`** — `key_for` as display text, never nil. Three picker-title
  sites fed a nil key straight to `string.format("%s")` (rendering
  `Issues (open  nil: cycle view)` under `default_keymaps = false`); one guarded
  it with `or "-"` and two did not. One convention, in one place.

### Data (single-source tables)

| Name | Lives in | Status |
|------|----------|--------|
| `opt_in` | `lua/parley/keybinding_registry.lua` | new |
| `native_overrides` | `lua/parley/keybinding_registry.lua` | new |
| `feature_gated` | `lua/parley/keybinding_registry.lua` | new |
| `_saved_cr` | `lua/parley/interview.lua` | new |

- **`opt_in`** — entries parley deliberately ships unbound, with the reason.
  Being listed is the only sanctioned way for a shipped binding to resolve to
  nothing; the spec closes it in both directions.
- **`native_overrides`** — the six keys parley wraps without owning
  (`u`, `<C-r>`, `*`, `#`, `g*`, `g#`), each with where it is installed and why
  it is not a registry entry. `native_map` refuses a key absent from it.
- **`feature_gated`** — keys that exist only because a feature was switched on
  (`chat_spell.typeahead`'s `<CR>`, interview mode's). The prose already blessed
  this category; listing it is what makes the leak guard's allowance list
  genuinely closed instead of reporting a documented opt-in as an escape.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `_branch_inserters` | `lua/parley/init.lua` | new | buffer writes + child-chat creation |
| `registry_callbacks` | `lua/parley/skills/review/init.lua` | new | review actions, for the registry to install |
| `native_map` | `lua/parley/init.lua` | new | `vim.keymap.set` for non-registry keys |
| `flatten_lines` | `lua/parley/helper.lua` | new | `vim.fn.writefile`'s NUL encoding |
| `setup_keymap` | `lua/parley/interview.lua` | changed | interview's `<CR>`, now buffer-local |
| `register_global` | `lua/parley/keybinding_registry.lua` | changed | global keymap install + teardown |

- **`_branch_inserters`** — one helper both chat and markdown call, branching on
  `owns_file`: parley commits a reference only in a file it owns.
- **`registry_callbacks`** — replaced the skill's own `setup_keymaps`. The skill
  supplies behaviour; the registry owns installation (#214 C1).
- **`native_map`** — gates the six native wrappers on the master switch and
  refuses an undeclared key.
- **`flatten_lines`** — no `writefile` element may contain a newline. `writefile`
  encodes one as a NUL byte instead of rejecting it, and `readfile` turns that
  NUL back into a newline, so a Lua round-trip cannot see the damage — it is
  visible only outside Vim. That is how a corrupt child transcript shipped in M3
  and was caught by the operator on first use.
- **`setup_keymap` / `_saved_cr`** — interview's timestamp `<CR>`. Its removal
  did an unconditional `vim.keymap.del("i", "<CR>")`, deleting the user's own map
  (cmp/blink's accept key for most users). The defect is **teardown, not scope**:
  round 9 narrowed the map to buffer-local, which moved the collision onto spell
  typeahead's own buffer-local `<CR>` — destroying it — and confined session
  state to one buffer. It is global again, matching the session state it serves
  and the `base_cr` delegation spell already implements, and `_saved_cr` holds
  whatever it shadowed so teardown restores rather than deletes.
- **`register_global`** — installs the non-buffer-local half of the registry and
  now tracks what it installed, so a later `setup()` can revoke it. Without the
  teardown, flipping `default_keymaps` off and re-running `setup()` left 43
  global mappings live — the most natural way to try the switch was the one way
  it did not work.

## Plan

Two review boundaries, sequenced as the operator directed: the chords are what
gets *felt*, so they land first; the curation cleanup follows. The ariadne
core/opt-in split is **not** in either — it touches `register_global`'s scope
list, which is #212's territory, and that is the whole of this issue's
`deps: [#212]`.

**Ordering constraint discovered at the gate (PQ-1).** `resolve_keys`
(`keybinding_registry.lua:965-967`) returns the config `shortcut` and **ignores
`default_key` entirely** whenever a `config_key` exists:

```lua
if not entry.config_key then
    return as_list(entry.default_key), entry.default_modes
end
```

Two consequences, and the second is the dangerous one.

**M1's edits would be inert or revoked.** `chat_prune` is already
config-resolved, so a key list on its registry entry changes nothing; and M2
giving `branch_ref` a `config_key` with a single-string default would drop M1's
`<M-S-CR>`/`<M-i>` a milestone later. So the artifact carrying the list is
**`config.lua`**, and `branch_ref` gets its `config_key` in M1, not M2.

**Generalised: adding a `config_key` can silently SHRINK an entry's key set.**
Two registry-only entries ship more than one key today —

| entry | keys | what a single-string config default would delete |
|---|---|---|
| `chat_drill_in` | `<C-g>q`, `<M-q>` | **`<M-q>`** — the headline quote feature (#217 item 7) |
| `outline` | `<C-g>t`, `<M-t>` | `<M-t>` |

— so M2's nine new config defaults must each carry that entry's **full existing
key list**, and a guard must enforce it rather than leave it to review. Without
one, the most-praised binding in the shakedown disappears in a commit whose
stated purpose is making bindings *more* configurable.

- [x] **M1** — chords **in config, with `branch_ref` gaining its `config_key` in
      the same step**: `global_shortcut_branch_ref = { "<M-S-CR>", "<M-i>", "<C-g>i" }`,
      `chat_shortcut_prune = { "<M-p>", "<C-g>b" }`. Old keys kept as legacy
      aliases (`chat_drill_in` is the precedent for a key list). `<M-S-CR>` is
      documented primary, `<M-i>`/`<M-p>` the fallback for the many terminals
      that cannot distinguish Shift+Enter. Test: `resolve_keys` returns all three
      for `branch_ref` under the shipped config.
- [x] **M1** — unify the branch paths. The class is **four** functions, not two
      (PQ-3): `chat_insert_branch_ref` / `chat_insert_inline_branch_ref`
      (`init.lua:2104,2118`) and the identical markdown twins
      `md_insert_branch_ref` / `md_insert_inline_branch_ref` (`:2427,2440`).
      Only the two *visual* paths call `create_child_chat`. Extract one helper
      both buffer types call, so the pair cannot drift again.
- [x] **M1** — resolve *when* the child is created on the no-selection path
      (PQ-2): the topic does not exist at keypress. Decision: create immediately
      with an empty topic and **open** the child, so the user types the question
      in the child rather than on the parent's ref line — this is what makes the
      no-selection case a redirected submission rather than an exception. The
      existing auto-slug-rename from the first topic
      (`atlas/chat/lifecycle.md`) fills the name in afterwards; verify that
      before relying on it.
- [x] **M1** — ~~bind~~ **make `chat_toggle_tool_folds` callable while staying
      unbound.** The plan step said "bind it"; the codebase disagreed in two
      places — a config comment reading *"Intentionally unbound by default"* and
      `config_tools_spec.lua:388` asserting `is_nil`. Operator ruled: **stays
      unbound, because a tool call's RESULT is low-value reading and does not
      justify a key out of the shared `<C-g>` surface** — the rationale the
      original decision never recorded. But "unbound" had also meant
      *unreachable*: the toggle existed only as a registry callback, so a user
      could not invoke it without first configuring a key. Now
      `:ParleyToggleToolFolds`, with the registry callback pointing AT the
      command so binding it cannot drift from calling it.
- [x] **M2** — `config_key` for the remaining 9 registry-only entries, each
      shipped default carrying that entry's **full** existing key list.
      **Tighten the existing assertion** at `tests/unit/keybindings_spec.lua:217-229`
      rather than adding a second one beside it. Seen red.
- [x] **M2** — guard BOTH directions of the resolve seam. Measured behaviour
      (`keybinding_registry.lua`, verified not inferred): only a table with a
      **non-empty `shortcut`** replaces `default_key`; an absent key, a table
      without `shortcut`, a bare string, and `shortcut = ""` **all fall back to
      `default_key` in full**.
      - *shrink* — a config value supplying one key where `default_key` held a
        list silently drops the rest. Seen red by shipping a single-string
        default for `chat_drill_in` (which would delete `<M-q>`).
      - *disable* — **`shortcut = ""` does not disable a binding**, it falls
        through to the default, so `branch_ref` is still not disableable and
        Done-when's "rebindable **and** disableable" is unmet (#214 BR-9). Today
        the only way to ship an entry off is `default_key = nil`. Decide the
        semantics (empty string / empty list = disabled) and pin both directions.
- [x] **M2** — gate the spell typeahead: `nil ⇒ off` semantics **and**
      `typeahead = false` shipped. Strategy: `spell.attach` across `typeahead`
      nil / false / true, crossed with a partial `chat_spell = { enable = true }`
      and with `prompt_buf_type` set.
- [x] **M2** — `resolve_keys` strategy: config values that are a string, a list,
      an empty string, and a table with no `shortcut` — the shapes the chord
      change and the 9 new `config_key`s both newly depend on.
- [x] **M2** — record in-repo why `u`/`<C-r>`/`*`/`#`/`g*`/`g#` stay off-registry
      (conditional, fall through to native — not a keyspace claim), as the named
      allowance list the help assertion checks against.
- [x] **M2** — `<leader>` maps to opt-in, per the Spec's recorded direction;
      `<leader>fo` maps oil.nvim, which parley never requires.
- [x] **M2** — one documented switch disabling the whole default keymap, verified
      by `:map` showing no parley mapping.
- [x] **M2** — assert registry-derived help/reality agreement in both directions,
      with the allowance list closed.

- [x] **M3** — generalise `<M-S-CR>` (operator, 2026-09-07), then NARROWED by the
      operator on first use (## Revisions, "M3 placement reversed by the operator"): the chord inserts at the
      cursor and never deletes. The rule as shipped:

      > ~~`<M-S-CR>` performs the submission `<M-CR>` would perform, into a new
      > child chat, and leaves a `🌿:` reference at the position `<M-CR>`'s
      > output would have occupied.~~
      >
      > **As shipped:** `<M-i>` inserts a branch reference at the cursor and
      > creates the child it points at, gathering any pending `<M-q>` quotes into
      > it. It never deletes from the parent.

      The parent always keeps its context. The design below is kept as the record
      of what was planned; the two revisions that narrowed it are in
      ## Revisions.

      | # | context | `<M-CR>` does | `<M-S-CR>` does | ref lands |
      |---|---|---|---|---|
      | 1 | visual selection | inline term definition at the selection | child seeded `tell me more about "<sel>"` | inline `[🌿:<sel>](child)` at the selection |
      | 2a | cursor on a past exchange carrying `<M-q>` markers | strip markers in place; insert a new turn **after that exchange's answer**, original Q/A preserved (`atlas/chat/drill_in.md:36`) | same gathered quote+question blocks become the child's first question | after **that** exchange's `📝:` |
      | 2b | `<M-q>` markers elsewhere | strip markers; append the new turn at buffer end | same payload → child | after the **last** exchange's `📝:` |
      | 3 | neither | submits the question | **placeholder**: bare `🌿:`, empty child, question untouched | at the cursor |

      **Superseded 2026-09-07** — see ## Revisions, "M3 placement reversed by the operator". Rows 2a/2b collapse
      (placement is the cursor, not the exchange end) and row 3 became a pure
      placeholder (the chord never deletes). The rule as shipped is in
      `atlas/chat/inline_branch_links.md`; this table is the design record.

      Spacing is the exchange model's own `MARGIN`: the ref is its own block with
      exactly one blank line before and after — `add_block(k, "branch_ref", 1, 1)`.

- [x] **M3 item 4 decision — SUPERSEDED (## Revisions, "M3 placement reversed" + "single-line annotations"). The ref lands
      at the CURSOR.** The reasoning below was sound and its measurement stands,
      but it was reasoning about a *workaround*: the model truncation it avoids
      was caused by the parser latching on `🌿:`, which is fixed at the source —
      a reference now costs exactly its own line wherever it sits. What follows
      is the original decision, kept because the measurement is still the record
      of how the exchange model behaved.

      ~~The ref goes AFTER the `📝:` summary. Measured, not reasoned.~~ Built both layouts and ran each through `from_parsed_chat`:

      ```
      ref AFTER  📝:  ex1 blocks = question@4 agent_header@6 text@8 summary@10   append_pos=12  <- the ref line
      ref BEFORE 📝:  ex1 blocks = question@4 agent_header@6 text@8              append_pos=10
      ```

      Placing the ref **before** the summary drops the `summary` block out of the
      exchange model entirely — so the summary stops being folded, and
      `append_pos` / `exchange_total_size` / `last_nonempty_block_end` all point
      into the middle of the exchange. Placing it after leaves the answer's blocks
      contiguous and lands exactly on `append_pos(k)`, which is the model's only
      end-of-exchange API (there is no mid-list insert). It also matches the
      operator's phrasing — "end of answer, right before next question" — and the
      semantics: `📝:` summarises the **answer**, while a branch ref is an
      annotation about where the conversation forked.

      (A first argument — that `🌿` is a structural marker in `chat_parser` and so
      would split the answer — was **wrong**: at parse level both placements yield
      an identical summary and branch list. The breakage is one level down, in the
      model. Recorded because the inference looked convincing and was not.)

- [x] **M3 decision (operator, 2026-09-07): STRIP, same as `<M-CR>` — SHIPPED,
      and it is the only case the chord acts on.** The markers move into the
      child and the parent is left clean. Rationale:
      `<M-q>` + `<M-CR>` moves your quotes into the next turn *here*; `<M-q>` +
      `<M-S-CR>` moves them into the next turn *there*. Same gesture, different
      destination — which is the whole mnemonic. A *fork* (copy, parent keeps the
      annotation) was the alternative and is rejected: it would make the same
      preparation gesture mean two different things depending on which key
      follows it.

**Why M3 and not M2.** M2 is pure policy — which keys exist, are they rebindable,
are they disableable. This is behaviour: what happens when the key fires, in code
(`drill_in`, `create_child_chat`) that M2 does not touch. M1 cost five review
rounds and three Criticals precisely because a behaviour change (the branch-path
unification) rode inside a curation milestone; bundling another one into M2 would
repeat that. Separate boundary, separate review, smaller blast radius.

**Deferred to after #212:** the ariadne core/opt-in split (`<C-y>*`, `<C-j>*`),
and with it the `<C-y>`/`<C-j>` half of the fresh-install Done-when criterion.

## Log


- 2026-09-07: closed M3 — make test: 200 spec files, MAKE_EXIT=0; luacheck clean across 356 files. BR-79 (Critical) was the same hazard in a form I had not enumerated. Rounds 14-15 fixed the TRAILING then the MIDDLE position of an annotation inside a resubmitted span, the second at the operation (delete_answer keeps annotations) on the reasoning that it covered every position at once — it did, but position is one axis and FORM is another: an inline [🌿:anchor](file) is what the visual branch exists to produce and my predicate was vim.startswith, so <M-i> on a selection then <M-CR> still orphaned the child. That is step 1.1 of the smoke walkthrough I had just written for the operator. annotation.survivors now handles both forms — line-start verbatim, inline reformatted into a standalone reference since the surrounding prose belonged to the replaced answer while the link is the only pointer to a child on disk. Reproduced first (a plain delete left only the question line), pinned by 2 unit assertions plus an end-to-end test that runs a real visual <M-i> and then the real delete_answer; reverting survivors to line-start-only turns 2 red. BR-80: is_annotation carried its own default prefix table, which silently answers for a caller that never threaded config through — the shape #215 is_partition exists to forbid, and here a wrong answer deletes user data. It derives from highlight_structure.patterns now, the one place that already resolves a prefix or falls back, so there is one source for defaults and one owner for the question; asserting rather than defaulting immediately exposed two callers reading plugin state they had not set up (delete_answer, which now takes cfg explicitly from chat_respond, and the outline parse path), both fixed. Placement: the smoke walkthrough moved from workshop/ root to workshop/plans/, per the rule that a workshop artifact lives in the subdirectory its datatype names. Actual 4.69h = measured 14.53h cumulative minus M1 1.31h minus M2 8.53h.; review verdict: FIX-THEN-SHIP
- 2026-09-07: M2 rounds 9-11. Round 9 (5 Importants): the master switch was sampled at three sites and only two had a stated reversibility rule — `register_global` had no teardown, so `setup()` then `setup({default_keymaps=false})` left 43 global mappings live; it now tracks and revokes what it installed, skipping keys the user rebound. Two of the five were my own test ORACLES rather than the code: the leak guard identified parley's maps by a `desc` containing "parley" (46 of 81 entries carry no such desc, and they are all non-buffer_local only by coincidence), and "every binding is disableable" excluded the 15 dotted picker keys behind a hand-typed predicate. Both replaced with derivations — a before/after keymap diff, and a nested-config builder covering all 81. Round 10 (4 Importants) was dominated by BR-47, a regression I introduced in round 9: making interview's `<CR>` buffer-local MOVED the collision instead of removing it, destroying spell typeahead's own buffer-local `<CR>` and confining session state to one buffer. The defect BR-41 named is teardown, not scope — `del` cannot tell "mine" from "theirs" at any scope — so the map is global again (matching the session state it serves and the `base_cr` delegation spell implements) and teardown restores via `mapset` what `nvim_get_keymap` captured. Round 10 also moved malformed-shortcut validation out of `resolve_keys`, where one typo had produced a log write and a notify popup on every `<C-g>?` press and every chat BufEnter. Round 11 demoted three findings past the cap; all three were fixed anyway under the FIX-THEN-SHIP protocol. N2 was the sharpest: my interview tests drove `setup_keymap`/`remove_keymap` rather than `enter()`/`exit()`, and the real transition RAISED — `start_timer` parked a libuv handle in `_state`, which `refresh_state` deepcopies, so opening any chat file during interview mode errored with "Cannot deepcopy object of type userdata". Pre-existing for ~16 months, invisible because no test drove the transition a user actually triggers. Timer moved to a module-local; tests converted to `enter()`/`exit()`; three assertions red when the handle is parked back. N3 re-raised BR-49 correctly: my boundary parse checked only the top-level type, so `shortcut = { 5 }` still resolved to nil — the same outcome as a deliberate `""`, which is the exact typo-equals-decision equivalence the fix existed to remove. Now every coercible shape is reported and normalised, including dotted parents and leaves. N1: the atlas and lessons.md still taught the buffer-local design round 10 reversed, and lessons.md is read by every agent at session start, so its rule 5 would have re-created BR-47; both rewritten, and the enumeration came from `git show --stat a84108a` rather than memory.

- 2026-09-07: M2 boundary review returned REWORK with two Criticals, both mine, both correct on measurement. **C1 was the milestone's own thesis failing at the install seam.** M2 gave the registry three guarantees — rebinding, `shortcut = ""` disabling, the master switch — and every one attaches to `resolve_keys`; but the review skill and ~20 picker sites built keymaps by reading `config.X.shortcut` directly, so none of the three reached them. Measured symptoms: `default_keymaps = false` left `<M-o>`/`<M-CR>`/`<C-g>ve` bound on every markdown buffer, and the `shortcut = ""` gesture the README had just documented raised `Invalid (empty) LHS` on every markdown BufEnter. The class fix, not the site fix: the review skill now returns `registry_callbacks` and the registry installs them (its three entries lost `help_only`, the flag that WAS the exemption); every picker resolves via `key_for`, which also deleted their hardcoded `default_key` duplicates; `float_picker` skips an empty key; the two chat-template display sites use `key_hint`. Zero raw `.shortcut` reads remain outside the registry, and an arch guard enforces that plus "no `help_only` entry outside a picker mappings table", both seen red. The agreement spec now covers markdown and journal-sidecar buffers — C1 lived entirely in the chat-only blind spot. **C2 was subtler and worse in kind:** giving `md_delete_file` the shared `chat_shortcut_delete` knob handed it the chat entry's MODES too, putting a file-deleting action on insert and visual mode in every markdown buffer, inside a milestone whose plan declares itself behaviour-free. My superset guard inspected `shortcut` only. It now covers keys AND modes in one loop, plus a new rule that entries may share a config_key only when their declared defaults match exactly — which is the general statement of why the twin pattern was wrong here. Fixing I1 exposed something worse than the README sentence: the switch as built overrode the user's OWN bindings, so turning it on was a one-way door (and 8 entries, `chat_drill_in`/`<M-q>` among them, have no `:Parley*` command to fall back on). `setup()` now records `config._explicit_shortcuts` and the switch honours them — it suppresses parley's claims, not the user's choices. I2 delivered rather than retired: `<C-g>?` renders aliases, closing the Done-when M1's Log had committed M2 to. Writing the derived README-command test immediately caught three commands the README documents that were never implemented (`ParleyChatDirs`/`ChatDirAdd`/`ChatDirRemove`); README corrected. Minors: `native_map` logs and skips instead of raising after `_prepared_bufs` was set (contract moved to an arch guard); dead `bufnr` thread removed; the reversibility test now states the real `_prepared_bufs` rule instead of only the flattering half; upgrade note and `note_shortcut_*` added to the README. The two Core-concepts arch guards were hardwired to `000205-*` — parameterised on the branch's issue and on `git merge-base HEAD main` (the issue's first commit attributed every unrelated merge to this issue), and #214's own table added. Two bugs in my own new guards, caught by running them: a `plain=true` find with a pattern-escaped needle, and the arch sweep flagging the `_explicit_shortcuts` capture, which reads `.shortcut` to detect user INTENT rather than to derive a key — now an explicit `-- shortcut-read-ok:` annotation rather than an inferred exemption.

- 2026-09-07: M2 implementation complete, pre-close. Three of the eight rows named the same defect from different angles: parley shipped bindings the registry could not govern. (1) Nine entries had no `config_key`. Adding one is not free — `resolve_keys` REPLACES rather than merges, so a single-string shipped default would have deleted `<M-q>` (the headline quote gesture, #217 item 7) and `<M-t>`; each new default carries the entry's full key list and a superset guard enforces it, seen red by shipping `chat_drill_in` as a string. (2) BR-9 confirmed and fixed: `shortcut = ""` fell through to `default_key`, so nothing carrying a default could be disabled. The existing tool-folds tests made empty look like it worked generally — it only worked for the one entry shipping no `default_key` at all, which is the adjacent-thing trap again. An explicit `shortcut` is now authoritative both ways. (3) The help float ended in `or entry.default_key`, resurrecting exactly the keys resolution had refused, so `<C-g>?` advertised bindings nobody could press — and handed a raw TABLE to `string.format` for multi-key entries. It now reads `resolve_keys` and nothing else, which is also what makes the master switch honest: `default_keymaps = false` lives inside `resolve_keys`, so registration, `key_for` and the float go quiet together rather than the float advertising a keymap set that was never installed. `<leader>` maps (five copy helpers plus `<leader>fo`, which mapped oil.nvim — not a parley dependency) ship off via a declared `opt_in` list the spec closes in BOTH directions, so a binding cannot lose its key quietly; being in that list is the only sanctioned way to resolve to nothing. `u`/`<C-r>`/`*`/`#`/`g*`/`g#` stay off-registry with their rationale recorded in `native_overrides`, and that exemption is enforced rather than trusted — `native_map` refuses a key absent from the list, and the new `keybinding_agreement_spec` closes it against a real prepped chat buffer (no leaks, no ghosts). Writing that test surfaced a normalization bug in my own first version: Neovim reports `<C-g>` as `<C-G>`, so every `<C-g>` binding looked simultaneously leaked and missing until both sides went through `keytrans(replace_termcodes(...))`. `chat_spell.typeahead` flips to nil-implies-off and ships `false` per the operator's call to gate the whole typeahead. One design correction mid-flight: I invented `chat_shortcut_delete_file` for `md_delete_file` before checking the two existing markdown twins, which both share their chat sibling's `config_key`; sharing `chat_shortcut_delete` matches the precedent and a test now rebinds all three pairs through the shared knob. Mutation ledger built from `git diff <M1 boundary> -- lua/`, not recall: ten deliverables, ten mutations, each verified red and restored green.


- 2026-09-07: closed M1 — make test: 197 spec files, MAKE_EXIT=0 verified against make status; luacheck clean across 351 files. Round 6 disposed 18 findings and left the gate with no open blocking items; its one new finding BR-34 is addressed in 0a712ad. That finding also corrected my own earlier BR-21 report: I had said a % in a gsub replacement RAISES, reproduced in standard Lua, but neovim runs LuaJIT which does not raise — measured here, "50% off" becomes "50 off", "%1 ph" becomes the pattern itself, and "100%" writes a NUL byte into the file. So it was silent corruption of chat topics and note titles, not a crash. I had fixed one site; the enumeration turned up six more: three {{topic}} substitutions including the child-creation path M1 routes markdown branches to, the initial_question substitution, notes.lua title and metadata placeholders, and exporter.lua branch placeholders in HTML export. render.lua and the slug rename were already escaped. An arch guard now enforces the rule — a runtime string is never gsubs second argument — using an explicit `-- gsub-safe: <why>` annotation rather than inferring safety from variable names, which my first version did and which is a guess dressed as a rule; verified by planting a raw runtime replacement. M1 itself delivers: branch_ref resolving <M-i>, <M-S-CR>, <C-g>i and chat_prune resolving <M-p>, <C-g>b, both in config.lua because a registry-side edit would have been inert; the portable key leads because the help float renders only keys[1] and most terminals cannot distinguish Shift+Enter from Enter; four branch functions collapsed into one branch_inserters(buf, abs_link, owns_file) with the pure line editing in the new parley/branch_ref.lua; chat_toggle_tool_folds unbound per operator decision but callable as :ParleyToggleToolFolds. The governing rule from six rounds: parley commits a reference only in a file it OWNS, so a chat buffer gets create-child + save-parent + open-child while a foreign markdown buffer gets the ref line and cursor with no child and no write. Neither mode calls create_child_chat directly and the spec iterates modes x buffer types. Mutation ledger generated from git diff rather than recall. Atlas corrected twice, README updated, ## Revisions records the three M1 decisions review overturned, lessons.md records the root cause. Deferred: BR-9 to M2, and routing <M-q> quotes into the branch to M3 with the strip-not-fork decision recorded up front.; review verdict: FIX-THEN-SHIP

### 2026-09-02

Raised by the operator while reviewing the parley-v1-release breakdown: the
audit had catalogued the keybinding *land-grab* as blocker B9, but treated it
purely as a gating problem. The operator's framing is the missing half — even
where a feature works, a default binding is a claim on the user's keyspace that
has to be justified, and ariadne bindings should be explicitly configured rather
than defaulted.

Distinct from #212 on purpose. #212 asks "can this feature work in this context?"
and stops binding it where it cannot. This issue asks "even where it works, does
it deserve a default key?" — a curation judgment, not a mechanical one. #212 is a
launch blocker; this is quality work that rides on the mechanism #212 builds.

Counts current as of this date: 78 registry entries (68 rebindable, 10 not, 18
help-only, 3 with no default key), 65 default shortcuts in `config.lua`, and 4
bindings made outside the registry.

### 2026-09-06 — M1 implemented

Commit `d57e660` + the tool-folds follow-up. Suite green (195 files), lint clean.

**The chords had to land in `config.lua`, not the registry.** `resolve_keys`
ignores `default_key` entirely once a `config_key` exists, so the registry-side
edit I originally planned would have been **inert** for `chat_prune` and revoked
for `branch_ref` when M2 added its `config_key`. Caught by the plan gate, not by
me.

**`<M-i>` leads over `<M-S-CR>`, reversing the order the operator approved.**
The `<C-g>?` help float renders only `keys[1]`, and most terminals cannot
distinguish Shift+Enter from Enter — so leading with the mnemonic would
advertise a chord that silently does nothing for most users. Portable key first.
Flagged to the operator rather than done quietly.

**Found while checking that: `<M-q>` is invisible in the help float.**
`chat_drill_in` is `{ "<C-g>q", "<M-q>" }` and help shows only the first, so the
binding the operator singled out as a shakedown talking point is undiscoverable.
Same for `outline`'s `<M-t>`. Pre-existing; belongs to M2's help/reality
criterion, which will render aliases rather than reorder more keys.

**Three tests encoded the old chords** and now assert the full key **list** — an
assertion reading `keys[1]` would have stayed green while an alias silently
vanished, which is the shrink class PQ-1 named.

## Revisions

Numbered continuously with the `## Problem` enumeration above (which owns 1-3),
so no number repeats anywhere in this file. **Cite an entry by its dated heading,
not by its number** — the consolidation that produced this sequence silently
re-pointed five existing citations at unrelated decisions, and an ordinal is a
reference that its own artifact can invalidate (#214 BR-76). Appended in the order the decisions
were made; entries that reverse an earlier one say which. Five of these blocks
lived under `## Log` until the M3 boundary review pointed out that a revision
belongs here and that 1/2/3 were each in use twice (#214 BR-67).


### 2026-09-06 — M1 decisions superseded during review (BR-30)

Four review rounds changed three decisions the Plan and the earlier Log still
state as settled. Recording the deltas rather than editing the originals.

**4. `<M-S-CR>` is no longer the documented primary.** The Plan says "`<M-S-CR>`
is documented primary, `<M-i>`/`<M-p>` the fallback". Shipped order is
`<M-i>`, `<M-S-CR>`, `<C-g>i` — because `<C-g>?` renders only `keys[1]`, so
leading with the mnemonic would advertise a chord most terminals cannot
distinguish from `<CR>`. Flagged to the operator at the time; the mnemonic is
still bound, just not first.

**5. `chat_toggle_tool_folds` is NOT bound.** The Plan says "bind
`chat_toggle_tool_folds`". The codebase already carried the opposite decision in
a comment and an assertion, and the operator confirmed it: a tool call's *result*
is low-value reading and does not justify a key out of the shared `<C-g>`
surface. The real defect was that "unbound" also meant *unreachable* — fixed with
`:ParleyToggleToolFolds`, not with a key.

**6. The branch key does NOT behave identically in both buffer types.** The Plan
says "make all three branch paths one action", and the first implementation took
that literally — which produced two Criticals in a row: writing an arbitrary
markdown document to disk (persisting the user's unrelated edits), and creating
a child whose only reference could never be committed. The rule that survived
review is narrower and honest: **parley commits a reference only in a file it
owns.** A chat buffer gets create + commit + open; a foreign markdown buffer gets
the reference line and the cursor, with no child and no write. One code path,
one explicit branch on ownership — not one behaviour.

The consolidation itself stands: four near-identical functions became one, and
the drift they had accumulated (only the visual paths created children) is gone.

### 2026-09-07 — M2 boundary review (REWORK) reversed three things I had recorded

**7. `default_keymaps = false` no longer overrides the user's own bindings.**
As first built the switch was absolute: `resolve_keys` returned nil for every
entry, including one the user had explicitly configured. That made it a one-way
door — you turn it on to take the keyspace back, and then nothing you write in
`setup{}` can ever bind again. Compounded by I1: eight registry entries have no
`:Parley*` command, `chat_drill_in` (`<M-q>`) among them, so "use the command
instead" was not a recovery path either. `setup()` now records which
`*_shortcut_*` knobs the caller supplied (`config._explicit_shortcuts`) and the
switch honours them. The Done-when still holds: with nothing configured, `:map`
shows no parley mapping.

**8. The master switch's carve-out list was wrong as written.** `config.lua` and
the atlas claimed it exempted "keys inside transient parley windows (pickers,
the help float, the review menu)". `<M-o>`/`<M-CR>`/`<C-g>ve` are the keys that
*open* the review menu, on every ordinary markdown buffer — not keys inside it.
They were exempt for an entirely different reason: the review skill installed
them itself from raw config. Corrected extent: the switch covers everything
registry-derived, picker mappings included; only **hardcoded** window keys
(`q`/`<Esc>`, motion) are outside it.

**9. Alias rendering in `<C-g>?` is delivered, not accepted-as-missing.** M1's
Log committed M2's help criterion to "render aliases"; my first M2 pass ticked
the row and documented alias-invisibility in the atlas as settled instead. That
was a superseded commitment recorded in the wrong artifact. The float now shows
the primary in the aligned column and names the rest after the description
(`(also <M-S-CR>, <C-g>i)`), and the Done-when's both-directions assertion is
the test that closes it.

**10. `md_delete_file` does not share `chat_shortcut_delete` after all.** Round 1
of M2 gave it the shared knob to match `md_delete_tree`/`md_export_html`. But
`resolve_keys` lets config replace *modes* too, and the chat entry ships
`n/i/v/x` while `md_delete_file` declares `{ "n" }` — so a **file-deleting**
action reached insert and visual mode on every markdown buffer. It has its own
`chat_shortcut_delete_file` knob; entries may share one only when their declared
defaults match exactly, which is now asserted.

### 2026-09-07 — M2 round 9 (FIX-THEN-SHIP, 5 open Importants) — two more reversals
- 2026-09-07: closed M2 — make test: 198 spec files, MAKE_EXIT=0; luacheck clean across 352 files. Round-10 findings all fixed at the class. BR-47 (my own round-9 regression): making interview <CR> buffer-local MOVED the collision — it destroyed spell typeahead buffer-local <CR> and confined session state to one buffer. The defect is teardown, not scope, so the map is global again (matching session state and the base_cr delegation spell implements, #134) and teardown RESTORES what it shadowed: captured via nvim_get_keymap because maparg returns a buffer-local map when both exist (measured), restored via mapset which round-trips Lua-callback maps (measured). Six tests; red both on reverting to delete-the-slot (3) and on reverting to buffer-local (2), so both the original BR-41 defect and my regression are pinned. BR-49: validation moved from resolve_keys to setup() — measured 1 warning at setup and 0 across 3x help_lines + 5x resolve_keys (was 1 per call, i.e. a notify popup on every <C-g>? and every chat BufEnter); binding falls back to default; registry asserted to carry no logger dependency, restoring the purity the Core-concepts table claims. BR-48: added the DERIVED assertion the family lacked across five findings — every registry config_key must appear in config.lua — which reproduced the reviewers exact two (global_shortcut_vision_allocation, agent_picker_mappings.expand_catalog); both added, test green. BR-50 (both mine): global baseline now captured at module load rather than after ~13 setup() calls — the reviewers planted out-of-registry global now fails 3 tests where the file previously stayed green; feature_gated given both guards native_overrides already had (every member carries gate+where; no member is bound by the shipped config); traceability guard now reports pending off an issue branch instead of passing on an empty diff. Also caught and fixed while doing this: my round-9 rewrite had silently deleted the four BR-38 global-switch tests (file went 29->25 green with no failure) — restored. Actual 8.53h = measured 9.84h cumulative minus M1 recorded 1.31h.; review verdict: FIX-THEN-SHIP

**11. The master switch is reversible for global maps too, and that is a stated
rule per sample site rather than a property of buffers.** Round 8 raised the
buffer half as a Minor; I fixed and documented buffers and never looked at the
other sample site. `register_global` samples `default_keymaps` once per
`setup()` and had no teardown, so `setup()` then
`setup({ default_keymaps = false })` left **43** global mappings live — the
switch failing in the most natural way to try it. It now tracks what it
installed and revokes it, skipping any key whose `desc` no longer matches so a
user who rebound the key keeps theirs. The atlas states the rule for all three
sample sites (`register_global`, `register_buffer`, `native_map`), not just the
one I had looked at.

**12. Interview's `<CR>` is buffer-local.** M2's carve-out reasoning called it
"the feature, not a default" and stopped there. It never asked whether
*removing* it was safe: `remove_keymap` did an unconditional
`vim.keymap.del("i", "<CR>")`, so `<C-n>i` then `<C-n>I` deleted the user's own
`<CR>` — cmp/blink's accept key for most Neovim users — for the rest of the
session. This is the exact collision the Spec names and the Done-when's `<CR>`
clause covers. Buffer-local shadows and unshadows instead; `del` cannot
distinguish "mine" from "theirs", so it must never be aimed at a global map.

Two of my own guards were also wrong in ways worth recording, because both were
oracles that looked like assertions. The leak guard identified parley's maps by
a `desc` containing "parley" — a convention nothing enforced, and 46 of 81
entries do not follow it; it now diffs a before/after keymap snapshot and
depends on no convention at all. And "every binding is disableable" excluded the
15 dotted picker keys via a hand-typed predicate, which is an allowlist wearing
a filter; it now builds the nested config and covers all 81, as does a new
rebindability twin.

### 2026-09-07 — M2 round 11 (FIX-THEN-SHIP) — one reversal of a reversal

**13. Interview's `<CR>` is GLOBAL again, and the Core-concepts row that said
"buffer-local" was itself the round-9 decision being reversed.** Round 9 read the
BR-41 defect as a scope problem; round 10 established it is a *teardown* problem
(`del` cannot tell "mine" from "theirs" at any scope) and put the map back to
global with save/restore. Round 11 caught that the artifacts *recording* the
round-9 decision — `atlas/ui/keybindings.md` and `workshop/lessons.md` — were
never part of the reversal's diff, and that `lessons.md` in particular is loaded
by every agent at session start, so its rule would have re-created BR-47. Both
corrected. The enumeration is mechanical, not a memory exercise:
`git show --stat <the reversed commit>` lists exactly which artifacts recorded it.

**14. Interview's timer handle left `_state`.** Round 10's rationale was "the map
must live at the same scope as the session state it serves" — and that state's
own lifecycle could not run: `_state.interview_timer` held a libuv userdata and
`refresh_state` deepcopies `_state`, so opening any chat file while interview
mode was on raised. Pre-existing (~16 months), surfaced only once the tests were
converted to drive `enter()`/`exit()` instead of the sub-steps the fix edited.

### 2026-09-07 — 🌿: and 🔒: are single-line annotations (operator)

**15. The parser latched instead of skipping.** Both prefixes set
`line_before_local`, meaning *"content from here to the end of this component is
local"*. Right for a section marker, wrong for a one-line annotation, and nothing
distinguished the two — so a private note dropped early in a long answer silently
removed the rest of that answer from every later submission, and a note inside a
question removed the second half of the user's own question. Operator's model,
now the code's: the line is withheld, the next line is ordinary content.
Single-line is also the more useful primitive for `🔒:` — notes go anywhere, and
a multi-line note is several noted lines.

**My blast-radius estimate was wrong, and the operator called it.** I said this
"touches the parse of essentially every file" because every child chat opens with
a `🌿:` back-link. Measured: the latch resets at the next `💬:`, so a back-link
before the first question truncates nothing. Real corpus: 0 of 16 chats affected,
0 fixtures. The bug only bit mid-component. Same shape as the recurring mistake —
I verified that the marker is everywhere rather than that its position matters.

**What the fix did need was a hazard I had not seen.** Removing the latch put a
TRAILING `🌿:` inside the answer's line span, and resubmit deletes
`question..answer.line_end` — so the reference would have been deleted and the
child orphaned on disk, BR-19 by another route. The trailing-blank trim now skips
annotation lines; reverting that turns the span test red. Three existing tests
encoded the old semantics (one carried the fixture line *"still private because
line_before_local is set"*) and were updated to the decided contract.
      (placement is the cursor, not the exchange end) and the 3a/3b split is gone
      (the chord never deletes).

### 2026-09-07 — M3 placement reversed by the operator, on first real use

**16. The reference lands at the CURSOR, not at the end of the answer.** The
operator's earlier instruction ("end of answer, right before next question") was
withdrawn after using it: `<M-i>` inserted the line, then the line appeared
somewhere else, and the jump read as wrong. The reasoning is the part that
settles it — `<M-S-CR>` reads as a *submission*, whose effect is not local to
anywhere, but `<M-S-CR>` does not survive most terminals, so `<M-i>` is the key
people actually press and it reads as an *insertion*. An insertion happens where
you are.

I raised the measured cost before changing it: `🌿:` sets the parser's
`line_before_local` — the mechanism `🔒:` uses for a local section — so a
mid-answer reference drops the text after it from the LLM context, and
`from_parsed_chat` truncates the exchange (`summary` block gone, `append_pos`
into the middle). That is what end-of-answer placement was buying. It is also
pre-existing: the pre-#214 path inserted at the cursor too. The operator's call
stands; the real fix is a parser change (a standalone `🌿:` is a one-line
annotation, not a section boundary), which is not this milestone's to make.

**17. The chord never deletes.** With the placement change the operator also
narrowed case 3 to a pure placeholder: no markers means a bare `🌿:` at the
cursor and an empty child, with the question left alone. The earlier "copy the
question, delete the answer" reading mirrored `<M-CR>`'s resubmit and was
coherent for a submission — but `<M-i>`, `<M-S-CR>` and `<C-g>i` are one registry
entry with one callback, so it would only ever have been reachable from the key
that says "insert here". `plan_submission` now returns a plan only for the quotes
case; `exchange_at` and its conformance test went with it rather than staying as
tested-but-unreachable code.
