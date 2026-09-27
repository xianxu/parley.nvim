---
id: '000218'
status: done
started: 2026-09-05T12:12:38-07:00
created: 2026-09-05
updated: 2026-09-05
estimate_hours: 1.86
actual_hours: 2.13
---

# Rendering: contain malformed fences within one exchange

## Problem

Surfaced in the #206 release shakedown (#217 gap 10). When a model returns an
unmatched ``` fence, the damage does not stay in that answer — the rest of the
document renders as code.

The operator's diagnosis was right: **the render path does not honour the
exchange boundary that the structure already tracks.** `highlight_structure`
resets `in_question` and `in_reasoning` at every `💬:`/`🤖:` partition and never
`in_code`:

```lua
if token == TOKENS.user then
    state.in_question = true
    state.in_reasoning = false          -- reset
elseif token == TOKENS.assistant or token == TOKENS["local"] or token == TOKENS.branch then
    state.in_question = false
    state.in_reasoning = false          -- reset
```

### The class: four independent fence trackers, none of which reset

| # | site | shape | resets at partition? |
|---|---|---|---|
| 1 | `highlight_structure.lua:85,173` | boolean toggle on `^%s*```` | no |
| 2 | `highlighter.lua:148-153` | **duplicate** of #1, re-derived per window | no |
| 3 | `outline.lua:31-33` | boolean toggle, also `~~~` | no |
| 4 | `skills/review/init.lua:166-172` | fence-range pairing | no |

#2 is byte-identical logic to #1, seeded from it and then advanced privately —
so fixing #1 alone repairs the *seed* and leaves the in-window walk leaking.
