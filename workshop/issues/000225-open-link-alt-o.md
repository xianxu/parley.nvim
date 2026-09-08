---
id: 000225
status: open
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-08
estimate_hours:
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

**Fallback chain for `<M-o>`**, in order, each falling through to the next:

1. `🌿:` reference line → open that chat
2. inline `[🌿:anchor](file)` under the cursor → open it
3. `@@path@@` reference → open it
4. **otherwise → `ResolveRefOrGotoFile`**: an ariadne artifact ref
   (`ariadne#11`, `#15 M4`) resolves and jumps; anything else gets native `gf`

Step 4 is the new part; steps 1-3 exist. `ResolveRefOrGotoFile` is already a
command (`init.lua:4692`) and already ends in `normal! gf`, so this is a
delegation, not new logic.

- `<C-g>o` stays as a legacy alias, as `<C-g>i`/`<C-g>b` did in #214.
- `gf` keeps its own binding. `<M-o>` is a superset, not a replacement — muscle
  memory for `gf` is worth more than the deduplication.
- The old "no file reference found" warning goes away; falling through IS the
  answer, and a warning that fires whenever you are not on a link is noise.

## Done when

- `<M-o>` opens a `🌿:` line, an inline link and an `@@ref@@` in both chat and
  markdown buffers; `<C-g>o` still does the same.
- On a plain word `<M-o>` behaves as `gf` would — asserted, not assumed.
- `<M-s>` opens the skill picker; `<M-o>` no longer does, in any buffer type.
- `<M-o>` resolves to exactly one entry — the collision check #214 added for
  `<M-g>` catches a re-collision.
- No "no file reference" warning remains on the fall-through path.

## Plan

- [ ] Move `review_menu` to `<M-s>`; assert `<M-o>` has one owner
- [ ] Rebind `open_file` to `<M-o>` (with `<C-g>o` alias, full list in config —
      M2's superset guard requires it)
- [ ] Fall through to `ResolveRefOrGotoFile` instead of warning; drop the warning
- [ ] Tests: each of the four steps, in both buffer types
- [ ] README + `atlas/ui/keybindings.md` + the alt-family list

## Log

### 2026-09-08

Requested during the #224 investigation, after the operator had been using forks
heavily. Taken ahead of #224 because it is small and it is the key they press
most; #224 is the larger fix and follows.

`<M-g>` lasted a few hours — worth recording as evidence that a chord's cost is
not knowable from the registry. It was chosen because it was free and in the
right family, which is necessary and not sufficient.
