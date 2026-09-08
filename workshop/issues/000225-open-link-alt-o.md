---
id: 000225
status: working
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-08
estimate_hours:
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

- [ ] Generalise the collision guard: no alt key has two owners (fails today
      only if a collision exists; seen red by binding `<M-o>` twice)
- [ ] Extract `open_reference_under_cursor(buf, line, col, in_insert, is_chat)`
      taking the UNION of differences 1-3 and keeping 4 behind `is_chat`;
      characterisation tests for all four BEFORE the extraction, so a dropped
      arm fails rather than passing silently
- [ ] Three-valued return; only `"none"` falls through. `"failed"` keeps its
      diagnostic; the two `"none"` warnings are deleted
- [ ] One fall-through to `ResolveRefOrGotoFile`, `stopinsert` first when in
      insert mode
- [ ] Move `review_menu` to `<M-s>`; update `atlas/modes/review.md:55,199` and
      `tests/integration/review_menu_spec.lua:93,110`, which assert `<M-o>`
- [ ] Rebind `open_file` to `{ "<M-o>", "<C-g>o" }` — full list in `config.lua`,
      since M2's superset guard requires it
- [ ] Tests, named: `OpenFileUnderCursor` reaches each of the four steps in both
      buffer types; the gf arm via a `vim.cmd` spy; the resolve arm via the
      injected runner
- [ ] README + `atlas/ui/keybindings.md` alt-family list + `atlas/modes/review.md`

## Log

### 2026-09-08

Requested during the #224 investigation, after the operator had been using forks
heavily. Taken ahead of #224 because it is small and it is the key they press
most; #224 is the larger fix and follows.

`<M-g>` lasted a few hours — worth recording as evidence that a chord's cost is
not knowable from the registry. It was chosen because it was free and in the
right family, which is necessary and not sufficient.
