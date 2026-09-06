---
id: 000214
status: working
deps: [#212]
github_issue:
created: 2026-09-02
updated: 2026-09-05
estimate_hours: 2.84
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
item: atlas-docs         design=0.05 impl=0.08
item: milestone-review   design=0.0  impl=0.2
item: milestone-review   design=0.0  impl=0.2
design-buffer: 0.15
total: 2.84
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
- **Two `milestone-review` items**, one per genuine boundary, each at the scaled
  ceiling (0.2–0.5 × 0.40 = 0.08–0.20). #218 needed five close rounds; budgeting
  one clean round per boundary would be optimistic.

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
- [ ] **M2** — `config_key` for the remaining 9 registry-only entries, each
      shipped default carrying that entry's **full** existing key list.
      **Tighten the existing assertion** at `tests/unit/keybindings_spec.lua:217-229`
      rather than adding a second one beside it. Seen red.
- [ ] **M2** — guard BOTH directions of the resolve seam. Measured behaviour
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
- [ ] **M2** — gate the spell typeahead: `nil ⇒ off` semantics **and**
      `typeahead = false` shipped. Strategy: `spell.attach` across `typeahead`
      nil / false / true, crossed with a partial `chat_spell = { enable = true }`
      and with `prompt_buf_type` set.
- [ ] **M2** — `resolve_keys` strategy: config values that are a string, a list,
      an empty string, and a table with no `shortcut` — the shapes the chord
      change and the 9 new `config_key`s both newly depend on.
- [ ] **M2** — record in-repo why `u`/`<C-r>`/`*`/`#`/`g*`/`g#` stay off-registry
      (conditional, fall through to native — not a keyspace claim), as the named
      allowance list the help assertion checks against.
- [ ] **M2** — `<leader>` maps to opt-in, per the Spec's recorded direction;
      `<leader>fo` maps oil.nvim, which parley never requires.
- [ ] **M2** — one documented switch disabling the whole default keymap, verified
      by `:map` showing no parley mapping.
- [ ] **M2** — assert registry-derived help/reality agreement in both directions,
      with the allowance list closed.

**Deferred to after #212:** the ariadne core/opt-in split (`<C-y>*`, `<C-j>*`),
and with it the `<C-y>`/`<C-j>` half of the fresh-install Done-when criterion.

## Log

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

### 2026-09-06 — M1 decisions superseded during review (BR-30)

Four review rounds changed three decisions the Plan and the earlier Log still
state as settled. Recording the deltas rather than editing the originals.

**1. `<M-S-CR>` is no longer the documented primary.** The Plan says "`<M-S-CR>`
is documented primary, `<M-i>`/`<M-p>` the fallback". Shipped order is
`<M-i>`, `<M-S-CR>`, `<C-g>i` — because `<C-g>?` renders only `keys[1]`, so
leading with the mnemonic would advertise a chord most terminals cannot
distinguish from `<CR>`. Flagged to the operator at the time; the mnemonic is
still bound, just not first.

**2. `chat_toggle_tool_folds` is NOT bound.** The Plan says "bind
`chat_toggle_tool_folds`". The codebase already carried the opposite decision in
a comment and an assertion, and the operator confirmed it: a tool call's *result*
is low-value reading and does not justify a key out of the shared `<C-g>`
surface. The real defect was that "unbound" also meant *unreachable* — fixed with
`:ParleyToggleToolFolds`, not with a key.

**3. The branch key does NOT behave identically in both buffer types.** The Plan
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
