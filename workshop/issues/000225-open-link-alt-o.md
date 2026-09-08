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

### The structural problem step 4 exposes (PQ-1, PQ-2)

`OpenFileUnderCursor` has **two** chains, not one:

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

Appending step 4 at the end would fire in chat buffers and never in markdown —
the per-buffer-type divergence this issue exists to remove, reintroduced by the
fix for it. Appending it to both is two copies of the fall-through.

**So step 4 is not an append; it is an extraction.** One predicate, used by both
buffer types, and the fall-through stated once:

```lua
--- @return boolean handled
local function open_reference_under_cursor(buf, line, col, in_insert) … end

M.cmd.OpenFileUnderCursor = function()
    …guards…
    if open_reference_under_cursor(buf, line, col, in_insert) then return end
    M.cmd.ResolveRefOrGotoFile()          -- exactly one fall-through
end
```

`open_chat_reference` already returns a boolean and already chains src → inline
→ `@@`; the chat path duplicates most of it. The extraction is mostly deleting
the second copy, which is the same four-copies-to-one move #214 M1 made for
`branch_inserters`.

### Insert mode (PQ-3)

`open_file` is bound in `n` **and** `i`, and `register_buffer` passes a
mode-specific callback straight through — no `stopinsert` wrapper (that exists
only in `register_global`). `normal! gf` from insert mode would run against a
cursor one column off and drop the user out of insert anyway.

**Decision: `stopinsert` first, then fall through.** Following a link is a
navigation, and navigating out of insert mode is what the user asked for by
pressing the key. The alternative — no fall-through in insert mode — makes one
key mean two things depending on mode, which is the divergence again.

## Done when

- `<M-o>` opens a `🌿:` line, an inline link, a `src:` link and an `@@ref@@`, in
  **both** chat and markdown buffers; `<C-g>o` does the same.
- On a plain word `<M-o>` reaches the `gf` path **in both buffer types** —
  asserted by spying the delegation, not by hoping a real file exists.
- On an ariadne artifact ref it resolves, exercised through
  `artifact_ref.run_resolve`'s existing injected-runner seam
  (`artifact_ref.lua:112-134`) rather than spawning `sdlc`.
- From insert mode, `<M-o>` leaves insert and then falls through.
- `<M-s>` opens the skill picker; `<M-o>` does not, in any buffer type.
- **No alt key resolves to more than one entry** — generalised from #214's
  `<M-g>`-specific check, which would not have caught this collision (PQ-4).
- One fall-through call site, asserted, so it cannot be re-duplicated per branch.
- No "no file reference" warning on the fall-through path.

## Plan

- [ ] Generalise the collision guard: no alt key has two owners (fails today
      only if a collision exists; seen red by binding `<M-o>` twice)
- [ ] Extract `open_reference_under_cursor(buf, line, col, in_insert) -> handled`
      from the markdown branch and the chat chain; delete the duplicate
- [ ] One fall-through to `ResolveRefOrGotoFile`, after `stopinsert` when in
      insert mode; drop the "no file reference" warning
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
