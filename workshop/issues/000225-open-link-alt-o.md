---
id: 000225
status: working
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-08
estimate_hours: 1.79
started: 2026-09-08T16:45:24-07:00
---

# Open a link with <M-o>, falling back to gf

## Problem

Following a link is the most-used navigation in a forked transcript, and it is
on the hardest key. #214 moved it from `<C-g>o` to `<M-g>` to join the alt
family; the operator, using forks heavily, reports `<M-g>` is awkward to press.

Two things are wrong beyond the reach:

1. **`<M-o>` is the obvious key and is taken.** It opens the skill picker
   (`review_menu`, `scope = markdown`, chosen by the operator in #133 —
   "alt+o = skill selector"). `<M-o>` is therefore free in a chat buffer and
   taken in a markdown one, which is exactly the per-buffer-type divergence
   #214 spent sixteen rounds removing.
2. **Open dead-ends instead of falling through.** With the cursor on anything
   that is not a `🌿:` line, an inline `[🌿:…](file)` or an `@@ref@@`,
   `OpenFileUnderCursor` logs *"No file reference (@@ syntax) found on current
   line"* and stops. Meanwhile `gf` (`resolve_ref_gf`) already does the sensible
   thing for everything else: resolve an ariadne artifact ref, else native `gf`.
   One key should cover "go to the thing under my cursor."

## Spec

**Operator decision, 2026-09-08:**

| key | does | scope |
|---|---|---|
| `<M-o>` | open the link under the cursor | chat **and** markdown |
| `<M-s>` | skill picker (moved from `<M-o>`) | markdown |
| `<M-CR>` | review menu | unchanged |

`o` = open and `s` = skills both resolve as mnemonics, which the previous
assignment did not.

**Fallback chain for `<M-o>`**, in order:

1. `🌿:` reference line → open that chat
2. inline `[🌿:anchor](file)` under the cursor → open it
3. `src:` link / `@@path@@` reference → open it
4. **otherwise → `ResolveRefOrGotoFile`**: an ariadne artifact ref resolves and
   jumps; anything else gets native `gf`

### Step 4 is an extraction, and it needs a three-valued contract (PQ-1, PQ-2)

`OpenFileUnderCursor` has **two** chains:

```lua
if M.is_markdown(buf, file_name) then
    M.open_chat_reference(current_line, cursor_col, in_insert_mode, current_line)
    return                       -- UNCONDITIONAL. markdown never reaches below.
end
if M.not_chat(buf, file_name) then … return end
if open_branch_ref(...) then return end            -- the chat chain
if try_open_inline_branch_link(...) then return end
… @@ handling …
```

Appending step 4 would fire in chat and never in markdown — the per-buffer
divergence this issue exists to remove, reintroduced by its own fix. Appending
to both is two copies. So it is an **extraction**: one predicate for both types,
one fall-through at the caller. **The two chains are NOT duplicates, and saying so was the #214 M1 mistake
repeated** (PQ-8). I cited `branch_inserters` as the precedent for the
extraction and then made the error that precedent exists to prevent —
*"consolidating implementations ≠ erasing situational differences"*
(`lessons.md`). Measured, four divergences, each with a verdict:

| # | difference | today | verdict |
|---|---|---|---|
| 1 | `src:` links (`init.lua:4307`) | markdown only | **keep, extend to chat.** A `src:` link is a reference like any other; its absence in chat is an omission, not a policy. |
| 2 | `@@path: topic` form (`init.lua:4328`) | markdown only | **keep, extend to chat.** Same parser, strictly more forms accepted. Low risk: the chat path already handles bare `@@ref@@`. |
| 3 | bare-name `resolve_chat_path` (`init.lua:4352`) | markdown only | **keep, extend to chat** — and it is the timestamp-prefix resolver #224 is about, so chat gains slug-tolerance it should already have had. |
| 4 | directory `Explore` + split-aware edit (`init.lua:4463-4492`) | **chat only** | **keep, chat only.** This is the one that must NOT be flattened: it opens a directory reference in netrw, preferring the other window in a two-split layout. Deleting the "second copy" as originally written would have silently dropped it. Whether markdown should gain it is a separate question, deliberately not answered here. |

So the extraction takes the union for 1-3 and preserves 4 as a chat-only arm —
one function with one explicit branch, not one function that quietly loses a
feature. That branch is the `owns_file`-shaped parameter M1 ended up with, for
the same reason.

**A boolean is not enough.** Making markdown fall through promotes three
currently-discarded exits to load-bearing, and they do not mean the same thing:

| exit | today | means | on fall-through |
|---|---|---|---|
| `init.lua:4337` | `nil` + warning *"No chat reference (@@ syntax) found"* | there is no reference here | **fall through to `gf`**; drop the warning |
| `init.lua:4344` | `nil` + warning *"Could not extract chat path"* | same | **fall through**; drop the warning |
| `init.lua:4394` | `false` + warning *"Chat file not found: <path>"* | a reference we understood, whose file is missing | **terminal — report, do NOT fall through** |

Falling through on the third would hand `gf` a path we already know is absent,
losing the diagnostic and letting `gf` fail or open something unrelated. So:

```lua
--- @return "opened" | "none" | "failed"
local function open_reference_under_cursor(buf, line, col, in_insert) … end
```

`"none"` is the only value that falls through. `"failed"` keeps its message.

### Landing mode (PQ-3, PQ-7)

Every existing success exit restores insert when it started there
(`init.lua:4511, 4587, 4602`). That is not an oversight to normalise away — it
is a coherent policy once stated:

> **The landing mode follows the destination, not the origin.**
> A chat reference is somewhere you went to *write*, so insert is restored.
> A `gf` destination is source you went to *read*, so it lands in normal.

So the fall-through does `stopinsert`, the reference exits keep `startinsert`,
and the difference is intended rather than an artifact of which branch ran.

## Core concepts

The work is one extraction, so the table is short. `open_reference_under_cursor`
is the entity; the three helpers below it change *contract* (boolean → status)
without changing shape, which is what makes the extraction's fall-through
possible at all.

### Pure entities

None. Reference opening is inherently an integration — it reads the filesystem,
creates buffers and moves windows. The pure parts it leans on
(`_parse_at_reference`, `_parse_branch_ref`, `extract_inline_branch_links`)
already exist and are unchanged.

### Integration points

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| `_open_reference_under_cursor` | `lua/parley/init.lua` | new | filesystem + buffer/window opening |
| `focus_other_split` | `lua/parley/init.lua` | new | window layout |
| `open_branch_ref` | `lua/parley/init.lua` | modified | — |
| `try_open_src_link` | `lua/parley/init.lua` | modified | — |
| `try_open_inline_branch_link` | `lua/parley/init.lua` | modified | — |
| `OpenFileUnderCursor` | `lua/parley/init.lua` | modified | — |
| `open_chat_reference` | `lua/parley/init.lua` | deleted | — |

- **`_open_reference_under_cursor`** — the single chain, exported under `M._`
  purely as a test seam (the repo's existing idiom for a file-local function).
  - **Injected into:** nothing; it is the leaf. `OpenFileUnderCursor` is its
    only caller and owns the `"none"` → `gf` fall-through, so the fall-through
    exists in exactly one place and cannot be re-duplicated per buffer type.
  - **DRY rationale:** collapses two chains that had drifted apart in four
    measured ways. Three of the four were omissions **in chat** — the released
    surface — so the union is the fix, not a nicety.
  - **Future extensions:** `is_chat` is the one deliberate divergence axis. If
    markdown should ever gain directory `Explore`, the parameter disappears; no
    other caller shape changes.

- **`focus_other_split`** — the two-split preference, previously hand-inlined
  twice inside `OpenFileUnderCursor`. `open_buf` already had its own copy for
  files; this one exists because netrw does not go through `open_buf`.

- **`open_branch_ref` / `try_open_src_link` / `try_open_inline_branch_link`** —
  each returned `true` for both "opened it" and "recognised it and failed".
  That conflation was harmless while every non-`false` answer meant "stop"; it
  is not harmless once `"none"` falls through to `gf`. Each now returns
  `"opened" | "failed" | nil`.

- **`open_chat_reference`** — deleted. It was the markdown-only chain; its one
  production caller and its one test now go through the unified function.

**Test surface.** `tests/integration/open_reference_spec.lua` — integration
rather than unit because the behaviour under test *is* the IO: real files, real
buffers, real window layout, with `vim.cmd` / `open_buf` / `logger.warning`
spied at the boundary. Each of the four one-chain capabilities was
mutation-checked before the extraction landed.

## Estimate

Derived against the calibration ledger's comparable parley rows rather than a
remembered table (`sdlc estimate-source` flags the v3.1 doc `[stale]`; the
ledger is the newer artifact):

| row | est | design | impl | actual | ratio |
|---|---|---|---|---|---|
| #215 | 2.23 | 1.25 | 0.60 | 1.67 | 1.34 |
| #218 | 1.86 | 0.70 | 1.05 | 2.13 | 0.87 |
| #214 | 3.83 | 1.00 | 2.68 | 17.14 | **0.22** |

#218 is the closest shape — a focused Lua behaviour change with real edge cases
— and it bracketed 1.0 from the low side. #225 is a little more than that: an
extraction with four measured divergences, a three-valued contract, and 13
literal hits across 7 files.

**#214's 0.22 is the loud one, and it is not evidence to inflate this.** That
overrun was sixteen boundary rounds on a milestone carrying eight plan rows
across four subsystems. #225 is single-pass, one concern, and its design is
largely already spent — four plan-gate rounds have happened, which is why the
design line is not larger.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim              design=0.5 impl=0.5
item: ux-rename-iteration     design=0.1 impl=0.25
item: atlas-docs              design=0.0 impl=0.15
item: milestone-review        design=0.0 impl=0.2
design-buffer: 0.15
total: 1.79
```

`design-buffer: 0.15` (not the 0.30 default) because there is a thorough plan:
four gate rounds, the divergences enumerated with verdicts, the exit contract
tabulated. `milestone-review ×1` because the Plan is plain checkboxes — one
boundary, one `sdlc close`, no `Mx` tags.

Recomputed: (0.5+0.1) × 1.15 + (0.5+0.25+0.15+0.2) × 1.0 = 0.69 + 1.10 = **1.79**.

## Done when

- `<M-o>` opens a `🌿:` line, an inline link, a `src:` link, an `@@ref@@` and an
  `@@path: topic` in **both** chat and markdown buffers; `<C-g>o` does the same.
- A directory reference still opens in `Explore`, split-aware, **in chat
  buffers** — the one divergence kept rather than flattened.
- On a plain word `<M-o>` reaches the `gf` path **in both buffer types** —
  asserted by spying the delegation, not by hoping a real file exists.
- A `🌿:` reference whose file is missing still reports and does **not** reach
  `gf` — the `"failed"` case, asserted separately from `"none"`.
- On an ariadne artifact ref it resolves, exercised through
  `artifact_ref.run_resolve`'s existing injected-runner seam
  (`artifact_ref.lua:112-134`) rather than spawning `sdlc`.
- From insert mode: a reference lands in insert (unchanged), the `gf`
  fall-through lands in normal — both asserted, since the split is the policy.
- `<M-s>` opens the skill picker; `<M-o>` does not, in any buffer type.
- **No alt key resolves to more than one entry** — generalised from #214's
  `<M-g>`-specific check, which would not have caught this collision (PQ-4).
- One fall-through call site, asserted, so it cannot be re-duplicated per branch.
- No "no file reference" warning on the fall-through path.

## Plan

- [x] Generalise the collision guard: no alt key has two owners (fails today
      only if a collision exists; seen red by binding `<M-o>` twice)
- [x] Extract `open_reference_under_cursor(buf, line, col, is_chat)` — landed
      without the `in_insert` parameter: the landing mode is the *caller's*
      decision (it depends on which of the three outcomes came back), so
      passing it in would have been a parameter the function never reads
      taking the UNION of differences 1-3 and keeping 4 behind `is_chat`;
      characterisation tests for all four BEFORE the extraction, so a dropped
      arm fails rather than passing silently
- [x] Three-valued return; only `"none"` falls through. `"failed"` keeps its
      diagnostic; the two `"none"` warnings are deleted
- [x] One fall-through to `ResolveRefOrGotoFile`, `stopinsert` first when in
      insert mode
- [x] Move `review_menu` to `<M-s>`. **Grep-derived hit list** (13 across 7
      files — the first version of this row was recalled and named 2):
      `keybinding_registry.lua:750` (`default_key`), `config.lua:458,462`,
      `skills/review/init.lua:742,765`, `init.lua`, `atlas/modes/review.md:55,199`,
      `tests/integration/review_menu_spec.lua:93,110`,
      `tests/integration/keybinding_agreement_spec.lua:326,370,397,407` — where
      two hardcoded `{ "<C-g>ve", "<M-o>", "<M-CR>" }` lists need editing and
      `:407` (journal sidecar asserts `is_nil` for `<M-o>`) fails outright
- [x] `<M-g>` also lives in `README.md:189` and `atlas/ui/keybindings.md:65`
- [x] Rebind `open_file` to `{ "<M-o>", "<C-g>o" }` — full list in `config.lua`,
      since M2's superset guard requires it
- [x] Tests, named: `OpenFileUnderCursor` reaches each of the four steps in both
      buffer types; the gf arm via a `vim.cmd` spy; the resolve arm via the
      injected runner
- [x] README + `atlas/ui/keybindings.md` alt-family list + `atlas/modes/review.md`

## Log

### 2026-09-08 — implementation

**The bare-name gap was not just an omission.** D3 was tabled as "markdown
resolves bare filenames against the chat roots, chat does not." What chat
actually did was fall past `filereadable`, match the timestamp pattern, and
**create a second empty chat** beside the one being referenced. So `@@<bare
name>@@` in a chat buffer silently forked the transcript. The union fixes it;
`open_reference_spec` asserts the file count, not just which path was opened.

**Chat is the release surface** (operator, mid-implementation): markdown is
experimental ariadne-stack polish. That reinforces rather than redirects the
extraction — all three omissions were on the chat side. It does settle the
question the Spec deliberately left open: whether markdown should gain
directory `Explore` is not worth answering now.

**The unified file-open goes through `open_buf`.** The chat chain hand-rolled
its own split-aware `vim.cmd("edit")`, a strictly worse copy of what `open_buf`
already did: no existing-window reuse, no `file_tracker` access record. Chat
gains both. `focus_other_split` exists only because netrw does not go through
`open_buf`.

**Read-repair was deliberately NOT extended.** `resolve_chat_path` takes an
optional `referring_file` that schedules a slug rewrite in the referring
document. The `🌿:` paths pass it; the `@@` path does not, and this change kept
it that way — widening read-repair to `@@` references is #224's call, not a
side effect of a keybinding move.

**Two guards were wrong, not the code.**
- The plan-table sweep demanded a definition for rows marked `deleted` — a
  status its own legend defines. Fixed in `single_source_sweeps_spec`.
- The journal-sidecar assertion listed `<M-o>` among "review keys that must not
  leak". `<M-o>` is now `open_file`, `parley_buffer` scope, which *belongs* on a
  sidecar. It checks `<M-s>` instead: the key changed, but so did the rule the
  line was expressing.

**`<M-CR>` means two things and that is fine.** `chat_define` (chat) and
`review_next` (markdown) are siblings under `parley_buffer`, so no buffer is
ever both — the collision guard permits it by design. `<M-o>` was the opposite
case: `open_file` is an *ancestor* scope of `markdown`, so both bindings would
have been live in one buffer with the later registration silently winning. That
is why the skill picker had to move rather than coexist.

### 2026-09-08

Requested during the #224 investigation, after the operator had been using forks
heavily. Taken ahead of #224 because it is small and it is the key they press
most; #224 is the larger fix and follows.

`<M-g>` lasted a few hours — worth recording as evidence that a chord's cost is
not knowable from the registry. It was chosen because it was free and in the
right family, which is necessary and not sufficient.
