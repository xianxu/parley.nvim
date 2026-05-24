---
issue: 000124
target: review-convention
created: 2026-05-23
updated: 2026-05-23
---

# Plan: Align marker grammar and bindings with review-convention target

Companion to `workshop/issues/000124-review-convention-alignment.md`.
Canonical spec: `../ariadne/workshop/targets/review-convention.md`.

## Operator decisions (resolved before plan was written)

1. `~X~` uses **single tilde**, not GFM `~~X~~`. We own the rendering —
   highlighter applies strikethrough ourselves; we don't rely on the
   markdown renderer's strikethrough behavior.
2. **No bulk resolve.** Per-marker `<M-a>` / `<M-r>` only. Bulk path is
   "ask an agent" (spec §6, out of scope for parley.nvim).
3. **Retire `<C-g>vi`.** `<M-q>` / `<C-g>q` is the single canonical
   human-insertion path.
4. **Retire `<C-g>vr`** (human-typing-on-behalf-of-robot shortcut). If
   needed, a human can type `🤖{}` directly.
5. **`<X>` and `~X~` are mutually exclusive.** At most one reference
   slot per marker.

No backwards compatibility required for the `<M-r>` semantic shift from
accept-ish bulk-resolve → per-marker reject.

## Current state (gap survey)

Key files and their current responsibilities:

| File | Lines | Current responsibility |
|---|---|---|
| `lua/parley/skills/review/init.lua` | 30-44 | `find_matching_bracket` — depth-counting nested matcher (works for `<>`, `[]`, `{}`, will NOT work for non-nesting `~~`) |
| `lua/parley/skills/review/init.lua` | 54-102 | `parse_marker_sections` — parses `<X>` first slot then chain of `[]`/`{}` |
| `lua/parley/skills/review/init.lua` | 437-505 | Review-skill insertion (`<C-g>vi`, `<C-g>vr`) — diverges from spec, slated for removal |
| `lua/parley/drill_in.lua` | 68-96 | `parse` — wraps `parse_marker_sections`, exposes `quoted` |
| `lua/parley/drill_in.lua` | 142-152 | `resolve_at` — cursor-relative; `<T>` → T, no `<T>` → "" |
| `lua/parley/drill_in.lua` | 161-180 | `resolve_all` — bulk; `<T>` wins or trailing `{A}` → A. Slated for removal. |
| `lua/parley/drill_in.lua` | 244-246 | `wrap` — produces `🤖<text>[]` |
| `lua/parley/init.lua` | 1361-1495 | Drill-in handlers (visual wrap, resolve_at_cursor, insert) |
| `lua/parley/init.lua` | 1499-1523 | `drill_in_callbacks` — registry wiring for `chat_drill_in`, `chat_resolve_drill_in` |
| `lua/parley/keybinding_registry.lua` | 614-631 | `chat_drill_in` (`<M-q>`, `<C-g>q`) and `chat_resolve_drill_in` (`<M-r>`, `<C-g>r`) |
| `lua/parley/keybinding_registry.lua` | 673-694 | `review_insert` (`<C-g>vi`), `review_insert_machine` (`<C-g>vr`) — slated for removal |
| `lua/parley/config.lua` | 385-388 | Review-skill shortcut config — partial removal |
| `lua/parley/highlighter.lua` (TBD) | — | Marker highlight rules — needs `~X~` strikethrough |

## Design

### Marker model

After this change, a marker is conceptually:

```
marker     ::= 🤖 reference? chain
reference  ::= quote | strike
quote      ::= "<" TEXT ">"           # preserved on accept/reject
strike     ::= "~" TEXT "~"           # accept = removed; reject = preserved
chain      ::= (human | agent)*
human      ::= "[" TEXT "]"
agent      ::= "{" TEXT "}"
```

Parser surface change: keep existing `quoted = { text, byte_start, byte_end }`
for `<X>` (unchanged shape), add parallel `strike = { text, byte_start, byte_end }`
for `~X~`. Mutually exclusive — exactly one or neither is set. This is
less invasive than a unified `ref` field (existing tests reference
`m.quoted` directly throughout) and reads more naturally at call sites
(`if m.quoted` for one path, `if m.strike` for the other).

### `~X~` lexing

Tildes don't nest. Use simple "find next `~`" from the open position;
the matched text spans to that position. Multi-line `~X~` is supported
(same as multi-line `<X>` and `[]`/`{}` today). Edge case: if no closing
`~` exists, treat as plain text (fall through, same posture as unmatched
`<`).

Note: `~` is common in prose (e.g., file paths `~/foo`). The leading
`🤖` is what makes this a marker boundary — `~X~` is only recognized
*immediately* after `🤖` (or after a `🤖` that has no `<X>` since `<X>`
and `~X~` are mutually exclusive and exactly one can appear). Stray `~`
in unrelated prose is unaffected.

### Resolution table

Implemented as a single function `resolve(marker, mode)` where
`mode in {"accept", "reject"}`. The table maps `(ref_kind, chain_shape)
→ replacement` per spec §5:

```
ref=nil, chain=[H]                → ""    (both)
ref=quote(X), chain=[H]            → X     (both)
ref=quote(X), chain=[H]{R}          → X     (both)
ref=nil, chain={R}                  → R    (accept) / ""  (reject)
ref=nil, chain=[H]{R}               → ""   (both)
ref=nil, chain={R}[H]               → ""   (both)
ref=strike(D), chain=∅              → ""   (accept) / D   (reject)
ref=strike(D), chain={N}            → N    (accept) / D   (reject)
ref=strike(D), chain=[N]            → N    (accept) / D   (reject)
ref=nil, chain=longer [H]{R}[H]…   → ""   (both)
ref=quote(X), chain=longer          → X    (both)
ref=strike(D), chain=longer         → (first {N} or [N] after strike) on accept; D on reject
```

The general rule: take the reference's "kept text" (`<X>` → X, `~X~` →
nothing-on-accept / X-on-reject) plus the *first* `{N}` or `[N]` block
immediately following a strike reference if mode=accept. All later
blocks are dialogue and discard.

This generalization handles forms not explicitly enumerated in the spec
(e.g., `🤖<X>[H]{R}[H']{R'}` → X both modes).

### Insertion

`<M-q>` behavior, single canonical path:

| Mode | Selection | Inserted | Cursor lands |
|---|---|---|---|
| visual | non-empty | `🤖<sel>[ ]` | between `[` and `]` (one space) |
| normal | n/a | `🤖[ ]` | between `[` and `]` (one space) |

Empty selection in visual mode → fall through to normal-mode insert.

(Existing drill-in wrap produces `🤖<sel>[]` with *empty* `[]`. Spec
shows `🤖[human comment]` placeholder text; for the cursor-landing
case, an empty bracket is functionally equivalent. We'll keep the empty
form `🤖<sel>[]` since it's already implemented and matches existing
tests — adjustment only if cursor positioning is wrong.)

### Highlighter

`~X~` content rendered with `gui=strikethrough`. The `~` delimiters
themselves rendered like the surrounding marker chrome (faint). Follow
the existing pattern for `<>`/`[]`/`{}` rendering.

## Milestones

### M1 — `~X~` parser + highlighter (~3-4h)

**Files:**
- `lua/parley/skills/review/init.lua` — extend `parse_marker_sections`
- `lua/parley/drill_in.lua` — rename `quoted` → `ref`, update `parse`
- `lua/parley/highlighter.lua` (or equivalent) — add strikethrough rule
- `tests/unit/review_spec.lua` — add `~X~` parse cases
- `tests/unit/drill_in_spec.lua` — add `~X~` parse cases

**Tasks:**
1. In `parse_marker_sections`, after the existing `<` branch, add a `~`
   branch using a simple `text:find("~", cursor + 1, true)` lookup. Set
   `ref = { kind = "strike", text, byte_start, byte_end }`.
2. Rename `quoted` → `ref` everywhere in `drill_in.lua` and call sites
   (`init.lua` `drill_in_resolve_at_cursor` references `m.byte_start`
   etc.; check whether `quoted` is exposed).
3. Update `gather_and_strip` and `format_block` to handle `ref.kind`:
   `quote` behaves as today; `strike` content is *not* included in the
   gathered block (deletion proposal isn't a question to the agent).
4. Find the highlighter module (TBD — likely `lua/parley/highlighter.lua`
   or inline in a syntax file) and add a strikethrough span for `~X~`
   content. If no highlighter exists for current marker forms, this is
   a green-field add.
5. Tests: parse round-trip for `🤖~D~`, `🤖~D~{N}`, `🤖~D~[N]`,
   `🤖~D~[H]{R}` (longer chain); rejection of `🤖<X>~Y~` (only one ref
   slot).

**Verification:**
- `make test` (or repo-equivalent — see TOOLING.md) green.
- Open a test buffer with `🤖~D~` and visually confirm strikethrough
  renders.

**Milestone close:**
- Update atlas marker-grammar entry to mention `~X~`.
- Code review per AGENTS.md §3 (post-milestone subagent review).

### M2 — Accept/reject split + table-driven resolution (~4-5h)

**Files:**
- `lua/parley/drill_in.lua` — add `accept_at`, `reject_at`, remove
  `resolve_at`, `resolve_all`
- `lua/parley/init.lua` — split `drill_in_resolve_at_cursor` into
  `drill_in_accept_at_cursor` and `drill_in_reject_at_cursor`; remove
  `drill_in_resolve` (bulk)
- `lua/parley/keybinding_registry.lua` — add `chat_accept_drill_in`
  entry; repurpose `chat_resolve_drill_in` → `chat_reject_drill_in`;
  drop `<C-g>r` from key slots
- `tests/unit/drill_in_spec.lua` — full table coverage

**Tasks:**
1. Implement `resolve(marker, mode)` pure function in `drill_in.lua`
   per the design table. Single switch on `(ref_kind, chain_shape, mode)`.
2. Implement `accept_at(text, offset)` and `reject_at(text, offset)`
   wrapping `resolve` with the splice mechanic from existing
   `resolve_at`.
3. Delete `resolve_at` (cursor-relative), `resolve_all` (bulk) — both
   superseded.
4. Update `drill_in_callbacks` in `init.lua` to expose
   `chat_accept_drill_in` and `chat_reject_drill_in`. Remove
   `chat_resolve_drill_in`.
5. Update `keybinding_registry.lua`: rename `chat_resolve_drill_in` →
   `chat_reject_drill_in` with `default_key = "<M-r>"` (single key, drop
   `<C-g>r`); add `chat_accept_drill_in` with `default_key = "<M-a>"`.
6. Update `init.lua` wiring sites (lines ~1675, ~1886) to pass the new
   callback set.
7. Tests: every row of the table for both modes; behavior at chain
   boundaries; cursor-outside-marker (no-op).

**Verification:**
- `make test` green.
- Manual: in a buffer with one `🤖~D~{N}` marker, press `<M-a>` →
  buffer shows N. Reload, press `<M-r>` → buffer shows D.

**Milestone close:**
- Update `lua/parley/skills/review/SKILL.md` resolution semantics.
- Code review per AGENTS.md §3.

### M3 — `<M-q>` normalization + retire review-skill insertion (~2-3h)

**Files:**
- `lua/parley/skills/review/init.lua` — delete insertion handler block
  (~lines 437-505)
- `lua/parley/keybinding_registry.lua` — delete `review_insert`,
  `review_insert_machine` entries (lines 673-694)
- `lua/parley/config.lua` — delete `review_shortcut_insert`,
  `review_shortcut_insert_machine` entries (lines 385-386)
- `lua/parley/init.lua` — verify `drill_in_insert` cursor position
  matches spec
- `lua/parley/skills/review/SKILL.md` — update grammar + bindings section
- Atlas entry — point at canonical target

**Tasks:**
1. Verify `drill_in_insert` and `drill_in_visual` produce spec-conformant
   output. Adjust if cursor positioning drifts from spec.
2. Delete review-skill insertion block (the `M.setup_keymaps` portion
   handling `insert_cfg` and `insert_machine_cfg`).
3. Delete the two registry entries.
4. Delete the two config entries.
5. Update SKILL.md: grammar table, bindings table, accept/reject
   semantics.
6. Update atlas: minimal — one line pointing at
   `../ariadne/workshop/targets/review-convention.md` as canonical.

**Verification:**
- `make test` green.
- Grep `<C-g>vi`, `<C-g>vr`, `review_shortcut_insert`,
  `review_shortcut_insert_machine`, `review_insert`,
  `review_insert_machine` repo-wide — zero hits.
- Manual: visual-select text + `<M-q>` → `🤖<sel>[]` with cursor between
  brackets, ready to type.

**Milestone close:**
- Final code review per AGENTS.md §3.
- `make close-issue ISSUE=124 ACTUAL=<h> VERIFIED='<evidence>'`.

## Risks / open questions

- **Highlighter location unknown** — I haven't read the highlighter
  source yet. If parley.nvim relies on treesitter or a vim syntax file
  rather than an in-Lua highlighter, M1's strikethrough work changes
  shape (treesitter query vs. Lua `nvim_buf_set_extmark`). Surface
  during M1 setup, not blocking the plan.
- **`drill_in.parse` callers** — any peer that imports
  `drill_in.parse(text)` and reads `m.quoted` directly needs to be
  updated when we rename to `m.ref`. Quick grep during M1.
- **`gather_and_strip` semantics for `~X~`** — chat-respond's strip rule
  currently keys off `m.ready` (last section is non-empty `[]`). A
  `🤖~D~` standalone has no `[]` chain so it's not "ready" — chat-respond
  will leave it alone, which is correct. Confirm during M1 that `~D~[N]`
  (replacement form with `[N]`) doesn't accidentally trigger chat-respond
  as a drill-in.
- **Atlas update target** — need to find which atlas file currently
  describes marker grammar.

## Out of scope

- Agentic resolution (§6 of the spec). That lives in Claude Code /
  xx-fix per the parley/claude-code split memory.
- Any UI work for showing accept/reject status (e.g., toast, statusline
  indicator). Spec doesn't require it.
- Migration of existing in-the-wild markers. None use `~X~` yet, so
  nothing to migrate.
