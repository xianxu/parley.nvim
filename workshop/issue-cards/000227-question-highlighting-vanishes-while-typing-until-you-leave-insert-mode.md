---
id: '000227'
status: done
started: 2026-09-10T13:13:23-07:00
created: 2026-09-09
updated: 2026-09-10
estimate_hours: 4.30
actual_hours: 3.35
---

# question highlighting vanishes while typing until you leave insert mode

## Problem

Operator report with a screenshot: while composing in insert mode, the chat's
highlighting is gone — the `💬:` question line and its block render as plain
text. Returning to normal mode restores it, which reads as *"moving outside to
normal mode triggers recoloring of the question"*. **Expected: questions are
constantly coloured.**

The recolour on mode change is a side effect, not the mechanism. Highlighting is
drawn by a decoration provider on redraw, and it **fails closed** the moment the
structure cache goes dirty.

### The symptom is instability, not only absence (operator, 5 more screenshots)

The first report showed the block rendering **plain**. A second batch taken
while typing continuously shows the colouring **changing frame to frame** —
*"as I typed, the question coloring kept changing"*. Across five captures of the
same buffer, the ordered-list markers (`1.` `2.` `3.`) render in one colour in
some frames and another in others, while the body text stays coloured.

That is the same defect seen at different redraw frames rather than a second
one. A chat buffer is `filetype=markdown` (`init.lua:1714`), so markdown's own
highlighting sits **underneath** parley's decoration overlay:

- frames where the structure cache is clean → the provider runs → parley's
  question colours win;
- frames where an edit has just dirtied it → `on_win` returns `false` → no
  parley decorations → **markdown's own colours show through**.

Typing alternates between the two states, so the block appears to shimmer rather
than simply vanish. The first screenshot caught a dirty frame at rest; these
catch the alternation.

**Stated as a hypothesis, not a finding:** the colour attribution above is read
off screenshots, and which layer owns the list-marker colour should be confirmed
at the buffer (`:Inspect` on a marker in a clean vs dirty frame) before the fix
is designed around it. What is *not* in doubt is the instability itself, which
the operator observed directly and which the `return false` path fully explains.

**This raises the fix's bar.** "Highlighting is present after typing stops" is
not enough — the Done-when must assert the rendered result is **stable across
consecutive redraws during a burst of edits**, since an intermittently-correct
overlay is what is actually being reported.

### The chain

**1. `on_lines` invalidates and does not repair.** `rebuild_structure`'s
`nvim_buf_attach` hook (`highlighter.lua:928-943`) tries an incremental update
and, when it cannot, gives up:

```lua
if reason then
    current.dirty = true
    current.renderable = false
else
    current.structure = replaced
end
```

Nothing schedules a rebuild. The cache simply stays unrenderable.

**2. The incremental path bails on almost any real edit.** `M.replace`
(`highlight_structure.lua:351-374`) succeeds only when **both** hold:

```lua
if old_last0 - first0 ~= #new_lines then
    return nil, #new_lines, "structural", ...      -- line COUNT changed
end
...
if not identical then return nil, #new_lines, "structural", work end   -- any fingerprint changed
```

So it handles only edits that change no line's structural fingerprint *and* keep
the line count identical. **Pressing Enter changes the count and bails
immediately** — which is exactly what the operator had just done (cursor on a
fresh line 11 in the screenshot). Typing a character that changes a line's
fingerprint bails too.

**3. The decoration provider draws nothing when dirty.**
`highlighter.lua:996-998`:

```lua
local structure_cache = structure_caches[bufnr]
if not structure_cache or structure_cache.dirty or not structure_cache.renderable then
    return false
end
```

`return false` means the window renders with **no** decorations at all — not
stale ones, none. Every highlight in the visible region disappears together,
which is why the symptom is "the whole thing goes plain" rather than "the edited
line is wrong".

**4. Recovery is incidental.** The cache is only rebuilt when something else
calls `rebuild_structure` — `BufEnter` (`highlighter.lua:1051`), or
`highlight_question_block` (`:851`, reached via `init.lua:2872`). Leaving insert
mode happens to reach one of those, so the colour returns and the mode change
gets the blame.

### Why the current design defers, which the fix must respect

`rebuild_structure` calls `build_structure`, which reads the **whole buffer**
(`reader:lines(0, -1, false)`) and re-derives every fingerprint and
`state_before`. That is precisely why the incremental path exists, and why a
naive "rebuild on every `on_lines`" would be wrong — it would put an O(buffer)
scan on every keystroke of a long chat. The current code avoids that cost by
paying with a blank screen instead.
